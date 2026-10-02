import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/config/biometric_config.dart';
import 'package:horas_hombre_mobile/config/device_form_factor.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/models/employee.dart';
import 'package:horas_hombre_mobile/screens/employee_number_screen.dart';
import 'package:horas_hombre_mobile/screens/face_capture_screen.dart';
import 'package:horas_hombre_mobile/screens/qr_scan_screen.dart';
import 'package:horas_hombre_mobile/screens/result_screen.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/attendance_sync_service.dart';
import 'package:horas_hombre_mobile/services/face_gallery_service.dart';
import 'package:horas_hombre_mobile/services/face_reference_repository.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:horas_hombre_mobile/widgets/loading_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// Flujo principal: captura → liveness → identificación 1:N → asistencia.
/// Si no hay match, ofrece QR o número de empleado.
class FaceIdentifyScreen extends StatefulWidget {
  const FaceIdentifyScreen({super.key, required this.attendanceType});

  final AttendanceType attendanceType;

  @override
  State<FaceIdentifyScreen> createState() => _FaceIdentifyScreenState();
}

class _FaceIdentifyScreenState extends State<FaceIdentifyScreen> {
  CameraController? _controller;
  int _cameraEpoch = 0;
  Future<void> _cameraOp = Future<void>.value();
  bool _initializing = true;
  bool _processing = false;
  bool _handoff = false;
  String? _statusMessage;
  String? _error;
  bool _permissionDenied = false;
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  /// Cierra la sesión de CameraX de esta pantalla.
  /// `camera` y `mobile_scanner` comparten el mismo ProcessCameraProvider:
  /// si la siguiente pantalla abre la cámara antes de este dispose, el
  /// `unbindAll` deja el preview en negro o congelado en el QR.
  Future<void> _releaseCamera() async {
    _cameraEpoch++;
    try {
      await _cameraOp;
    } catch (_) {}

    final controller = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _initCamera() {
    final epoch = ++_cameraEpoch;
    final op = _openCamera(epoch);
    _cameraOp = op;
    return op;
  }

  Future<void> _openCamera(int epoch) async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
        _permissionDenied = false;
      });
    }

    var status = await Permission.camera.status;
    if (epoch != _cameraEpoch || !mounted) return;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (epoch != _cameraEpoch || !mounted) return;
    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
        _initializing = false;
      });
      return;
    }

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (epoch != _cameraEpoch || !mounted) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        front,
        captureResolutionPreset(),
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (epoch != _cameraEpoch || !mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      try {
        await controller?.dispose();
      } catch (_) {}
      if (epoch == _cameraEpoch && mounted) {
        setState(() {
          _error = 'No se pudo iniciar la cámara: $e';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _captureAndIdentify() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }

    final faceSdk = context.read<FaceSdkService>();
    final gallery = context.read<FaceGalleryService>();
    final api = context.read<ApiService>();
    final attendanceSync = context.read<AttendanceSyncService>();
    final settings = context.read<SettingsService>();

    if (!faceSdk.isInitialized) {
      await _goToResult(
        success: false,
        title: 'Biometría no disponible',
        subtitle: '3DiVi Face SDK no está inicializado.',
      );
      return;
    }

    if (!gallery.isReady) {
      setState(() {
        _showFallback = true;
        _statusMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Galería facial vacía. Use QR o número, o sincronice en Ajustes.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _processing = true;
      _showFallback = false;
      _statusMessage = 'Verificando prueba de vida…';
    });

    String? capturedPath;
    try {
      final file = await controller.takePicture();
      capturedPath = file.path;
      final capturedBytes = await File(file.path).readAsBytes();

      final liveness = await faceSdk.checkLiveness(capturedBytes);
      if (!liveness.isLive) {
        if (mounted) {
          await _goToResult(
            success: false,
            title: 'Prueba de vida fallida',
            subtitle:
                'No se confirmó que sea una persona real.\n'
                'Liveness: ${liveness.livenessScore.toStringAsFixed(3)}',
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Identificando rostro…');
      }

      final identify = await faceSdk.identifyFace(capturedBytes);
      if (!identify.isMatch || identify.numberUser == null) {
        if (mounted) {
          setState(() {
            _processing = false;
            _statusMessage = null;
            _showFallback = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se identificó el rostro '
                '(score ${identify.faceMatchScore.toStringAsFixed(3)}, '
                'umbral ${BiometricConfig.identifyThreshold}). '
                'Pruebe QR o número de empleado.',
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Resolviendo empleado…');
      }

      final numberUser = identify.numberUser!;
      Employee? employee = gallery.getByNumberUser(numberUser);
      employee ??= await api.getEmployee(numberUser);

      if (employee.active == false) {
        await _goToResult(
          success: false,
          title: 'Empleado inactivo',
          subtitle: employee.fullName,
        );
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Guardando asistencia…');
      }

      if (settings.locationId == null ||
          settings.locationName == null ||
          settings.locationName!.isEmpty) {
        await _goToResult(
          success: false,
          title: 'Ubicación no configurada',
          subtitle: 'Seleccione una ubicación en Ajustes antes de registrar.',
        );
        return;
      }

      final delivery = await attendanceSync.capture(
        AttendanceRecord(
          userId: employee.userId,
          type: widget.attendanceType,
          locationId: settings.locationId,
          locationName: settings.locationName,
          employeeName: employee.fullName,
        ),
      );

      if (mounted) {
        await _goToResult(
          success: delivery.success,
          title: delivery.title,
          subtitle:
              '${employee.fullName}\n'
              'Liveness: ${liveness.livenessScore.toStringAsFixed(3)}\n'
              'Identificación: ${identify.faceMatchScore.toStringAsFixed(3)}\n'
              '${delivery.message}',
        );
      }
    } on FaceSdkException catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _statusMessage = null;
          _showFallback = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        await _goToResult(
          success: false,
          title: 'Error al guardar',
          subtitle: e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _statusMessage = null;
          _showFallback = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      await _deleteCapturedFile(capturedPath);
      if (mounted && _processing) {
        setState(() {
          _processing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _openQrFallback() async {
    if (_handoff || _processing) return;
    _handoff = true;
    await _releaseCamera();
    if (!mounted) return;
    final numberUser = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const QrScanScreen()),
    );
    if (!mounted) return;
    if (numberUser == null) {
      _handoff = false;
      await _initCamera();
      return;
    }
    await _continueWithNumberUser(numberUser);
  }

  Future<void> _openManualFallback() async {
    if (_handoff || _processing) return;
    final numberUser = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const EmployeeNumberScreen()),
    );
    if (numberUser == null || !mounted) return;
    _handoff = true;
    await _continueWithNumberUser(numberUser);
  }

  Future<void> _continueWithNumberUser(int numberUser) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingOverlay(message: 'Buscando empleado…'),
    );

    try {
      final api = context.read<ApiService>();
      final faceRefRepo = context.read<FaceReferenceRepository>();
      final employee = await api.getEmployee(numberUser);
      await faceRefRepo.cacheFromEmployee(employee);

      if (!mounted) return;
      Navigator.of(context).pop();

      if (employee.active == false) {
        await _goToResult(
          success: false,
          title: 'Empleado inactivo',
          subtitle: employee.fullName,
        );
        return;
      }

      await _releaseCamera();
      if (!mounted) return;
      // CameraX cierra el dispositivo después de unbindAll.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => FaceCaptureScreen(
            employee: employee,
            attendanceType: widget.attendanceType,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await _goToResult(
        success: false,
        title: 'Empleado no encontrado',
        subtitle: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await _goToResult(
        success: false,
        title: 'Error de conexión',
        subtitle: e.toString(),
      );
    }
  }

  Future<void> _deleteCapturedFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _goToResult({
    required bool success,
    required String title,
    String? subtitle,
  }) async {
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          success: success,
          title: title,
          subtitle: subtitle,
          attendanceType: widget.attendanceType,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraEpoch++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = context.watch<FaceGalleryService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Identificación — ${widget.attendanceType.label}'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    gallery.isReady
                        ? 'Mire a la cámara y pulse identificar '
                            '(${gallery.cachedEmployeeCount} rostros en galería)'
                        : 'Galería no lista: use QR o número, o sincronice fotos.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(child: _buildCameraArea()),
                if (_showFallback) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Otras formas de identificarse',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing || _handoff ? null : _openQrFallback,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('QR'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing || _handoff ? null : _openManualFallback,
                            icon: const Icon(Icons.dialpad),
                            label: const Text('Número'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _canCapture ? _captureAndIdentify : null,
                          icon: const Icon(Icons.face),
                          label: const Text(
                            'Tomar foto e identificar',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      if (!_showFallback) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _processing || _handoff
                              ? null
                              : () => setState(() => _showFallback = true),
                          child: const Text('Usar QR o número de empleado'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_processing && _statusMessage != null)
              LoadingOverlay(message: _statusMessage!),
          ],
        ),
      ),
    );
  }

  bool get _canCapture =>
      !_processing &&
      !_initializing &&
      _controller != null &&
      _controller!.value.isInitialized;

  Widget _buildCameraArea() {
    if (_permissionDenied) {
      return _messagePanel(
        'Permiso de cámara denegado.',
        action: TextButton(
          onPressed: openAppSettings,
          child: const Text('Abrir configuración'),
        ),
      );
    }
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _messagePanel(_error!);
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _messagePanel('Cámara no disponible');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _messagePanel(String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}

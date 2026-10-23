import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/config/biometric_config.dart';
import 'package:horas_hombre_mobile/config/device_form_factor.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/models/employee.dart';
import 'package:horas_hombre_mobile/screens/result_screen.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/attendance_sync_service.dart';
import 'package:horas_hombre_mobile/services/face_reference_repository.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/services/settings_service.dart';
import 'package:horas_hombre_mobile/widgets/adaptive_capture_body.dart';
import 'package:horas_hombre_mobile/widgets/employee_card.dart';
import 'package:horas_hombre_mobile/widgets/loading_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({
    super.key,
    required this.employee,
    required this.attendanceType,
  });

  final Employee employee;
  final AttendanceType attendanceType;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  int _cameraEpoch = 0;
  bool _initializing = true;
  bool _processing = false;
  String? _statusMessage;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final epoch = ++_cameraEpoch;
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

    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (epoch != _cameraEpoch || !mounted) return;
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
        if (epoch != _cameraEpoch || !mounted) return;
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
          _error = null;
        });
        return;
      } catch (e) {
        lastError = e;
        try {
          await controller?.dispose();
        } catch (_) {}
      }
    }

    if (epoch == _cameraEpoch && mounted) {
      setState(() {
        _error = 'No se pudo iniciar la cámara: $lastError';
        _initializing = false;
      });
    }
  }

  Future<void> _captureAndProcess() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }

    final faceSdk = context.read<FaceSdkService>();
    if (!faceSdk.isInitialized) {
      await _goToResult(
        success: false,
        title: 'Biometría no disponible',
        subtitle: '3DiVi Face SDK no está inicializado.',
      );
      return;
    }

    final faceRefRepo = context.read<FaceReferenceRepository>();
    final attendanceSync = context.read<AttendanceSyncService>();

    setState(() {
      _processing = true;
      _statusMessage = 'Verificando prueba de vida…';
    });

    String? capturedPath;
    try {
      final file = await controller.takePicture();
      capturedPath = file.path;
      final capturedBytes = await File(file.path).readAsBytes();

      final stored = await faceRefRepo.resolveReferenceImage(widget.employee);
      if (stored == null || stored.isEmpty) {
        if (mounted) {
          await _goToResult(
            success: false,
            title: 'Sin fotografía registrada',
            subtitle:
                'El empleado no tiene foto en el sistema ni en cache local. '
                'Contacte a recursos humanos.',
          );
        }
        return;
      }

      final livenessOnly = await faceSdk.checkLiveness(capturedBytes);
      if (!livenessOnly.isLive) {
        if (mounted) {
          await _goToResult(
            success: false,
            title: 'Prueba de vida fallida',
            subtitle:
                'No se confirmó que sea una persona real.\n'
                'Liveness: ${livenessOnly.livenessScore.toStringAsFixed(3)} '
                '(umbral ${BiometricConfig.livenessThreshold})',
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Comparando rostros…');
      }

      final verify = await faceSdk.verifyFace(
        capturedJpeg: capturedBytes,
        referenceJpeg: stored,
      );

      if (!verify.isMatch) {
        if (mounted) {
          await _goToResult(
            success: false,
            title: 'Rostro no coincide',
            subtitle:
                'La verificación facial no fue exitosa.\n'
                'Coincidencia: ${verify.faceMatchScore.toStringAsFixed(3)} '
                '(umbral ${BiometricConfig.faceMatchThreshold})',
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Guardando asistencia…');
      }

      if (!mounted) return;
      final settings = context.read<SettingsService>();
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

      final record = AttendanceRecord(
        userId: widget.employee.userId,
        type: widget.attendanceType,
        locationId: settings.locationId,
        locationName: settings.locationName,
        employeeName: widget.employee.fullName,
      );
      final delivery = await attendanceSync.capture(record);

      if (mounted) {
        await _goToResult(
          success: delivery.success,
          title: delivery.title,
          subtitle:
              '${widget.employee.fullName}\n'
              'Liveness: ${livenessOnly.livenessScore.toStringAsFixed(3)}\n'
              'Coincidencia: ${verify.faceMatchScore.toStringAsFixed(3)}\n'
              '${delivery.message}',
        );
      }
    } on FaceSdkException catch (e) {
      if (mounted) {
        await _goToResult(
          success: false,
          title: 'Error biométrico',
          subtitle: e.message,
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
        await _goToResult(
          success: false,
          title: 'Error de verificación',
          subtitle: e.toString(),
        );
      }
    } finally {
      await _deleteCapturedFile(capturedPath);
      if (mounted) {
        setState(() {
          _processing = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _deleteCapturedFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      await _deleteStaleCapturesIn(file.parent);
    } catch (_) {}
  }

  /// Limpia JPEGs temporales de `takePicture()` que hayan quedado de intentos previos.
  Future<void> _deleteStaleCapturesIn(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last.toUpperCase();
      final isCapture =
          name.startsWith('CAP') &&
          (name.endsWith('.JPG') ||
              name.endsWith('.JPEG') ||
              name.endsWith('.HEIF'));
      if (!isCapture) continue;
      try {
        await entity.delete();
      } catch (_) {}
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Verificación — ${widget.attendanceType.label}'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AdaptiveCaptureBody(
              banner: Padding(
                padding: const EdgeInsets.all(12),
                child: EmployeeCard(
                  fullName: widget.employee.fullName,
                  departmentName: widget.employee.departmentName,
                  photograph: widget.employee.photograph,
                ),
              ),
              preview: _buildCameraArea(),
              controls: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _canCapture ? _captureAndProcess : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Tomar foto y verificar',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

    return CameraPreviewFrame(controller: controller);
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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/config/biometric_config.dart';
import 'package:horas_hombre_mobile/models/biometric_test_result.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:horas_hombre_mobile/widgets/loading_overlay.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Pantalla aislada: validar licencia 3DiVi y prueba biométrica 1:1.
class BiometricTestScreen extends StatefulWidget {
  const BiometricTestScreen({super.key});

  @override
  State<BiometricTestScreen> createState() => _BiometricTestScreenState();
}

class _BiometricTestScreenState extends State<BiometricTestScreen> {
  final _picker = ImagePicker();

  FaceSdkDiagnostics? _diagnostics;
  String? _diagnosticsError;

  Uint8List? _referenceBytes;
  Uint8List? _capturedBytes;
  BiometricTestResult? _result;
  String? _runError;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDiagnostics());
  }

  void _loadDiagnostics() {
    final sdk = context.read<FaceSdkService>();
    if (!sdk.isInitialized) {
      setState(() {
        _diagnosticsError = 'FaceSDK no está inicializado. Revise la licencia.';
      });
      return;
    }

    try {
      setState(() {
        _diagnostics = sdk.getDiagnostics();
        _diagnosticsError = null;
      });
    } on FaceSdkException catch (e) {
      setState(() => _diagnosticsError = e.message);
    } catch (e) {
      setState(() => _diagnosticsError = e.toString());
    }
  }

  Future<void> _pickImage(ImageSource source, {required bool reference}) async {
    final file = await _picker.pickImage(
      source: source,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    setState(() {
      if (reference) {
        _referenceBytes = bytes;
      } else {
        _capturedBytes = bytes;
      }
      _result = null;
      _runError = null;
    });
  }

  Future<void> _runTest() async {
    final reference = _referenceBytes;
    final captured = _capturedBytes;
    if (reference == null || captured == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione foto de referencia y foto capturada.'),
        ),
      );
      return;
    }

    setState(() {
      _running = true;
      _runError = null;
      _result = null;
    });

    try {
      final sdk = context.read<FaceSdkService>();
      final result = await sdk.runBiometricTest(
        referenceJpeg: reference,
        capturedJpeg: captured,
      );
      if (mounted) {
        setState(() => _result = result);
      }
    } on FaceSdkException catch (e) {
      if (mounted) setState(() => _runError = e.message);
    } catch (e) {
      if (mounted) setState(() => _runError = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba 3DiVi (Fase 1)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar diagnóstico',
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DiagnosticsCard(
                diagnostics: _diagnostics,
                error: _diagnosticsError,
              ),
              const SizedBox(height: 16),
              _ImagePickerCard(
                title: 'Foto de referencia',
                subtitle: 'Imagen registrada del empleado (galería)',
                bytes: _referenceBytes,
                onPickGallery: () =>
                    _pickImage(ImageSource.gallery, reference: true),
              ),
              const SizedBox(height: 12),
              _ImagePickerCard(
                title: 'Foto capturada',
                subtitle: 'Selfie nueva para comparar',
                bytes: _capturedBytes,
                onPickGallery: () =>
                    _pickImage(ImageSource.camera, reference: false),
                galleryLabel: 'Tomar selfie',
                galleryIcon: Icons.camera_alt,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _running ? null : _runTest,
                icon: const Icon(Icons.biotech),
                label: const Text('Ejecutar liveness + verificación 1:1'),
              ),
              if (_runError != null) ...[
                const SizedBox(height: 16),
                _ErrorCard(message: _runError!),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _ResultCard(result: _result!),
              ],
            ],
          ),
          if (_running) const LoadingOverlay(message: 'Procesando biometría…'),
        ],
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({this.diagnostics, this.error});

  final FaceSdkDiagnostics? diagnostics;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ok = diagnostics != null && error == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.verified : Icons.warning_amber,
                  color: ok ? Colors.green.shade700 : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  'Estado de la licencia',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(error!, style: TextStyle(color: Colors.red.shade700))
            else if (diagnostics != null) ...[
              _DiagRow(label: 'Versión SDK', value: diagnostics!.versionInfo),
              _DiagRow(label: 'Licencia', value: diagnostics!.licenseInfo),
              _DiagRow(label: 'Hardware ID', value: diagnostics!.hardwareId),
              const SizedBox(height: 8),
              Text(
                'Si la licencia es válida, la información anterior se muestra sin error de activación.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.onPickGallery,
    this.galleryLabel = 'Elegir de galería',
    this.galleryIcon = Icons.photo_library,
  });

  final String title;
  final String subtitle;
  final Uint8List? bytes;
  final VoidCallback onPickGallery;
  final String galleryLabel;
  final IconData galleryIcon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes!, height: 160, fit: BoxFit.cover),
              )
            else
              Container(
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.face, size: 48, color: Colors.grey),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickGallery,
              icon: Icon(galleryIcon),
              label: Text(galleryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final BiometricTestResult result;

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final color = passed ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  passed ? 'Prueba exitosa' : 'Prueba fallida',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            _MetricRow(
              label: 'isLive',
              value: result.isLive ? 'true' : 'false',
              ok: result.isLive,
              detail:
                  '${result.livenessScore.toStringAsFixed(3)} (umbral ${BiometricConfig.livenessThreshold})',
            ),
            _MetricRow(
              label: 'isMatch',
              value: result.isMatch ? 'true' : 'false',
              ok: result.isMatch,
              detail:
                  'faceMatchScore ${result.faceMatchScore.toStringAsFixed(3)} (umbral ${BiometricConfig.faceMatchThreshold})',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.ok,
    required this.detail,
  });

  final String label;
  final String value;
  final bool ok;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check : Icons.close,
            size: 20,
            color: ok ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label = $value',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

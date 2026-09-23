import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horas_hombre_mobile/models/qr_payload.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.front,
  );

  bool _handled = false;
  bool _closing = false;
  bool _permissionDenied = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _ensureCameraPermission();
  }

  /// Suelta CameraX antes de volver. Si no, el `unbindAll` del escáner
  /// llega tarde y deja en negro (o congelada) la cámara de la foto.
  Future<void> _close([int? numberUser]) async {
    if (_handled) return;
    _handled = true;

    try {
      await _controller.stop();
    } catch (_) {}

    if (mounted) {
      setState(() => _closing = true);
    }
    await WidgetsBinding.instance.endOfFrame;

    try {
      await _controller.dispose();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop(numberUser);
  }

  Future<void> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    setState(() {
      _checkingPermission = false;
      _permissionDenied = !status.isGranted;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    final payload = QrPayload.parse(raw);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'QR inválido: use el número de empleado o JSON con numberUser',
          ),
        ),
      );
      return;
    }

    unawaited(_close(payload.numberUser));
  }

  @override
  void dispose() {
    if (!_handled) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _handled) return;
        unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Escanear QR'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => unawaited(_close()),
          ),
        ),
        body: _checkingPermission || _closing
            ? const Center(child: CircularProgressIndicator())
            : _permissionDenied
                ? SafeArea(child: _buildPermissionDenied())
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
                      _buildOverlay(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Se necesita permiso de cámara para escanear el código QR.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('Abrir configuración'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          color: Colors.black54,
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          child: const Text(
            'Muestre el código QR frente a la cámara',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }
}

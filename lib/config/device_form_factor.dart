import 'dart:ui' show PlatformDispatcher;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

const _faceSdkChannel = MethodChannel('samples.flutter.dev/facesdk');

/// Lado corto a partir del cual el equipo se trata como tableta.
/// Es el mismo corte que Android usa para pantallas grandes (`sw600dp`).
const double kTabletShortestLogicalSide = 600;

bool isTabletLogicalSize(double shortestLogicalSide) {
  return shortestLogicalSide >= kTabletShortestLogicalSide;
}

/// Usa el tamaño físico de la pantalla, no el área de la vista.
/// En pantallas grandes Android puede meter la app en un recuadro y
/// `MediaQuery` reportaría un teléfono.
bool isTabletDisplay() {
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return false;
  final display = views.first.display;
  final ratio = display.devicePixelRatio;
  if (ratio == 0) return false;
  return isTabletLogicalSize(display.size.shortestSide / ratio);
}

/// Teléfono: vertical, como el kiosko de bolsillo.
/// Tableta: vertical y ambos horizontales. La cámara frontal no está
/// siempre en el mismo borde; la interfaz sigue al sensor, así que
/// al colocar la cámara arriba el botón queda derecho en cualquier modelo.
List<DeviceOrientation> kioskOrientations({required bool tablet}) {
  if (tablet) {
    return const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
  }
  return const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];
}

Future<void> applyKioskOrientations() async {
  if (isTabletDisplay()) {
    // `SENSOR` sigue el acelerómetro aunque el bloqueo de rotación
    // del sistema esté activo. En iOS el canal no existe y se usa
    // la lista de orientaciones de abajo.
    try {
      final applied = await _faceSdkChannel.invokeMethod<bool>(
        'setSensorOrientation',
      );
      if (applied == true) return;
    } on MissingPluginException {
      // iOS y pruebas: sigue el camino de SystemChrome.
    } catch (_) {}
  }

  await SystemChrome.setPreferredOrientations(
    kioskOrientations(tablet: isTabletDisplay()),
  );
}

/// `medium` en CameraX es 720×480. En una tableta esa textura se estira
/// y el rostro llega al SDK con pocos píxeles.
/// En tableta se pide 1080p; si el sensor no lo tiene, CameraX baja
/// a la resolución más cercana. El teléfono se queda en 480p.
ResolutionPreset kioskCaptureResolution({required bool tablet}) {
  return tablet ? ResolutionPreset.veryHigh : ResolutionPreset.medium;
}

ResolutionPreset captureResolutionPreset() {
  return kioskCaptureResolution(tablet: isTabletDisplay());
}

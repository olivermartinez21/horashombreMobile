import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horas_hombre_mobile/config/device_form_factor.dart';

void main() {
  test('teléfono y tableta pueden girar', () {
    expect(
      kioskOrientations(),
      [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
  });

  test('el corte de tableta es 600 dp', () {
    expect(isTabletLogicalSize(599), isFalse);
    expect(isTabletLogicalSize(600), isTrue);
    expect(isTabletLogicalSize(800), isTrue);
  });

  test('la tableta pide 1080p y el teléfono se queda en 480p', () {
    expect(
      kioskCaptureResolution(tablet: false),
      ResolutionPreset.medium,
    );
    expect(
      kioskCaptureResolution(tablet: true),
      ResolutionPreset.veryHigh,
    );
  });
}

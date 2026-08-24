import 'dart:developer';
import 'dart:typed_data';

import 'package:face_sdk_3divi/face_sdk_3divi.dart';
import 'package:horas_hombre_mobile/config/biometric_config.dart';
import 'package:horas_hombre_mobile/models/biometric_test_result.dart';
import 'package:image/image.dart' as img;

class FaceSdkException implements Exception {
  FaceSdkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LivenessResult {
  const LivenessResult({
    required this.isLive,
    required this.livenessScore,
  });

  final bool isLive;
  final double livenessScore;
}

class VerifyResult {
  const VerifyResult({
    required this.isMatch,
    required this.faceMatchScore,
  });

  final bool isMatch;
  final double faceMatchScore;
}

/// Información de diagnóstico tras activar el SDK (validar licencia).
class FaceSdkDiagnostics {
  const FaceSdkDiagnostics({
    required this.versionInfo,
    required this.licenseInfo,
    required this.hardwareId,
  });

  final String versionInfo;
  final String licenseInfo;
  final String hardwareId;
}

/// Inicialización y operaciones de bajo nivel sobre 3DiVi Face SDK.
class FaceSdkService {
  static const String _sdkVersion = '3DiVi Face SDK 3.26.1';
  static const String _detectorModification = 'uld';
  static const String _fitterModification = 'fda';
  static const String _livenessModification = '2d_light';
  static const String _templateModification = '100m';
  static const int _templateVersion = 1;
  static const int _maxImageSide = 1600;

  bool _initialized = false;
  FacerecService? _facerecService;
  ProcessingBlock? _faceDetector;
  ProcessingBlock? _faceFitter;
  ProcessingBlock? _livenessEstimator;
  ProcessingBlock? _faceTemplateExtractor;
  ProcessingBlock? _verificationModule;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _facerecService = await FacerecService.createService();
      final service = _facerecService!;

      _faceDetector = service.createProcessingBlock({
        'unit_type': 'FACE_DETECTOR',
        'modification': _detectorModification,
      });
      _faceFitter = service.createProcessingBlock({
        'unit_type': 'FACE_FITTER',
        'modification': _fitterModification,
      });
      _livenessEstimator = service.createProcessingBlock({
        'unit_type': 'LIVENESS_ESTIMATOR',
        'modification': _livenessModification,
      });
      _faceTemplateExtractor = service.createProcessingBlock({
        'unit_type': 'FACE_TEMPLATE_EXTRACTOR',
        'modification': _templateModification,
        'version': _templateVersion,
      });
      _verificationModule = service.createProcessingBlock({
        'unit_type': 'VERIFICATION_MODULE',
        'modification': _templateModification,
        'version': _templateVersion,
      });
      _initialized = true;
    } catch (e, st) {
      log('Error al inicializar 3DiVi Face SDK: $e\n$st');
      _disposeNative();
      throw FaceSdkException(
        'No se pudo iniciar 3DiVi Face SDK. Revisa assets/license/3divi_face_sdk.lic '
        'y que coincida con el applicationId de release. Detalle: $e',
      );
    }
  }

  FaceSdkDiagnostics getDiagnostics() {
    _ensureInitialized();
    return const FaceSdkDiagnostics(
      versionInfo: _sdkVersion,
      licenseInfo: 'Licencia cargada desde assets/license/3divi_face_sdk.lic',
      hardwareId: 'n/a (lock por Application ID)',
    );
  }

  Future<BiometricTestResult> runBiometricTest({
    required Uint8List referenceJpeg,
    required Uint8List capturedJpeg,
  }) async {
    final liveness = await checkLiveness(capturedJpeg);
    final verify = await verifyFace(
      capturedJpeg: capturedJpeg,
      referenceJpeg: referenceJpeg,
    );
    return BiometricTestResult(
      isLive: liveness.isLive,
      livenessScore: liveness.livenessScore,
      isMatch: verify.isMatch,
      faceMatchScore: verify.faceMatchScore,
    );
  }

  Future<LivenessResult> checkLiveness(Uint8List jpegBytes) async {
    _ensureInitialized();
    if (jpegBytes.isEmpty) {
      throw FaceSdkException('La foto capturada está vacía.');
    }

    final prepared = _prepareImageForSdk(jpegBytes);
    Object? lastFailure;
    for (final attempt in [prepared, jpegBytes]) {
      try {
        return _estimateLivenessFromEncoded(attempt);
      } catch (e) {
        lastFailure = e;
        log('Intento de liveness falló, probando variante: $e');
      }
    }
    if (lastFailure is FaceSdkException) {
      throw lastFailure;
    }
    throw FaceSdkException('No se pudo validar liveness: $lastFailure');
  }

  Future<VerifyResult> verifyFace({
    required Uint8List capturedJpeg,
    required Uint8List referenceJpeg,
  }) async {
    _ensureInitialized();
    if (referenceJpeg.isEmpty) {
      throw FaceSdkException(
        'La foto de referencia del empleado no está disponible o viene vacía.',
      );
    }
    if (capturedJpeg.isEmpty) {
      throw FaceSdkException('La foto capturada está vacía.');
    }

    Context? verificationData;
    try {
      final resourceTemplate = _templateWithPreparedAndRawFallback(
        rawBytes: referenceJpeg,
        noFaceMessage:
            'No detectamos un rostro en la foto de referencia del empleado.',
      );
      final capturedTemplate = _templateWithPreparedAndRawFallback(
        rawBytes: capturedJpeg,
        noFaceMessage:
            'No detectamos un rostro en la foto capturada. Usa buena luz y mira de frente.',
      );

      verificationData = _facerecService!.createContext({
        'template1': {},
        'template2': {},
      });
      verificationData['template1']['template'].placeValues(resourceTemplate);
      verificationData['template2']['template'].placeValues(capturedTemplate);
      _verificationModule!.process(verificationData);

      final score = _toDouble(verificationData['result']['score'].get_value());
      log('3DiVi verify score=$score');
      return VerifyResult(
        isMatch: score >= BiometricConfig.faceMatchThreshold,
        faceMatchScore: score,
      );
    } on FaceSdkException {
      rethrow;
    } catch (e, st) {
      log('Error al verificar rostro: $e\n$st');
      throw FaceSdkException(
        'No pudimos completar la comparación (${e.runtimeType}): $e',
      );
    } finally {
      verificationData?.dispose();
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw FaceSdkException('FaceSDK no está inicializado.');
    }
  }

  Uint8List _prepareImageForSdk(Uint8List encoded) {
    try {
      final decoded = img.decodeImage(encoded);
      if (decoded == null) {
        return encoded;
      }
      var baked = img.bakeOrientation(decoded);
      final longest = baked.width > baked.height ? baked.width : baked.height;
      if (longest > _maxImageSide) {
        if (baked.width >= baked.height) {
          baked = img.copyResize(baked, width: _maxImageSide);
        } else {
          baked = img.copyResize(baked, height: _maxImageSide);
        }
      }
      return Uint8List.fromList(img.encodeJpg(baked, quality: 92));
    } catch (e) {
      log('Preparación de imagen omitida: $e');
      return encoded;
    }
  }

  LivenessResult _estimateLivenessFromEncoded(Uint8List encoded) {
    Context? ctx;
    try {
      ctx = _facerecService!.createContextFromEncodedImage(encoded);
      _faceDetector!.process(ctx);
      final objects = ctx['objects'];
      if (objects.len() == 0) {
        throw FaceSdkException(
          'No detectamos un rostro en la captura para validar liveness.',
        );
      }
      final w = _shapeLength(ctx['image']['shape'], 1);
      final h = _shapeLength(ctx['image']['shape'], 0);
      final idx = _largestFaceIndex(objects, w, h);
      _faceFitter!.process(ctx);
      _livenessEstimator!.process(ctx);
      final liveness = ctx['objects'][idx]['liveness'];
      final value = liveness['value'].get_value()?.toString();
      final info = liveness['info'].get_value()?.toString();
      final confidence = _toDouble(liveness['confidence'].get_value());
      log('Liveness value=$value info=$info confidence=$confidence');

      final isLive = _isRealLiveness(value, info);
      return LivenessResult(
        isLive: isLive,
        livenessScore: isLive ? (confidence > 0 ? confidence : 1.0) : confidence,
      );
    } on FaceSdkException {
      rethrow;
    } catch (e, st) {
      log('Error en liveness: $e\n$st');
      throw FaceSdkException(
        'No se pudo validar liveness (anti-spoofing): $e',
      );
    } finally {
      ctx?.dispose();
    }
  }

  bool _isRealLiveness(String? value, String? info) {
    final v = (value ?? '').toUpperCase();
    final i = (info ?? '').toUpperCase();
    return v == 'REAL' || i == 'REAL';
  }

  ContextTemplate _templateWithPreparedAndRawFallback({
    required Uint8List rawBytes,
    required String noFaceMessage,
  }) {
    final prepared = _prepareImageForSdk(rawBytes);
    Object? lastFailure;

    for (final attempt in [prepared, rawBytes]) {
      try {
        final t = _tryExtractTemplateFromEncoded(attempt);
        if (t != null) {
          return t;
        }
      } catch (e, st) {
        lastFailure = e;
        log('Intento de extracción falló, probando variante: $e\n$st');
      }
    }

    if (lastFailure != null) {
      throw FaceSdkException('Error al analizar la imagen: $lastFailure');
    }
    throw FaceSdkException(noFaceMessage);
  }

  ContextTemplate? _tryExtractTemplateFromEncoded(Uint8List encoded) {
    Context? ctx;
    try {
      ctx = _facerecService!.createContextFromEncodedImage(encoded);
      _faceDetector!.process(ctx);
      final objects = ctx['objects'];
      if (objects.len() == 0) {
        return null;
      }
      final w = _shapeLength(ctx['image']['shape'], 1);
      final h = _shapeLength(ctx['image']['shape'], 0);
      final idx = _largestFaceIndex(objects, w, h);
      if (objects.len() > 1) {
        log('${objects.len()} rostros en imagen; usando el de mayor área.');
      }
      _faceFitter!.process(ctx);
      _faceTemplateExtractor!.process(ctx);
      return ctx['objects'][idx]['face_template']['template'].get_value();
    } finally {
      ctx?.dispose();
    }
  }

  int _shapeLength(Context shape, int index) {
    final dynamic v = shape[index].get_value();
    if (v is int) {
      return v;
    }
    if (v is double) {
      return v.round();
    }
    return (v as num).round();
  }

  double _bboxArea(Context bbox, int width, int height) {
    final x0 = bbox[0].get_value() * width;
    final y0 = bbox[1].get_value() * height;
    final x1 = bbox[2].get_value() * width;
    final y1 = bbox[3].get_value() * height;
    return (x1 - x0).abs() * (y1 - y0).abs();
  }

  int _largestFaceIndex(Context objects, int width, int height) {
    final n = objects.len();
    if (n <= 1) {
      return 0;
    }
    var bestI = 0;
    var bestArea = _bboxArea(objects[0]['bbox'], width, height);
    for (var i = 1; i < n; i++) {
      final a = _bboxArea(objects[i]['bbox'], width, height);
      if (a > bestArea) {
        bestArea = a;
        bestI = i;
      }
    }
    return bestI;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0;
  }

  void _disposeNative() {
    try {
      _faceDetector?.dispose();
      _faceFitter?.dispose();
      _livenessEstimator?.dispose();
      _faceTemplateExtractor?.dispose();
      _verificationModule?.dispose();
      _facerecService?.dispose();
    } catch (e) {
      log('Error al liberar 3DiVi Face SDK: $e');
    }
    _faceDetector = null;
    _faceFitter = null;
    _livenessEstimator = null;
    _faceTemplateExtractor = null;
    _verificationModule = null;
    _facerecService = null;
    _initialized = false;
  }
}

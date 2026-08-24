import 'dart:typed_data';

import 'package:horas_hombre_mobile/services/face_sdk_service.dart';

class FaceMatchResult {
  const FaceMatchResult({
    required this.matched,
    required this.score,
    required this.isLive,
    this.livenessScore,
  });

  final bool matched;
  final double score;
  final bool isLive;
  final double? livenessScore;
}

abstract class FaceMatchService {
  Future<FaceMatchResult> compare(Uint8List stored, Uint8List captured);
}

/// Verificación 1:1 con 3DiVi Face SDK (liveness + match contra foto de referencia).
class DeviceFaceMatchService implements FaceMatchService {
  DeviceFaceMatchService(this._faceSdk);

  final FaceSdkService _faceSdk;

  @override
  Future<FaceMatchResult> compare(
    Uint8List stored,
    Uint8List captured,
  ) async {
    final liveness = await _faceSdk.checkLiveness(captured);
    if (!liveness.isLive) {
      return FaceMatchResult(
        matched: false,
        score: 0,
        isLive: false,
        livenessScore: liveness.livenessScore,
      );
    }

    final verify = await _faceSdk.verifyFace(
      capturedJpeg: captured,
      referenceJpeg: stored,
    );

    return FaceMatchResult(
      matched: verify.isMatch,
      score: verify.faceMatchScore,
      isLive: true,
      livenessScore: liveness.livenessScore,
    );
  }
}

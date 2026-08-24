import 'dart:typed_data';

/// Referencia biométrica local de un empleado (foto JPEG).
class FaceReference {
  const FaceReference({
    required this.numberUser,
    required this.userId,
    required this.imageJpeg,
    required this.cachedAt,
  });

  final int numberUser;
  final int userId;
  final Uint8List imageJpeg;
  final DateTime cachedAt;
}

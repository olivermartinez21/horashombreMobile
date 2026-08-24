import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:horas_hombre_mobile/models/employee.dart';
import 'package:horas_hombre_mobile/models/face_reference.dart';
import 'package:path_provider/path_provider.dart';

/// Cache local de fotos de referencia para verificación 1:1 (Fase 2).
class FaceReferenceRepository {
  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/face_references');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _metaPath(int numberUser) => 'ref_$numberUser.json';
  String _imagePath(int numberUser) => 'ref_$numberUser.jpg';

  Future<FaceReference?> getLocalReference(int numberUser) async {
    final dir = await _cacheDir();
    final metaFile = File('${dir.path}/${_metaPath(numberUser)}');
    final imageFile = File('${dir.path}/${_imagePath(numberUser)}');

    if (!await metaFile.exists() || !await imageFile.exists()) {
      return null;
    }

    try {
      final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final imageJpeg = await imageFile.readAsBytes();
      if (imageJpeg.isEmpty) return null;

      return FaceReference(
        numberUser: meta['numberUser'] as int,
        userId: meta['userId'] as int,
        imageJpeg: imageJpeg,
        cachedAt: DateTime.parse(meta['cachedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocalReference(FaceReference reference) async {
    if (reference.imageJpeg.isEmpty) return;

    final dir = await _cacheDir();
    final metaFile = File('${dir.path}/${_metaPath(reference.numberUser)}');
    final imageFile = File('${dir.path}/${_imagePath(reference.numberUser)}');

    await imageFile.writeAsBytes(reference.imageJpeg, flush: true);
    await metaFile.writeAsString(
      jsonEncode({
        'numberUser': reference.numberUser,
        'userId': reference.userId,
        'cachedAt': reference.cachedAt.toIso8601String(),
      }),
      flush: true,
    );
  }

  /// Guarda la foto del empleado obtenida del backend en cache local.
  Future<void> cacheFromEmployee(Employee employee) async {
    final photo = employee.photograph;
    if (photo == null || photo.isEmpty) return;

    await saveLocalReference(
      FaceReference(
        numberUser: employee.numberUser,
        userId: employee.userId,
        imageJpeg: photo,
        cachedAt: DateTime.now(),
      ),
    );
  }

  /// Foto de referencia: empleado en memoria o cache local.
  Future<Uint8List?> resolveReferenceImage(Employee employee) async {
    final fromEmployee = employee.photograph;
    if (fromEmployee != null && fromEmployee.isNotEmpty) {
      return fromEmployee;
    }

    final cached = await getLocalReference(employee.numberUser);
    return cached?.imageJpeg;
  }
}

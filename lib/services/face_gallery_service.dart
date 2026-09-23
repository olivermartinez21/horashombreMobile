import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:horas_hombre_mobile/models/employee.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/face_sdk_service.dart';
import 'package:path_provider/path_provider.dart';

/// Sincroniza fotos del backend, cachea templates 3DiVi y mantiene el índice 1:N.
class FaceGalleryService extends ChangeNotifier {
  FaceGalleryService({
    required ApiService api,
    required FaceSdkService faceSdk,
  })  : _api = api,
        _faceSdk = faceSdk;

  final ApiService _api;
  final FaceSdkService _faceSdk;

  final Map<int, Employee> _employeesByNumber = {};
  bool _syncing = false;
  String? _lastError;
  DateTime? _lastSyncedAt;

  bool get isSyncing => _syncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get cachedEmployeeCount => _employeesByNumber.length;
  bool get isReady => _faceSdk.hasIdentifyIndex;

  Employee? getByNumberUser(int numberUser) => _employeesByNumber[numberUser];

  Future<Directory> _rootDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/face_gallery');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _metaPath(Directory dir, int numberUser) =>
      '${dir.path}/meta_$numberUser.json';
  String _tplPath(Directory dir, int numberUser) =>
      '${dir.path}/tpl_$numberUser.bin';
  String _jpgPath(Directory dir, int numberUser) =>
      '${dir.path}/ref_$numberUser.jpg';
  String _indexMetaPath(Directory dir) => '${dir.path}/gallery_index.json';

  /// Carga templates locales al índice en memoria (sin red).
  Future<int> loadLocalIndex() async {
    if (!_faceSdk.isInitialized) return 0;

    final dir = await _rootDir();
    final entries = <({String uuid, Uint8List templateBytes})>[];
    _employeesByNumber.clear();

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('meta_') || !name.endsWith('.json')) continue;

      try {
        final meta =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final numberUser = meta['numberUser'] as int;
        final tplFile = File(_tplPath(dir, numberUser));
        if (!await tplFile.exists()) continue;

        final tplBytes = await tplFile.readAsBytes();
        if (tplBytes.isEmpty) continue;

        entries.add((uuid: numberUser.toString(), templateBytes: tplBytes));

        Uint8List? photo;
        final jpg = File(_jpgPath(dir, numberUser));
        if (await jpg.exists()) {
          photo = await jpg.readAsBytes();
        }

        _employeesByNumber[numberUser] = Employee(
          userId: meta['userId'] as int,
          numberUser: numberUser,
          firstName: meta['firstName'] as String? ?? '',
          lastName: meta['lastName'] as String? ?? '',
          secondLastName: meta['secondLastName'] as String?,
          departmentName: meta['departmentName'] as String?,
          photograph: photo,
          active: true,
          photoUpdatedAt: meta['photoUpdatedAt'] != null
              ? DateTime.tryParse(meta['photoUpdatedAt'] as String)
              : null,
        );
      } catch (e) {
        log('Meta de galería inválida: $e');
      }
    }

    if (entries.isEmpty) {
      _faceSdk.rebuildIdentifyIndex(const []);
      notifyListeners();
      return 0;
    }

    _faceSdk.rebuildIdentifyIndex(entries);
    notifyListeners();
    return entries.length;
  }

  /// Descarga galería del backend, actualiza templates solo si cambió la foto.
  Future<int> syncFromBackend({bool force = false}) async {
    if (_syncing) return cachedEmployeeCount;
    if (!_faceSdk.isInitialized) {
      _lastError = 'FaceSDK no inicializado';
      notifyListeners();
      return 0;
    }

    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      await loadLocalIndex();

      final remote = await _api.getFaceGallery();
      final dir = await _rootDir();
      final keepNumbers = <int>{};
      final entries = <({String uuid, Uint8List templateBytes})>[];
      _employeesByNumber.clear();

      for (final employee in remote) {
        if (employee.numberUser <= 0 || employee.userId <= 0) continue;
        final photo = employee.photograph;
        if (photo == null || photo.isEmpty) continue;

        keepNumbers.add(employee.numberUser);
        final versionKey = employee.photoVersionKey;
        final metaFile = File(_metaPath(dir, employee.numberUser));
        final tplFile = File(_tplPath(dir, employee.numberUser));
        final jpgFile = File(_jpgPath(dir, employee.numberUser));

        var needExtract = force || !await tplFile.exists();
        if (!needExtract && await metaFile.exists()) {
          try {
            final meta = jsonDecode(await metaFile.readAsString())
                as Map<String, dynamic>;
            if (meta['photoVersionKey'] != versionKey) {
              needExtract = true;
            }
          } catch (_) {
            needExtract = true;
          }
        }

        Uint8List? templateBytes;
        if (!needExtract) {
          templateBytes = await tplFile.readAsBytes();
          if (templateBytes.isEmpty) needExtract = true;
        }

        if (needExtract) {
          templateBytes = _faceSdk.extractTemplateBytes(photo);
          if (templateBytes == null || templateBytes.isEmpty) {
            log(
              'Sin template para numberUser=${employee.numberUser}; se omite',
            );
            continue;
          }
          await tplFile.writeAsBytes(templateBytes, flush: true);
          await jpgFile.writeAsBytes(photo, flush: true);
          await metaFile.writeAsString(
            jsonEncode({
              'userId': employee.userId,
              'numberUser': employee.numberUser,
              'firstName': employee.firstName,
              'lastName': employee.lastName,
              'secondLastName': employee.secondLastName,
              'departmentName': employee.departmentName,
              'photoVersionKey': versionKey,
              'photoUpdatedAt': employee.photoUpdatedAt?.toIso8601String(),
            }),
            flush: true,
          );
        }

        entries.add((
          uuid: employee.numberUser.toString(),
          templateBytes: templateBytes!,
        ));
        _employeesByNumber[employee.numberUser] = employee;
      }

      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final match = RegExp(r'^(meta|tpl|ref)_(\d+)\.').firstMatch(name);
        if (match == null) continue;
        final number = int.tryParse(match.group(2)!);
        if (number != null && !keepNumbers.contains(number)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }

      _faceSdk.rebuildIdentifyIndex(entries);
      _lastSyncedAt = DateTime.now();
      await File(_indexMetaPath(dir)).writeAsString(
        jsonEncode({
          'syncedAt': _lastSyncedAt!.toIso8601String(),
          'count': entries.length,
        }),
        flush: true,
      );
      log('Galería facial sincronizada: ${entries.length} empleados');
      return entries.length;
    } catch (e, st) {
      _lastError = e.toString();
      log('Error sync galería: $e\n$st');
      try {
        await loadLocalIndex();
      } catch (_) {}
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}

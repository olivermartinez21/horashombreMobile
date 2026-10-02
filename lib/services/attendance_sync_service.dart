import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/models/attendance_delivery.dart';
import 'package:horas_hombre_mobile/models/pending_attendance.dart';
import 'package:horas_hombre_mobile/services/api_service.dart';
import 'package:horas_hombre_mobile/services/attendance_queue_repository.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceSyncService extends ChangeNotifier with WidgetsBindingObserver {
  AttendanceSyncService({
    required ApiService api,
    AttendanceQueueRepository? queue,
  }) : _api = api,
       _queue = queue ?? AttendanceQueueRepository();

  static const _deviceIdKey = 'kiosk_device_id';

  final ApiService _api;
  final AttendanceQueueRepository _queue;

  final List<PendingAttendance> _items = [];
  Timer? _timer;
  Future<void> _tail = Future<void>.value();
  bool _started = false;
  bool _observing = false;
  bool _syncing = false;
  String? _lastError;
  String? _lastSyncNotice;

  List<PendingAttendance> get items => List.unmodifiable(_items);
  bool get isSyncing => _syncing;
  String? get lastError => _lastError;
  String? get lastSyncNotice => _lastSyncNotice;
  int get pendingCount => _items.length;
  int get conflictCount => _items.where((item) => item.isConflict).length;

  void start() {
    if (_started) return;
    _started = true;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      flush();
    });
    flush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      flush();
    }
  }

  /// Guarda la marca en el dispositivo y, si hay red, la envía de inmediato.
  Future<AttendanceDeliveryResult> capture(AttendanceRecord record) {
    return _serialized(() async {
      final deviceId = await _deviceId();
      final offlineEventId = _newId();
      await _queue.enqueue(
        PendingAttendance.fromRecord(
          record,
          offlineEventId: offlineEventId,
          deviceId: deviceId,
        ),
      );
      await _reload();

      List<AttendanceSyncItemResult> results = const [];
      try {
        results = await _flushUnlocked();
      } catch (e) {
        if (!_isRetryable(e)) {
          await _reload();
          return AttendanceDeliveryResult(
            success: false,
            title: 'No se pudo registrar',
            message:
                '${_errorText(e)} La marca quedó guardada en el kiosko.',
          );
        }
      }

      final mine = _resultFor(results, offlineEventId);
      final still = await _queue.find(offlineEventId);
      await _reload();
      if (mine != null) {
        return _deliveryFor(mine, still);
      }
      if (still == null) {
        return const AttendanceDeliveryResult(
          success: true,
          title: '¡Registro exitoso!',
          message: 'Asistencia guardada correctamente',
        );
      }
      if (still.isConflict) {
        return AttendanceDeliveryResult(
          success: false,
          title: 'Marca en conflicto',
          message: still.serverMessage ??
              'La marca no se aplicó porque choca con un registro ya existente. '
                  'Quedó guardada en el kiosko.',
        );
      }
      return const AttendanceDeliveryResult(
        success: true,
        title: 'Guardado en el kiosko',
        message:
            'Sin conexión. La marca quedó en el dispositivo y se enviará al reconectar.',
      );
    });
  }

  Future<void> flush() {
    return _serialized(() async {
      try {
        await _flushUnlocked();
      } catch (e) {
        _lastError = _isRetryable(e) ? null : _errorText(e);
        debugPrint('Sync asistencia: $e');
        notifyListeners();
      }
    });
  }

  Future<void> discard(String offlineEventId) {
    return _serialized(() async {
      await _queue.delete(offlineEventId);
      await _reload();
    });
  }

  Future<List<AttendanceSyncItemResult>> _flushUnlocked() async {
    final pending = await _queue.all();
    if (pending.isEmpty) {
      await _reload();
      return const [];
    }

    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final deviceId = await _deviceId();
      final results = await _api.syncAttendance(
        pending.map((item) => item.toSyncJson()).toList(),
        deviceId: deviceId,
      );
      final known = pending.map((item) => item.offlineEventId).toSet();
      var applied = 0;
      var reviews = 0;
      var conflicts = 0;

      for (final result in results) {
        final id = result.offlineEventId;
        if (id == null || !known.contains(id)) continue;
        switch (result.status) {
          case 'APPLIED':
          case 'DUPLICATE':
          case 'REJECTED':
            await _queue.delete(id);
            if (result.status == 'APPLIED') applied++;
            if (result.status == 'REJECTED') _lastError = result.message;
          case 'PENDING':
            await _queue.delete(id);
            reviews++;
          case 'CONFLICT':
            await _queue.mark(
              id,
              PendingAttendanceStatus.conflict,
              result.message,
            );
            conflicts++;
          default:
            await _queue.mark(
              id,
              PendingAttendanceStatus.pending,
              result.message,
            );
        }
      }

      if (applied + reviews + conflicts > 0) {
        final parts = <String>[
          if (applied > 0) '$applied nueva${applied == 1 ? '' : 's'}',
          if (reviews > 0)
            '$reviews en revisión del administrador',
          if (conflicts > 0) '$conflicts en conflicto',
        ];
        _lastSyncNotice = 'Última sincronización: ${parts.join(', ')}.';
      }
      return results;
    } finally {
      _syncing = false;
      await _reload();
    }
  }

  AttendanceDeliveryResult _deliveryFor(
    AttendanceSyncItemResult result,
    PendingAttendance? still,
  ) {
    switch (result.status) {
      case 'APPLIED':
        return AttendanceDeliveryResult(
          success: true,
          title: '¡Registro exitoso!',
          message: result.message.isEmpty
              ? 'Asistencia guardada correctamente'
              : result.message,
        );
      case 'DUPLICATE':
        return const AttendanceDeliveryResult(
          success: true,
          title: 'Marca ya registrada',
          message: 'Ya había un registro de esta marca. No se duplicó.',
        );
      case 'PENDING':
        return AttendanceDeliveryResult(
          success: true,
          title: 'Enviada a revisión',
          message: result.message.isEmpty
              ? 'Un administrador debe aceptarla en Asistencias.'
              : result.message,
        );
      case 'CONFLICT':
        return AttendanceDeliveryResult(
          success: false,
          title: 'Marca en conflicto',
          message: result.message.isEmpty
              ? (still?.serverMessage ??
                  'La marca quedó guardada en el kiosko para revisión.')
              : result.message,
        );
      default:
        return AttendanceDeliveryResult(
          success: false,
          title: 'No se pudo registrar',
          message: result.message.isEmpty
              ? 'El servidor rechazó la marca.'
              : result.message,
        );
    }
  }

  AttendanceSyncItemResult? _resultFor(
    List<AttendanceSyncItemResult> results,
    String offlineEventId,
  ) {
    for (final result in results) {
      if (result.offlineEventId == offlineEventId) return result;
    }
    return null;
  }

  Future<void> _reload() async {
    final items = await _queue.all();
    _items
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _newId();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  bool _isRetryable(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is http.ClientException) {
      return true;
    }
    if (error is ApiException) {
      final code = error.statusCode;
      if (code == null ||
          code == 404 ||
          code == 408 ||
          code == 429 ||
          code >= 500) {
        return true;
      }
    }
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused') ||
        text.contains('Network is unreachable');
  }

  String _errorText(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}

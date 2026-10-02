import 'dart:convert';

import 'package:horas_hombre_mobile/config/app_config.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/models/employee.dart';
import 'package:horas_hombre_mobile/models/location.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AttendanceSyncItemResult {
  const AttendanceSyncItemResult({
    required this.offlineEventId,
    required this.status,
    required this.message,
  });

  final String? offlineEventId;
  final String status;
  final String message;
}

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
      : _baseUrl = _normalizeBaseUrl(baseUrl ?? AppConfig.baseUrl),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  static String _normalizeBaseUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<Employee> getEmployee(int numberUser) async {
    final uri = Uri.parse('$_baseUrl/attendance/employee/$numberUser');
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 404) {
      throw ApiException('Empleado no encontrado', statusCode: 404);
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Error al consultar empleado (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return Employee.fromJson(json);
  }

  /// Empleados activos con foto para índice 1:N.
  Future<List<Employee>> getFaceGallery() async {
    final uri = Uri.parse('$_baseUrl/attendance/face-gallery');
    final response = await _client.get(uri).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw ApiException(
        'Error al sincronizar galería facial (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw ApiException('Respuesta de galería facial inválida');
    }

    final employees = <Employee>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        employees.add(Employee.fromJson(item));
      } else if (item is Map) {
        employees.add(Employee.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return employees;
  }

  Future<List<KioskLocation>> getLocations() async {
    final uri = Uri.parse('$_baseUrl/attendance/locations');
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(
        'Error al consultar ubicaciones (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw ApiException('Respuesta de ubicaciones inválida');
    }

    return decoded.map((item) {
      if (item is Map<String, dynamic>) {
        return KioskLocation.fromJson(item);
      }
      if (item is Map) {
        return KioskLocation.fromJson(Map<String, dynamic>.from(item));
      }
      throw ApiException('Ubicación inválida en catálogo');
    }).where((location) => location.active && location.locationName.isNotEmpty).toList();
  }

  Future<String> saveAttendance(AttendanceRecord record) async {
    final uri = Uri.parse('$_baseUrl/attendance/save');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(record.toJson()),
        )
        .timeout(_timeout);

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    final success = body?['success'] as bool? ?? false;
    final message = body?['message'] as String?;

    if (response.statusCode == 200 && success) {
      return message ?? 'Asistencia guardada correctamente';
    }

    throw ApiException(
      message ?? 'No se pudo guardar la asistencia',
      statusCode: response.statusCode,
    );
  }

  /// Envía marcas guardadas en el dispositivo. El servidor responde por evento.
  Future<List<AttendanceSyncItemResult>> syncAttendance(
    List<Map<String, dynamic>> events, {
    required String deviceId,
  }) async {
    final uri = Uri.parse('$_baseUrl/attendance/sync');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'deviceId': deviceId,
            'events': events,
          }),
        )
        .timeout(const Duration(seconds: 60));

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else if (decoded is Map) {
        body = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200 || body == null) {
      throw ApiException(
        'No se pudo sincronizar la asistencia (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final rawResults = body['results'];
    if (rawResults is! List) {
      throw ApiException('Respuesta de sincronización inválida');
    }

    return rawResults.map((item) {
      final map = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      return AttendanceSyncItemResult(
        offlineEventId: map['offlineEventId'] as String?,
        status: map['status'] as String? ?? '',
        message: map['message'] as String? ?? '',
      );
    }).toList();
  }

  void dispose() => _client.close();
}

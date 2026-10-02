import 'package:horas_hombre_mobile/models/attendance.dart';

class PendingAttendance {
  const PendingAttendance({
    required this.offlineEventId,
    required this.userId,
    required this.type,
    required this.attendanceDate,
    required this.attendanceTime,
    required this.deviceId,
    required this.status,
    required this.createdAt,
    this.employeeName,
    this.locationId,
    this.locationName,
    this.serverMessage,
  });

  final String offlineEventId;
  final int userId;
  final String? employeeName;
  final AttendanceType type;
  final String attendanceDate;
  final String attendanceTime;
  final int? locationId;
  final String? locationName;
  final String deviceId;
  final String status;
  final String? serverMessage;
  final DateTime createdAt;

  bool get isConflict => status == PendingAttendanceStatus.conflict;

  String get displayName {
    final name = employeeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Empleado $userId';
  }

  Map<String, dynamic> toSyncJson() {
    return {
      'userId': userId,
      'attendanceDate': attendanceDate,
      'attendanceTime': attendanceTime,
      'attendanceType': type.apiValue,
      'captureSource': 'MOVIL',
      'offlineEventId': offlineEventId,
      'deviceId': deviceId,
      if (locationId != null) 'locationId': locationId,
      if (locationName != null && locationName!.isNotEmpty)
        'locationName': locationName,
    };
  }

  Map<String, Object?> toDbMap() {
    return {
      'offline_event_id': offlineEventId,
      'user_id': userId,
      'employee_name': employeeName,
      'attendance_type': type.apiValue,
      'attendance_date': attendanceDate,
      'attendance_time': attendanceTime,
      'location_id': locationId,
      'location_name': locationName,
      'device_id': deviceId,
      'status': status,
      'server_message': serverMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PendingAttendance.fromRecord(
    AttendanceRecord record, {
    required String offlineEventId,
    required String deviceId,
  }) {
    final json = record
        .copyWith(offlineEventId: offlineEventId, deviceId: deviceId)
        .toJson();
    return PendingAttendance(
      offlineEventId: offlineEventId,
      userId: record.userId,
      employeeName: record.employeeName,
      type: record.type,
      attendanceDate: json['attendanceDate'] as String,
      attendanceTime: json['attendanceTime'] as String,
      locationId: record.locationId,
      locationName: record.locationName,
      deviceId: deviceId,
      status: PendingAttendanceStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  factory PendingAttendance.fromDbMap(Map<String, Object?> map) {
    final type = AttendanceType.fromApiValue(map['attendance_type'] as String?);
    return PendingAttendance(
      offlineEventId: map['offline_event_id'] as String,
      userId: map['user_id'] as int,
      employeeName: map['employee_name'] as String?,
      type: type ?? AttendanceType.entrada,
      attendanceDate: map['attendance_date'] as String,
      attendanceTime: map['attendance_time'] as String,
      locationId: map['location_id'] as int?,
      locationName: map['location_name'] as String?,
      deviceId: map['device_id'] as String,
      status: map['status'] as String? ?? PendingAttendanceStatus.pending,
      serverMessage: map['server_message'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

abstract final class PendingAttendanceStatus {
  static const pending = 'pending';
  static const conflict = 'conflict';
}

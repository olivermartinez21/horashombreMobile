import 'package:intl/intl.dart';

enum AttendanceType {
  entrada('ENTRADA'),
  salida('SALIDA');

  const AttendanceType(this.apiValue);
  final String apiValue;

  String get label => switch (this) {
        AttendanceType.entrada => 'Entrada',
        AttendanceType.salida => 'Salida',
      };

  static AttendanceType? fromApiValue(String? value) {
    return switch (value) {
      'ENTRADA' => AttendanceType.entrada,
      'SALIDA' => AttendanceType.salida,
      _ => null,
    };
  }
}

class AttendanceRecord {
  AttendanceRecord({
    required this.userId,
    required this.type,
    this.locationId,
    this.locationName,
    this.employeeName,
    this.offlineEventId,
    this.deviceId,
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  final int userId;
  final AttendanceType type;
  final int? locationId;
  final String? locationName;
  final String? employeeName;
  final String? offlineEventId;
  final String? deviceId;
  final DateTime dateTime;

  AttendanceRecord copyWith({
    String? offlineEventId,
    String? deviceId,
  }) {
    return AttendanceRecord(
      userId: userId,
      type: type,
      locationId: locationId,
      locationName: locationName,
      employeeName: employeeName,
      offlineEventId: offlineEventId ?? this.offlineEventId,
      deviceId: deviceId ?? this.deviceId,
      dateTime: dateTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'attendanceDate': DateFormat('yyyy-MM-dd').format(dateTime),
      'attendanceTime': DateFormat('HH:mm:ss').format(dateTime),
      'attendanceType': type.apiValue,
      'captureSource': 'MOVIL',
      if (locationId != null) 'locationId': locationId,
      if (locationName != null && locationName!.isNotEmpty)
        'locationName': locationName,
      if (offlineEventId != null) 'offlineEventId': offlineEventId,
      if (deviceId != null) 'deviceId': deviceId,
    };
  }
}

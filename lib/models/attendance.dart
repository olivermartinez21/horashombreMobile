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
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  final int userId;
  final AttendanceType type;
  final int? locationId;
  final String? locationName;
  final DateTime dateTime;

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
    };
  }
}

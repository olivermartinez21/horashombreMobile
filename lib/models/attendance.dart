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
}

class AttendanceRecord {
  AttendanceRecord({
    required this.userId,
    required this.type,
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  final int userId;
  final AttendanceType type;
  final DateTime dateTime;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'attendanceDate': DateFormat('yyyy-MM-dd').format(dateTime),
      'attendanceTime': DateFormat('HH:mm:ss').format(dateTime),
      'attendanceType': type.apiValue,
    };
  }
}

class AttendanceDeliveryResult {
  const AttendanceDeliveryResult({
    required this.success,
    required this.title,
    required this.message,
  });

  final bool success;
  final String title;
  final String message;
}

import 'dart:convert';

/// Payload formal del QR de asistencia (Fase 2).
///
/// Formatos soportados:
/// - Número plano: `12345`
/// - JSON: `{"numberUser": 12345}` o `{"employeeId": 12345}`
class QrPayload {
  const QrPayload({required this.numberUser});

  final int numberUser;

  /// Parsea el texto crudo del QR. Devuelve `null` si no es válido.
  static QrPayload? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final asInt = int.tryParse(trimmed);
    if (asInt != null && asInt > 0) {
      return QrPayload(numberUser: asInt);
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;

      final dynamic id =
          decoded['numberUser'] ?? decoded['employeeId'] ?? decoded['id'];
      if (id is int && id > 0) {
        return QrPayload(numberUser: id);
      }
      if (id is num && id > 0) {
        return QrPayload(numberUser: id.toInt());
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}

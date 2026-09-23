import 'dart:convert';
import 'dart:typed_data';

class Employee {
  Employee({
    required this.userId,
    required this.numberUser,
    required this.firstName,
    required this.lastName,
    this.secondLastName,
    this.departmentName,
    this.photograph,
    this.active,
    this.photoUpdatedAt,
  });

  final int userId;
  final int numberUser;
  final String firstName;
  final String lastName;
  final String? secondLastName;
  final String? departmentName;
  final Uint8List? photograph;
  final bool? active;

  /// Fecha de carga de la foto (backend usa eventDate = uploadDate de hh_files).
  final DateTime? photoUpdatedAt;

  String get fullName {
    final parts = [
      firstName,
      lastName,
      if (secondLastName != null && secondLastName!.isNotEmpty) secondLastName,
    ];
    return parts.join(' ').trim();
  }

  /// Clave de versión para invalidar templates locales.
  String get photoVersionKey {
    final ms = photoUpdatedAt?.millisecondsSinceEpoch ?? 0;
    return '$userId-$numberUser-$ms';
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      userId: _asInt(json['userId']) ?? 0,
      numberUser: _asInt(json['numberUser']) ?? 0,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      secondLastName: json['secondLastName'] as String?,
      departmentName: json['departmentName'] as String?,
      photograph: _parsePhotograph(json['photograph']),
      active: json['active'] as bool?,
      photoUpdatedAt: _parseDate(json['eventDate'] ?? json['photoUpdatedAt']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static Uint8List? _parsePhotograph(dynamic value) {
    if (value == null) return null;

    if (value is String && value.isNotEmpty) {
      try {
        return base64Decode(value);
      } catch (_) {
        return null;
      }
    }

    if (value is List) {
      final bytes = <int>[];
      for (final item in value) {
        if (item is int) {
          bytes.add(item);
        } else if (item is num) {
          bytes.add(item.toInt());
        }
      }
      if (bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    }

    return null;
  }
}

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
  });

  final int userId;
  final int numberUser;
  final String firstName;
  final String lastName;
  final String? secondLastName;
  final String? departmentName;
  final Uint8List? photograph;
  final bool? active;

  String get fullName {
    final parts = [
      firstName,
      lastName,
      if (secondLastName != null && secondLastName!.isNotEmpty) secondLastName,
    ];
    return parts.join(' ').trim();
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      userId: json['userId'] as int,
      numberUser: json['numberUser'] as int,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      secondLastName: json['secondLastName'] as String?,
      departmentName: json['departmentName'] as String?,
      photograph: _parsePhotograph(json['photograph']),
      active: json['active'] as bool?,
    );
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

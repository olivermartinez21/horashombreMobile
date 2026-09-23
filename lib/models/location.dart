class KioskLocation {
  const KioskLocation({
    required this.locationId,
    required this.locationName,
    this.active = true,
  });

  final int locationId;
  final String locationName;
  final bool active;

  factory KioskLocation.fromJson(Map<String, dynamic> json) {
    final id = json['locationId'];
    return KioskLocation(
      locationId: id is int ? id : (id as num).toInt(),
      locationName: json['locationName'] as String? ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationId': locationId,
      'locationName': locationName,
      'active': active,
    };
  }
}

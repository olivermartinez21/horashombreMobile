import 'package:flutter/foundation.dart';
import 'package:horas_hombre_mobile/models/attendance.dart';
import 'package:horas_hombre_mobile/models/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _kAttendanceType = 'kiosk_attendance_type';
  static const _kLocationId = 'kiosk_location_id';
  static const _kLocationName = 'kiosk_location_name';

  bool _loaded = false;
  AttendanceType? _kioskEventType;
  int? _locationId;
  String? _locationName;

  bool get isLoaded => _loaded;
  AttendanceType? get kioskEventType => _kioskEventType;
  int? get locationId => _locationId;
  String? get locationName => _locationName;

  KioskLocation? get selectedLocation {
    final id = _locationId;
    final name = _locationName;
    if (id == null || name == null || name.isEmpty) return null;
    return KioskLocation(locationId: id, locationName: name);
  }

  bool get isKioskConfigured =>
      _kioskEventType != null && _locationId != null && _locationName != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _kioskEventType = AttendanceType.fromApiValue(
      prefs.getString(_kAttendanceType),
    );
    _locationId = prefs.getInt(_kLocationId);
    _locationName = prefs.getString(_kLocationName);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setKioskEventType(AttendanceType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAttendanceType, type.apiValue);
    _kioskEventType = type;
    notifyListeners();
  }

  Future<void> setSelectedLocation(KioskLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLocationId, location.locationId);
    await prefs.setString(_kLocationName, location.locationName);
    _locationId = location.locationId;
    _locationName = location.locationName;
    notifyListeners();
  }

  Future<void> clearSelectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLocationId);
    await prefs.remove(_kLocationName);
    _locationId = null;
    _locationName = null;
    notifyListeners();
  }
}

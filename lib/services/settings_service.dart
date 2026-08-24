import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    await SharedPreferences.getInstance();
    _loaded = true;
    notifyListeners();
  }
}

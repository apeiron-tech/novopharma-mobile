import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  Locale? _locale;
  static const String _languageCodeKey = 'languageCode';

  Locale? get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  void _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageCodeKey);
    if (languageCode != null) {
      _locale = Locale(languageCode);
    } else {
      _locale = const Locale('fr'); // Default to French
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, locale.languageCode);
  }

  void toggleLocale() {
    if (_locale == const Locale('en')) {
      setLocale(const Locale('fr'));
    } else {
      setLocale(const Locale('en'));
    }
  }
}

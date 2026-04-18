import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { vi, en }

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  AppLanguage _language = AppLanguage.vi;
  SharedPreferences? _prefs;

  AppLanguage get language => _language;
  String get languageCode => _language == AppLanguage.vi ? 'vi' : 'en';
  String get languageDisplay => _language == AppLanguage.vi ? 'VN' : 'EN';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedLanguage = _prefs?.getString(_languageKey);
    if (savedLanguage != null) {
      _language = savedLanguage == 'en' ? AppLanguage.en : AppLanguage.vi;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _prefs?.setString(
      _languageKey,
      language == AppLanguage.en ? 'en' : 'vi',
    );
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    await setLanguage(
      _language == AppLanguage.vi ? AppLanguage.en : AppLanguage.vi,
    );
  }
}

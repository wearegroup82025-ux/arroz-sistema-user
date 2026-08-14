import 'package:flutter/foundation.dart';

enum AppLanguage {
  tagalog,
  english,
}

class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.tagalog;

  AppLanguage get language => _language;

  bool get isTagalog => _language == AppLanguage.tagalog;

  bool get isEnglish => _language == AppLanguage.english;

  String get languageName {
    switch (_language) {
      case AppLanguage.tagalog:
        return "Tagalog";

      case AppLanguage.english:
        return "English";
    }
  }

  void setLanguage(AppLanguage language) {
    if (_language == language) return;

    _language = language;
    notifyListeners();
  }

  void toggleLanguage() {
    _language = _language == AppLanguage.tagalog
        ? AppLanguage.english
        : AppLanguage.tagalog;

    notifyListeners();
  }
}
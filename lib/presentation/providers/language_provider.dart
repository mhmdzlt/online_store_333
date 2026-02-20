import 'package:flutter/material.dart';

import '../../utils/local_storage.dart';

class LanguageProvider extends ChangeNotifier {
  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('ckb'),
    Locale('ku'),
  ];

  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  Locale get frameworkLocale {
    if (_locale.languageCode == 'en') {
      return const Locale('en');
    }
    return const Locale('ar');
  }

  bool get isRtl =>
      _locale.languageCode == 'ar' || _locale.languageCode == 'ckb';

  String get languageLabel {
    switch (_locale.languageCode) {
      case 'en':
        return 'English';
      case 'ckb':
        return 'کوردی سۆرانی';
      case 'ku':
        return 'Kurdî Kurmancî';
      case 'ar':
      default:
        return 'العربية';
    }
  }

  Future<void> loadSavedLanguage() async {
    final code = await LocalStorage.getAppLanguageCode();
    final matched = supportedLocales.where((l) => l.languageCode == code);
    _locale = matched.isNotEmpty ? matched.first : const Locale('ar');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final exists = supportedLocales.any(
      (item) => item.languageCode == locale.languageCode,
    );
    if (!exists) return;
    if (_locale.languageCode == locale.languageCode) return;

    _locale = Locale(locale.languageCode);
    await LocalStorage.saveAppLanguageCode(_locale.languageCode);
    notifyListeners();
  }
}

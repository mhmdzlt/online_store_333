import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../presentation/providers/language_provider.dart';

extension LanguageTextX on BuildContext {
  String currentLanguageCode({bool watch = true}) {
    if (watch) {
      try {
        return select<LanguageProvider, String>((p) => p.locale.languageCode);
      } catch (_) {
        return read<LanguageProvider>().locale.languageCode;
      }
    }
    return read<LanguageProvider>().locale.languageCode;
  }

  String tr({
    required String ar,
    required String en,
    required String ckb,
    required String ku,
    bool watch = true,
  }) {
    final code = currentLanguageCode(watch: watch);
    switch (code) {
      case 'en':
        return en;
      case 'ckb':
        return ckb;
      case 'ku':
        return ku;
      case 'ar':
      default:
        return ar;
    }
  }
}

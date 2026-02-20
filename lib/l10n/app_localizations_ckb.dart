// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Central Kurdish (`ckb`).
class AppLocalizationsCkb extends AppLocalizations {
  AppLocalizationsCkb([String locale = 'ckb']) : super(locale);

  @override
  String get appTitle => 'فرۆشگای ئۆتۆمبێل';

  @override
  String get brandName => 'Karza';

  @override
  String get home => 'سەرەکی';

  @override
  String get cart => 'سەبەتە';

  @override
  String get freebies => 'بەخششەکان';

  @override
  String get more => 'زیاتر';

  @override
  String get notifications => 'ئاگادارکردنەوەکان';

  @override
  String get exitAppTitle => 'دەتەوێت لە Karza بچیتە دەرەوە؟';

  @override
  String get exitAppMessage => 'بۆ پشتڕاستکردنەوە کرتە لە \"دەرچوون\" بکە.';

  @override
  String get exitAppConfirm => 'دەرچوون';

  @override
  String get imageSearch => 'گەڕان بە وێنە';

  @override
  String get cancel => 'هەڵوەشاندنەوە';

  @override
  String get imageSearchNoResults => 'گەڕانی وێنە بێ ئەنجام';

  @override
  String imageSearchResults(Object count) {
    return 'گەڕانی وێنە ($count ئەنجام)';
  }

  @override
  String get categories => 'بەشەکان';

  @override
  String get addToCart => 'زیادکردن بۆ سەبەت';

  @override
  String get price => 'نرخ';

  @override
  String get searchHint => 'گەڕان بۆ پارچەی یەدەک...';

  @override
  String get homeSearchOnMarketplace => 'گەڕان لە بازاڕ';

  @override
  String get homeQuickNewRequest => 'داواکاری نوێ';

  @override
  String get homeQuickOffers => 'ئۆفەرەکان';

  @override
  String get homeQuickSections => 'بەشەکان';

  @override
  String get homeQuickOrders => 'داواکاریەکان';
}

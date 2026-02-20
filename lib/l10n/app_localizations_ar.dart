// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'متجر السيارات';

  @override
  String get brandName => 'كرزة';

  @override
  String get home => 'الرئيسية';

  @override
  String get cart => 'عربة التسوق';

  @override
  String get freebies => 'الهبات المجانية';

  @override
  String get more => 'المزيد';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get exitAppTitle => 'هل تريد الخروج من كرزة؟';

  @override
  String get exitAppMessage => 'اضغط \"خروج من التطبيق\" لتأكيد الخروج.';

  @override
  String get exitAppConfirm => 'خروج من التطبيق';

  @override
  String get imageSearch => 'بحث بالصورة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get imageSearchNoResults => 'بحث بالصورة بدون نتائج';

  @override
  String imageSearchResults(Object count) {
    return 'بحث بالصورة ($count نتيجة)';
  }

  @override
  String get categories => 'الأقسام';

  @override
  String get addToCart => 'أضف إلى العربة';

  @override
  String get price => 'السعر';

  @override
  String get searchHint => 'ابحث عن قطع الغيار...';

  @override
  String get homeSearchOnMarketplace => 'ابحث في السوق';

  @override
  String get homeQuickNewRequest => 'طلب جديد';

  @override
  String get homeQuickOffers => 'العروض';

  @override
  String get homeQuickSections => 'الأقسام';

  @override
  String get homeQuickOrders => 'الطلبات';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Car Store';

  @override
  String get brandName => 'Karza';

  @override
  String get home => 'Home';

  @override
  String get cart => 'Cart';

  @override
  String get freebies => 'Freebies';

  @override
  String get more => 'More';

  @override
  String get notifications => 'Notifications';

  @override
  String get exitAppTitle => 'Do you want to exit Karza?';

  @override
  String get exitAppMessage => 'Press \"Exit App\" to confirm.';

  @override
  String get exitAppConfirm => 'Exit App';

  @override
  String get imageSearch => 'Image search';

  @override
  String get cancel => 'Cancel';

  @override
  String get imageSearchNoResults => 'Image search with no results';

  @override
  String imageSearchResults(Object count) {
    return 'Image search ($count results)';
  }

  @override
  String get categories => 'Sections';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get price => 'Price';

  @override
  String get searchHint => 'Search for spare parts...';

  @override
  String get homeSearchOnMarketplace => 'Search in marketplace';

  @override
  String get homeQuickNewRequest => 'New request';

  @override
  String get homeQuickOffers => 'Offers';

  @override
  String get homeQuickSections => 'Sections';

  @override
  String get homeQuickOrders => 'Orders';
}

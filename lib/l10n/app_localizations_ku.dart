// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kurdish (`ku`).
class AppLocalizationsKu extends AppLocalizations {
  AppLocalizationsKu([String locale = 'ku']) : super(locale);

  @override
  String get appTitle => 'Firotgeha Erebeyan';

  @override
  String get brandName => 'Karza';

  @override
  String get home => 'Sereke';

  @override
  String get cart => 'Sepet';

  @override
  String get freebies => 'Diyari';

  @override
  String get more => 'Zêdetir';

  @override
  String get notifications => 'Agahdari';

  @override
  String get exitAppTitle => 'Tu dixwazî ji Karza derkeve?';

  @override
  String get exitAppMessage => 'Ji bo piştrastkirinê li \"Derketin\" bitikîne.';

  @override
  String get exitAppConfirm => 'Derkeve';

  @override
  String get imageSearch => 'Lêgerîna bi wêne';

  @override
  String get cancel => 'Betal bike';

  @override
  String get imageSearchNoResults => 'Lêgerîna wêneyê bê encam';

  @override
  String imageSearchResults(Object count) {
    return 'Lêgerîna wêneyê ($count encam)';
  }

  @override
  String get categories => 'Beş';

  @override
  String get addToCart => 'Tevlî sepêtê bike';

  @override
  String get price => 'Buhayî';

  @override
  String get searchHint => 'Li parçeyên yedek bigere...';

  @override
  String get homeSearchOnMarketplace => 'Li bazarê bigere';

  @override
  String get homeQuickNewRequest => 'Daxwaza nû';

  @override
  String get homeQuickOffers => 'Pêşniyar';

  @override
  String get homeQuickSections => 'Beş';

  @override
  String get homeQuickOrders => 'Daxwaz';
}

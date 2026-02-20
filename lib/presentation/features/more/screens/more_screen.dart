import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/auth_service.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';

const bool kEnablePartsBrowser = true;

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _authBusy = false;
  String? _currentUserEmail;
  StreamSubscription<AuthState>? _authSubscription;
  late final SupabaseClient _supabaseClient;
  String _appVersion = '1.0.0';
  Map<String, String> _appNameText = {
    'ar': 'متجر + هبات مجانية',
    'en': 'Store + Freebies',
    'ckb': 'فرۆشگا + بەخششە خۆڕاییەکان',
    'ku': 'Firotgeh + Diyariyên Belaş',
  };
  Map<String, String> _aboutText = {
    'ar':
        'تطبيق بسيط للتسوق والهبات المجانية ويدعم الدخول كزائر أو عبر حساب جوجل.',
    'en':
        'A simple shopping and freebies app that supports guest mode and Google sign-in.',
    'ckb':
        'بەرنامەیەکی سادەی کڕین و بەخششە خۆڕاییەکانە کە دۆخی میوان و چوونەژوورەوە بە گووگڵ پشتگیری دەکات.',
    'ku':
        'Uygulamek hêsan ji bo kirîn û diyariyên belaş e ku moda mêvan û têketina Google piştgirî dike.',
  };
  Map<String, String> _privacyText = {
    'ar': 'نص تجريبي لسياسة الخصوصية.',
    'en': 'Sample privacy policy text.',
    'ckb': 'دەقی نموونەیی بۆ سیاسەتی تایبەتمەندی.',
    'ku': 'Nivîsa mînakî ya siyaseta taybetîtiyê.',
  };
  Map<String, String> _termsText = {
    'ar': 'نص تجريبي للشروط والأحكام.',
    'en': 'Sample terms and conditions text.',
    'ckb': 'دەقی نموونەیی بۆ مەرج و ڕێساکان.',
    'ku': 'Nivîsa mînakî ya merc û şertan.',
  };
  Map<String, String> _contactText = {
    'ar': 'واتساب/هاتف (placeholder).',
    'en': 'WhatsApp/Phone (placeholder).',
    'ckb': 'واتساپ/تەلەفۆن (placeholder).',
    'ku': 'WhatsApp/Telefon (placeholder).',
  };

  @override
  void initState() {
    super.initState();
    _supabaseClient = Supabase.instance.client;
    _syncCurrentUser();
    _loadMoreContentSettings();
    _authSubscription = AuthService.instance.onAuthStateChange.listen((event) {
      if (!mounted) return;
      setState(() {
        _currentUserEmail = event.session?.user.email;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _syncCurrentUser() {
    final user = AuthService.instance.currentUser;
    _currentUserEmail = user?.email;
  }

  String _localizedText(Map<String, String> map, String code) {
    final picked = (map[code] ?? '').trim();
    if (picked.isNotEmpty) return picked;
    final arabic = (map['ar'] ?? '').trim();
    if (arabic.isNotEmpty) return arabic;
    final english = (map['en'] ?? '').trim();
    if (english.isNotEmpty) return english;
    return '';
  }

  Map<String, String> _readLocalizedMap(dynamic source) {
    if (source is! Map) return const {};
    final map = Map<String, dynamic>.from(source);
    return {
      'ar': (map['ar'] ?? '').toString(),
      'en': (map['en'] ?? '').toString(),
      'ckb': (map['ckb'] ?? '').toString(),
      'ku': (map['ku'] ?? '').toString(),
    };
  }

  Future<void> _loadMoreContentSettings() async {
    try {
      final row = await _supabaseClient
          .from('app_more_content_settings')
          .select('*')
          .eq('id', true)
          .maybeSingle();
      if (!mounted || row == null) return;

      setState(() {
        _appVersion = (row['app_version']?.toString() ?? _appVersion).trim();
        _appNameText = {..._appNameText, ..._readLocalizedMap(row['app_name'])};
        _aboutText = {..._aboutText, ..._readLocalizedMap(row['about_text'])};
        _privacyText = {
          ..._privacyText,
          ..._readLocalizedMap(row['privacy_text'])
        };
        _termsText = {..._termsText, ..._readLocalizedMap(row['terms_text'])};
        _contactText = {
          ..._contactText,
          ..._readLocalizedMap(row['contact_text'])
        };
      });
    } catch (_) {
      // Keep local defaults if settings are unavailable.
    }
  }

  void _showInfoDialog({
    required String title,
    required String content,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _authErrorMessage(Object error, String code) {
    final message = error.toString().toLowerCase();
    final providerNotEnabled = message.contains('provider is not enabled') ||
        message.contains('unsupported provider');

    if (providerNotEnabled) {
      return _t(
        code,
        ar: 'تسجيل Google غير مفعّل حاليًا. يرجى تفعيل Google Provider من إعدادات Supabase.',
        en: 'Google sign-in is currently disabled. Please enable the Google provider in Supabase settings.',
        ckb:
            'چوونەژوورەوەی گووگڵ ئێستا چالاک نییە. تکایە Google Provider لە ڕێکخستنەکانی Supabase چالاک بکە.',
        ku: 'Têketina Google niha neçalak e. Ji kerema xwe Google Provider di mîhengên Supabase de çalak bike.',
      );
    }

    return _t(
      code,
      ar: 'تعذر تسجيل الدخول بجوجل. حاول مرة أخرى.',
      en: 'Google sign-in failed. Please try again.',
      ckb: 'چوونەژوورەوە بە گووگڵ سەرکەوتوو نەبوو. تکایە دووبارە هەوڵ بدە.',
      ku: 'Têketina bi Google serneket. Ji kerema xwe dîsa biceribîne.',
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _authBusy = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      final code = context.read<LanguageProvider>().locale.languageCode;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authErrorMessage(e, code))));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _authBusy = true);
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل الخروج')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تسجيل الخروج: $e')));
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _showLanguagePicker() async {
    final languageProvider = context.read<LanguageProvider>();
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      builder: (sheetContext) {
        final currentCode = languageProvider.locale.languageCode;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('العربية'),
                trailing: currentCode == 'ar' ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(const Locale('ar')),
              ),
              ListTile(
                title: const Text('English'),
                trailing: currentCode == 'en' ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(const Locale('en')),
              ),
              ListTile(
                title: const Text('کوردی سۆرانی'),
                trailing: currentCode == 'ckb' ? const Icon(Icons.check) : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(const Locale('ckb')),
              ),
              ListTile(
                title: const Text('Kurdî Kurmancî'),
                trailing: currentCode == 'ku' ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(const Locale('ku')),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    await languageProvider.setLocale(selected);
  }

  String _t(
    String code, {
    required String ar,
    required String en,
    required String ckb,
    required String ku,
  }) {
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

  Widget _sectionCard(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _moreTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _accountHeader(BuildContext context, String code, int favoriteCount) {
    final theme = Theme.of(context);
    final signedIn = _currentUserEmail != null;
    final displayName = signedIn
        ? _currentUserEmail!.split('@').first
        : _t(
            code,
            ar: 'زائر',
            en: 'Guest',
            ckb: 'میوان',
            ku: 'Mêvan',
          );
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              initial,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _currentUserEmail ??
                _t(
                  code,
                  ar: 'غير مسجّل الدخول',
                  en: 'Not signed in',
                  ckb: 'چوونەژوورەوە نەکراوە',
                  ku: 'Têketin nehatî kirin',
                ),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              code,
              ar: 'مرحباً $displayName',
              en: 'Hello $displayName',
              ckb: 'سڵاو $displayName',
              ku: 'Silav $displayName',
            ),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed:
                _authBusy ? null : (signedIn ? _signOut : _signInWithGoogle),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(260, 48),
              side: BorderSide(color: theme.colorScheme.outline),
            ),
            child: _authBusy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    signedIn
                        ? _t(
                            code,
                            ar: 'تسجيل الخروج',
                            en: 'Sign out',
                            ckb: 'چوونەدەرەوە',
                            ku: 'Derkeve',
                          )
                        : _t(
                            code,
                            ar: 'إدارة حسابك على Google',
                            en: 'Manage your Google account',
                            ckb: 'بەڕێوەبردنی هەژماری گووگڵ',
                            ku: 'Hesabê Google îdare bike',
                          ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              code,
              ar: 'عدد العناصر في المفضلة: $favoriteCount',
              en: 'Favorite items count: $favoriteCount',
              ckb: 'ژمارەی کاڵاکانی لیستی دڵخوازەکان: $favoriteCount',
              ku: 'Hejmara berhemên watchlistê: $favoriteCount',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final favoriteCount = context.watch<FavoritesProvider>().count;
    final code = languageProvider.locale.languageCode;
    final appName = _localizedText(_appNameText, code);
    final aboutText = _localizedText(_aboutText, code);
    final privacyText = _localizedText(_privacyText, code);
    final termsText = _localizedText(_termsText, code);
    final contactText = _localizedText(_contactText, code);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          _t(
            code,
            ar: 'المزيد',
            en: 'More',
            ckb: 'زیاتر',
            ku: 'Zêdetir',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _accountHeader(context, code, favoriteCount),
          _sectionCard(context, [
            _moreTile(
              icon: Icons.language_outlined,
              title: _t(
                code,
                ar: 'اللغة',
                en: 'Language',
                ckb: 'زمان',
                ku: 'Ziman',
              ),
              subtitle: languageProvider.languageLabel,
              onTap: _showLanguagePicker,
            ),
          ]),
          _sectionCard(context, [
            _moreTile(
              icon: Icons.favorite_border_outlined,
              title: _t(
                code,
                ar: 'المفضلة',
                en: 'Favorites',
                ckb: 'لیستی دڵخوازەکان',
                ku: 'Watchlist',
              ),
              subtitle: _t(
                code,
                ar: 'عناصر محفوظة ومزامنة بين الأجهزة',
                en: 'Saved items synced across devices',
                ckb: 'کاڵا هەڵگیراوەکان کە لەنێوان ئامێرەکان هاوکاتکراون',
                ku: 'Berhemên tomarkirî yên di navbera amûran de hevdem bûn',
              ),
              trailing: favoriteCount > 0
                  ? CircleAvatar(
                      radius: 12,
                      child: Text(
                        '$favoriteCount',
                        style: const TextStyle(fontSize: 11),
                      ),
                    )
                  : null,
              onTap: () {
                NavigationHelpers.goToFavorites(context);
              },
            ),
            _moreTile(
              icon: Icons.campaign_outlined,
              title: _t(
                code,
                ar: 'شراكة المروجين',
                en: 'Influencer partnership',
                ckb: 'هاوبەشی مروژەران',
                ku: 'Hevkariya influenceran',
              ),
              subtitle: _t(
                code,
                ar: 'اربح عمولات عبر كودك الخاص وروابط التتبع',
                en: 'Earn commissions with your personal code and tracking links',
                ckb: 'قازانج بکە بە کۆد و بەستەری شوێنکەوتنی تایبەتی خۆت',
                ku: 'Bi koda xwe û girêdanên şopandinê komîsyon bistîne',
              ),
              onTap: () {
                NavigationHelpers.goToInfluencerPartnership(context);
              },
            ),
            _moreTile(
              icon: Icons.manage_search,
              title: _t(
                code,
                ar: 'بحث المستخدم',
                en: 'User search',
                ckb: 'گەڕانی بەکارهێنەر',
                ku: 'Lêgerîna bikarhêner',
              ),
              subtitle: _t(
                code,
                ar: 'البحث عن الطلبات والإشعارات المرتبطة بك',
                en: 'Search your related orders and notifications',
                ckb: 'گەڕان بۆ داواکاری و ئاگادارکردنەوە پەیوەندیدارەکانت',
                ku: 'Li ferman û agahdariyên girêdayî te bigere',
              ),
              onTap: () {
                NavigationHelpers.push(context, RouteNames.userSearch);
              },
            ),
            _moreTile(
              icon: Icons.local_shipping_outlined,
              title: _t(
                code,
                ar: 'تتبع الطلب',
                en: 'Track order',
                ckb: 'شوێنکەوتنی داوا',
                ku: 'Şopandina fermanê',
              ),
              onTap: () {
                NavigationHelpers.goToOrderTrackingHome(context);
              },
            ),
            _moreTile(
              icon: Icons.notifications_active_outlined,
              title: _t(
                code,
                ar: 'الإشعارات',
                en: 'Notifications',
                ckb: 'ئاگادارکردنەوەکان',
                ku: 'Agahdari',
              ),
              subtitle: _t(
                code,
                ar: 'العروض العامة والرسائل الخاصة',
                en: 'Public offers and private messages',
                ckb: 'پێشکەشکراوە گشتییەکان و نامە تایبەتەکان',
                ku: 'Pêşniyarên giştî û peyamên taybet',
              ),
              onTap: () {
                NavigationHelpers.goToNotifications(context);
              },
            ),
          ]),
          _sectionCard(context, [
            _moreTile(
              icon: Icons.directions_car,
              title: _t(
                code,
                ar: 'ماركات السيارات',
                en: 'Car brands',
                ckb: 'براندەکانی ئۆتۆمبێل',
                ku: 'Brandên erebeyan',
              ),
              subtitle: _t(
                code,
                ar: 'تصفح الماركات والأقسام والمنتجات',
                en: 'Browse brands, sections, and products',
                ckb: 'گەڕان بەناو براند و بەش و کاڵاکاندا',
                ku: 'Li nav brand, beş û berheman de bigere',
              ),
              onTap: () {
                NavigationHelpers.push(context, RouteNames.carBrands);
              },
            ),
            if (kEnablePartsBrowser)
              _moreTile(
                icon: Icons.tune_rounded,
                title: _t(
                  code,
                  ar: 'متصفح القطع (تجريبي)',
                  en: 'Parts browser (experimental)',
                  ckb: 'گەڕۆکی پارچەکان (تاقیکردنەوە)',
                  ku: 'Gerokê parçeyan (ceribandinî)',
                ),
                subtitle: _t(
                  code,
                  ar: 'اختر الماركة ثم الموديل والجيل لتصفح القطع',
                  en: 'Choose brand, model, and generation to browse parts',
                  ckb: 'براند و مۆدێل و نەوە هەڵبژێرە بۆ گەڕان بە پارچەکاندا',
                  ku: 'Brand, model û nesil hilbijêre da ku li parçeyan bigere',
                ),
                onTap: () {
                  NavigationHelpers.push(context, RouteNames.partsBrowser);
                },
              ),
            _moreTile(
              icon: Icons.request_quote_outlined,
              title: _t(
                code,
                ar: 'طلبات تسعير قطع (RFQ)',
                en: 'Parts quotation requests (RFQ)',
                ckb: 'داواکاری نرخی پارچەکان (RFQ)',
                ku: 'Daxwazên bihayê parçeyan (RFQ)',
              ),
              subtitle: _t(
                code,
                ar: 'ارفع طلبك واترك التجّار يقدّمون عروضهم',
                en: 'Submit your request and let sellers send offers',
                ckb: 'داواکارییەکەت بنێرە و بۆ بازرگانەکان بهێڵە پێشنیار بکەن',
                ku: 'Daxwaza xwe bişîne û bihêle firoşkar pêşniyar bidin',
              ),
              onTap: () {
                NavigationHelpers.push(context, RouteNames.rfqMyRequests);
              },
            ),
          ]),
          _sectionCard(context, [
            _moreTile(
              icon: Icons.info_outline,
              title: _t(
                code,
                ar: 'عن التطبيق',
                en: 'About app',
                ckb: 'دەربارەی بەرنامە',
                ku: 'Derbarê appê de',
              ),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: appName,
                  applicationVersion: _appVersion,
                  children: [
                    Text(aboutText),
                  ],
                );
              },
            ),
            _moreTile(
              icon: Icons.privacy_tip_outlined,
              title: _t(
                code,
                ar: 'سياسة الخصوصية',
                en: 'Privacy policy',
                ckb: 'سیاسەتی تایبەتمەندی',
                ku: 'Siyaseta taybetîtiyê',
              ),
              subtitle: _t(
                code,
                ar: privacyText,
                en: privacyText,
                ckb: privacyText,
                ku: privacyText,
              ),
              onTap: () {
                _showInfoDialog(
                  title: _t(
                    code,
                    ar: 'سياسة الخصوصية',
                    en: 'Privacy policy',
                    ckb: 'سیاسەتی تایبەتمەندی',
                    ku: 'Siyaseta taybetîtiyê',
                  ),
                  content: privacyText,
                );
              },
            ),
            _moreTile(
              icon: Icons.rule_folder_outlined,
              title: _t(
                code,
                ar: 'الشروط والأحكام',
                en: 'Terms and conditions',
                ckb: 'مەرج و ڕێساکان',
                ku: 'Merc û şert',
              ),
              subtitle: _t(
                code,
                ar: termsText,
                en: termsText,
                ckb: termsText,
                ku: termsText,
              ),
              onTap: () {
                _showInfoDialog(
                  title: _t(
                    code,
                    ar: 'الشروط والأحكام',
                    en: 'Terms and conditions',
                    ckb: 'مەرج و ڕێساکان',
                    ku: 'Merc û şert',
                  ),
                  content: termsText,
                );
              },
            ),
            _moreTile(
              icon: Icons.phone_in_talk_outlined,
              title: _t(
                code,
                ar: 'تواصل معنا',
                en: 'Contact us',
                ckb: 'پەیوەندیمان پێوە بکە',
                ku: 'Bi me re têkilî daynin',
              ),
              subtitle: _t(
                code,
                ar: contactText,
                en: contactText,
                ckb: contactText,
                ku: contactText,
              ),
              onTap: () {
                _showInfoDialog(
                  title: _t(
                    code,
                    ar: 'تواصل معنا',
                    en: 'Contact us',
                    ckb: 'پەیوەندیمان پێوە بکە',
                    ku: 'Bi me re têkilî daynin',
                  ),
                  content: contactText,
                );
              },
            ),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

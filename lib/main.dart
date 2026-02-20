import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';

import 'firebase_options.dart';
import 'presentation/providers/cart_provider.dart';
import 'presentation/providers/favorites_provider.dart';
import 'presentation/providers/home_provider.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/freebies_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/review_repository.dart';
import 'core/services/notification_service.dart';
import 'core/services/device_token_service.dart';
import 'package:design_system/design_system.dart';
import 'presentation/routing/app_router.dart';
import 'presentation/providers/language_provider.dart';
import 'utils/local_storage.dart' as app_storage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startupWarnings = <String>[];
  String? fatalStartupError;

  try {
    await Supabase.initialize(
      url: 'https://enxihyplaelrdkievkrk.supabase.co', // عدّل إلى رابط مشروعك
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVueGloeXBsYWVscmRraWV2a3JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0MDg5NTcsImV4cCI6MjA3ODk4NDk1N30.-QdRQCUaTprZDyDlrNm-7vPKwYFVE1_5ncLVjpSM9Oc', // عدّل إلى anon key
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (e, st) {
    debugPrint('Supabase.initialize failed: $e');
    debugPrintStack(stackTrace: st);
    fatalStartupError =
        'تعذر تهيئة الاتصال بالخادم (Supabase). تحقق من الإنترنت وإعدادات المشروع.';
  }

  if (fatalStartupError != null) {
    runApp(_StartupErrorApp(message: fatalStartupError));
    return;
  }

  final notificationRepository = SupabaseNotificationRepository();
  final productRepository = SupabaseProductRepository();
  final catalogRepository = SupabaseCatalogRepository();
  final orderRepository = SupabaseOrderRepository();
  final freebiesRepository = SupabaseFreebiesRepository();
  final adminRepository = SupabaseAdminRepository();
  final reviewRepository = SupabaseReviewRepository();

  DeviceTokenService.instance.configure(notificationRepository);
  NotificationService.instance.configure(notificationRepository);

  runApp(
    MultiProvider(
      providers: [
        Provider<ProductRepository>.value(value: productRepository),
        Provider<NotificationRepository>.value(value: notificationRepository),
        Provider<CatalogRepository>.value(value: catalogRepository),
        Provider<OrderRepository>.value(value: orderRepository),
        Provider<FreebiesRepository>.value(value: freebiesRepository),
        Provider<AdminRepository>.value(value: adminRepository),
        Provider<ReviewRepository>.value(value: reviewRepository),
        ChangeNotifierProvider(
          create: (_) => CartProvider()..loadCartFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider()..loadFromStorage(),
        ),
        ChangeNotifierProvider(
          create: (context) => HomeProvider(
            productRepository: context.read<ProductRepository>(),
            notificationRepository: context.read<NotificationRepository>(),
            catalogRepository: context.read<CatalogRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..loadSavedLanguage(),
        ),
      ],
      child: MyApp(startupWarnings: startupWarnings),
    ),
  );

  unawaited(_runPostLaunchInit(startupWarnings));
}

Future<void> _runPostLaunchInit(List<String> startupWarnings) async {
  final startupRef = Uri.base.queryParameters['ref'];
  if (startupRef != null && startupRef.trim().isNotEmpty) {
    try {
      await app_storage.LocalStorage.saveInfluencerReferralCode(
        startupRef,
        source: Uri.base.toString(),
      );
    } catch (_) {
      // Ignore referral persistence failures.
    }
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    debugPrint('Firebase.initializeApp failed: $e');
    debugPrintStack(stackTrace: st);
    startupWarnings.add('تعذر تهيئة Firebase. قد لا تعمل الإشعارات.');
  }

  try {
    final savedPhone = await app_storage.LocalStorage.getUserPhone();
    await NotificationService.instance.init(
      phone: savedPhone,
    );
  } catch (e, st) {
    debugPrint('NotificationService.init failed: $e');
    debugPrintStack(stackTrace: st);
    startupWarnings.add('تعذر تهيئة الإشعارات.');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.startupWarnings = const []});

  final List<String> startupWarnings;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _hideStartupWarnings = false;
  StreamSubscription<AuthState>? _authSubscription;

  Future<void> _syncPhoneFromSignedInAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final phone = (metadata['phone']?.toString() ??
            metadata['phone_number']?.toString() ??
            metadata['mobile']?.toString() ??
            '')
        .trim();
    if (phone.isEmpty) return;

    await app_storage.LocalStorage.saveUserPhone(phone);
    await DeviceTokenService.instance.registerDeviceToken(phone: phone);
  }

  @override
  void initState() {
    super.initState();
    final cartProvider = context.read<CartProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      unawaited(
        cartProvider.syncWithCloudForCurrentUser(),
      );
      unawaited(
        favoritesProvider.syncWithCloudForCurrentUser(),
      );
      unawaited(
        _syncPhoneFromSignedInAccount(),
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return Directionality(
      textDirection:
          languageProvider.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: MaterialApp.router(
        onGenerateTitle: (context) =>
            AppLocalizations.of(context)?.appTitle ?? 'متجر + هبات مجانية',
        debugShowCheckedModeBanner: false,
        routerConfig: AppRouter.router,
        theme: AppTheme.lightTheme(fontFamily: 'NotoSansArabic'),
        darkTheme: AppTheme.darkTheme(fontFamily: 'NotoSansArabic'),
        themeMode: ThemeMode.light,
        locale: languageProvider.frameworkLocale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final hasWarnings =
              widget.startupWarnings.isNotEmpty && !_hideStartupWarnings;

          return SafeArea(
            top: true,
            bottom: true,
            left: true,
            right: true,
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (hasWarnings)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Material(
                      color: Colors.amber.shade100,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.black87,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.startupWarnings.join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                setState(() => _hideStartupWarnings = true);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 42, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'تعذر تشغيل التطبيق',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'أغلق التطبيق ثم أعد تشغيله بعد التحقق من الإنترنت.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

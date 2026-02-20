import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/language_text.dart';
import '../../l10n/app_localizations.dart';

import '../features/categories/screens/categories_screen.dart';
import '../features/donations/screens/donations_home_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/more/screens/more_screen.dart';
import '../features/rfq/screens/rfq_my_requests_screen.dart';
import '../routing/navigation_helpers.dart';
import '../../core/services/tracking_service.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(),
    CategoriesScreen(),
    DonationsHomeScreen(),
    RfqMyRequestsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _trackCurrentTab();
  }

  void _trackCurrentTab() {
    final screenName = switch (_currentIndex) {
      0 => 'home',
      1 => 'categories',
      2 => 'donations',
      3 => 'my_requests',
      4 => 'more',
      _ => 'unknown',
    };
    TrackingService.instance.trackScreen(screenName);
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      _trackCurrentTab();
      return false;
    }

    final shouldExit = await _showExitBottomSheet(context);
    return shouldExit ?? false;
  }

  Future<bool?> _showExitBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.exit_to_app, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        l10n.exitAppTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.exitAppMessage,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            NavigationHelpers.pop(context, false);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            NavigationHelpers.pop(context, true);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l10n.exitAppConfirm,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: colorScheme.primaryContainer,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            height: 74,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              _trackCurrentTab();
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: context.tr(
                  ar: 'الرئيسية',
                  en: 'Home',
                  ckb: 'سەرەکی',
                  ku: 'Sereke',
                ),
              ),
              NavigationDestination(
                icon: const Icon(Icons.category_outlined),
                selectedIcon: const Icon(Icons.category_rounded),
                label: context.tr(
                  ar: 'الأقسام',
                  en: 'Sections',
                  ckb: 'بەشەکان',
                  ku: 'Beş',
                ),
              ),
              NavigationDestination(
                icon: const Icon(Icons.volunteer_activism_outlined),
                selectedIcon: const Icon(Icons.volunteer_activism),
                label: context.tr(
                  ar: 'الهبات',
                  en: 'Freebies',
                  ckb: 'بەخششەکان',
                  ku: 'Diyari',
                ),
              ),
              NavigationDestination(
                icon: const Icon(Icons.request_quote_outlined),
                selectedIcon: const Icon(Icons.request_quote),
                label: context.tr(
                  ar: 'طلباتي',
                  en: 'My requests',
                  ckb: 'داواکارییەکانم',
                  ku: 'Daxwazên min',
                ),
              ),
              NavigationDestination(
                icon: const Icon(Icons.more_horiz_outlined),
                selectedIcon: const Icon(Icons.more_horiz),
                label: context.tr(
                  ar: 'المزيد',
                  en: 'More',
                  ckb: 'زیاتر',
                  ku: 'Zêdetir',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

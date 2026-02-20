import 'package:flutter/material.dart';
import '../../../../core/localization/language_text.dart';

import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderNumber;
  final String? phone;

  const OrderSuccessScreen({super.key, required this.orderNumber, this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  ar: 'تم استلام طلبك بنجاح',
                  en: 'Your order was placed successfully',
                  ckb: 'داواکارییەکەت بە سەرکەوتوویی وەرگیرا',
                  ku: 'Fermana te bi serkeftî hate danîn',
                ),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.tr(ar: 'رقم الطلب', en: 'Order number', ckb: 'ژمارەی داواکاری', ku: 'Hejmara fermanê')}: $orderNumber',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  NavigationHelpers.goToOrderTracking(
                    context,
                    orderNumber,
                    phone: phone,
                  );
                },
                child: Text(
                  context.tr(
                      ar: 'تتبع الطلب',
                      en: 'Track order',
                      ckb: 'شوێنی داواکاری بکەوە',
                      ku: 'Fermanê bişopîne'),
                ),
              ),
              TextButton(
                onPressed: () {
                  NavigationHelpers.go(context, RouteNames.root);
                },
                child: Text(
                  context.tr(
                      ar: 'العودة للرئيسية',
                      en: 'Back to home',
                      ckb: 'گەڕانەوە بۆ سەرەکی',
                      ku: 'Vegere ser navendî'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

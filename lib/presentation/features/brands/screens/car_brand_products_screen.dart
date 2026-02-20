import 'package:flutter/material.dart';
import '../../../../core/localization/language_text.dart';

class CarBrandProductsScreen extends StatelessWidget {
  const CarBrandProductsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.sectionId,
    required this.sectionName,
  });

  final String brandId;
  final String brandName;
  final String sectionId;
  final String sectionName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'تم تحديث الهيكل',
            en: 'Structure updated',
            ckb: 'پێکهاتە نوێکرایەوە',
            ku: 'Avahî nû hate kirin',
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.tr(
              ar: 'هذا المسار قديم بعد تحديث هيكل السيارات.\nيرجى الرجوع واختيار الموديل ثم السنة والفئة للوصول إلى المنتجات.',
              en: 'This route is outdated after the car structure update.\nPlease go back and choose model, then year and trim to reach products.',
              ckb:
                  'ئەم ڕێگایە کۆنە دوای نوێکردنەوەی پێکهاتەی ئۆتۆمبێل.\nتکایە بگەڕێوە و مۆدێل، پاشان ساڵ و تریم هەڵبژێرە بۆ گەیشتن بە کاڵاکان.',
              ku: 'Ev rê piştî nûkirina avahiya erebeyan kevn bûye.\nJi kerema xwe vegere û model, paşê sal û trim hilbijêre da ku bigihîje berheman.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

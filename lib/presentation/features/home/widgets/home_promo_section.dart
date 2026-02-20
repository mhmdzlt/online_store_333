import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

import '../../../../data/models/promo_banner/promo_banner_model.dart';
import 'promo_banner_carousel.dart';

class HomePromoSection extends StatelessWidget {
  const HomePromoSection({
    super.key,
    required this.isLoading,
    required this.banners,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTap,
  });

  final bool isLoading;
  final List<PromoBannerModel> banners;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<PromoBannerModel> onTap;

  double _resolvedHeight() {
    if (banners.isEmpty) return AppSizes.bannerHeight;
    final activeIndex = currentIndex.clamp(0, banners.length - 1);
    final factor = banners[activeIndex].heightFactor;
    return (AppSizes.bannerHeight * factor).clamp(120.0, 360.0);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: AppSizes.bannerHeight,
        child: AppLoading(),
      );
    }

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return PromoBannerCarousel(
      banners: banners,
      controller: controller,
      bannerHeight: _resolvedHeight(),
      currentIndex: currentIndex,
      onPageChanged: onPageChanged,
      onTap: onTap,
    );
  }
}

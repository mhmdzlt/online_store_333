import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/promo_banner/promo_banner_model.dart';

class PromoBannerCarousel extends StatelessWidget {
  final List<PromoBannerModel> banners;
  final void Function(PromoBannerModel) onTap;
  final PageController controller;
  final double bannerHeight;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const PromoBannerCarousel({
    super.key,
    required this.banners,
    required this.onTap,
    required this.controller,
    required this.bannerHeight,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: bannerHeight,
          width: double.infinity,
          child: PageView.builder(
            controller: controller,
            itemCount: banners.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return _PromoBannerCard(
                banner: banner,
                bannerHeight: bannerHeight,
                onPressed: () => onTap(banner),
              );
            },
          ),
        ),
        const SizedBox(height: AppSizes.spaceS),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (index) {
            final isActive = currentIndex == index;
            return AnimatedContainer(
              duration: AppSizes.animationDurationMedium,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PromoBannerCard extends StatelessWidget {
  final PromoBannerModel banner;
  final double bannerHeight;
  final VoidCallback onPressed;

  const _PromoBannerCard({
    required this.banner,
    required this.bannerHeight,
    required this.onPressed,
  });

  Color _fromHex(String hex) {
    var clean = hex.replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.parse(clean, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _fromHex(banner.backgroundColor);
    final textColor = _fromHex(banner.textColor);
    final hasImage = banner.imageUrl.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.cardRadiusL),
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSizes.spaceM),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: banner.widthFactor,
            child: Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.cardRadiusL),
                color: hasImage ? null : bgColor,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    AppImage(
                      imageUrl: banner.imageUrl,
                      width: double.infinity,
                      height: bannerHeight,
                      fit: BoxFit.cover,
                      radius: AppSizes.cardRadiusL,
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spaceM,
                      vertical: AppSizes.spaceS,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.cardRadiusL),
                      color: hasImage
                          ? bgColor.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxHeight < 150;
                        final veryCompact = constraints.maxHeight < 130;
                        final titleSize =
                            veryCompact ? 16.0 : (compact ? 18.0 : 20.0);
                        final subtitleSize =
                            veryCompact ? 12.0 : (compact ? 13.0 : 14.0);
                        final buttonHeight =
                            veryCompact ? 34.0 : (compact ? 36.0 : 40.0);
                        final contentSpacing =
                            veryCompact ? 8.0 : (compact ? 10.0 : 16.0);
                        final subtitleSpacing = veryCompact ? 0.0 : 6.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (banner.title.isNotEmpty)
                              Text(
                                banner.title,
                                maxLines: veryCompact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                            if (banner.subtitle.isNotEmpty && !veryCompact) ...[
                              SizedBox(height: subtitleSpacing),
                              Text(
                                banner.subtitle,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.9),
                                  fontSize: subtitleSize,
                                  height: 1.15,
                                ),
                              ),
                            ],
                            SizedBox(height: contentSpacing),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    banner.ctaFullWidth ? double.infinity : 220,
                              ),
                              child: SizedBox(
                                height: buttonHeight,
                                width: banner.ctaFullWidth
                                    ? double.infinity
                                    : null,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: textColor,
                                    foregroundColor: bgColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 14 : 20,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: onPressed,
                                  child: Text(
                                    banner.ctaText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: compact ? 13 : 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/cart_provider.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchHintNotifier,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterTap,
    required this.imageSearchLoading,
    required this.onImageSearchTap,
    required this.onCartTap,
    required this.onQuickLiveTap,
    required this.onQuickSellingTap,
    required this.onQuickSavedTap,
    required this.onQuickHistoryTap,
    required this.imageSearchActive,
    required this.imageSearchCount,
    required this.onClearImageSearch,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueListenable<String> searchHintNotifier;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onFilterTap;
  final bool imageSearchLoading;
  final VoidCallback onImageSearchTap;
  final VoidCallback onCartTap;
  final VoidCallback onQuickLiveTap;
  final VoidCallback onQuickSellingTap;
  final VoidCallback onQuickSavedTap;
  final VoidCallback onQuickHistoryTap;
  final bool imageSearchActive;
  final int imageSearchCount;
  final VoidCallback onClearImageSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        height: 0.9,
                      ),
                      children: [
                        TextSpan(
                          text: 'k',
                          style: TextStyle(color: Color(0xFFE53238)),
                        ),
                        TextSpan(
                          text: 'a',
                          style: TextStyle(color: Color(0xFF0064D2)),
                        ),
                        TextSpan(
                          text: 'r',
                          style: TextStyle(color: Color(0xFFF5AF02)),
                        ),
                        TextSpan(
                          text: 'a',
                          style: TextStyle(color: Color(0xFF86B817)),
                        ),
                        TextSpan(
                          text: 'z',
                          style: TextStyle(color: Color(0xFFE53238)),
                        ),
                        TextSpan(
                          text: 'a',
                          style: TextStyle(color: Color(0xFF0064D2)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Selector<CartProvider, int>(
                selector: (_, cart) => cart.items.length,
                builder: (context, cartCount, _) {
                  return InkWell(
                    onTap: onCartTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            top: -5,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                cartCount > 99 ? '99+' : '$cartCount',
                                style: TextStyle(
                                  color: colorScheme.onError,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: searchHintNotifier,
                    builder: (context, hint, _) {
                      return TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: searchController.text.trim().isEmpty
                              ? l10n.homeSearchOnMarketplace
                              : hint,
                        ),
                      );
                    },
                  ),
                ),
                if (searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.cancel,
                  ),
                IconButton(
                  onPressed: imageSearchLoading ? null : onImageSearchTap,
                  icon: imageSearchLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.photo_camera_outlined,
                          size: 22,
                          color: colorScheme.onSurfaceVariant,
                        ),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.imageSearch,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _QuickChip(
                  label: l10n.homeQuickNewRequest,
                  icon: Icons.add_circle_outline,
                  onTap: onQuickLiveTap,
                ),
                _QuickChip(
                  label: l10n.homeQuickOffers,
                  icon: Icons.local_offer_outlined,
                  onTap: onQuickSellingTap,
                ),
                _QuickChip(
                  label: l10n.homeQuickSections,
                  icon: Icons.grid_view_rounded,
                  onTap: onQuickSavedTap,
                ),
                _QuickChip(
                  label: l10n.homeQuickOrders,
                  icon: Icons.receipt_long_outlined,
                  onTap: onQuickHistoryTap,
                ),
              ],
            ),
          ),
          if (imageSearchActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.image_search,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      imageSearchCount == 0
                          ? l10n.imageSearchNoResults
                          : l10n.imageSearchResults(imageSearchCount),
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onClearImageSearch,
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }
}

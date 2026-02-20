// lib/utils/image_resolvers.dart

/// يتحقق هل الرابط Placeholder (أو فارغ) ولا يجب استخدامه كصورة حقيقية.
bool isPlaceholderUrl(String? url) {
  if (url == null) return true;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return true;

  // نتجنب جميع روابط placeholder.com
  return trimmed.contains('via.placeholder.com');
}

bool isValidNetworkImageUrl(String? url) {
  if (isPlaceholderUrl(url)) return false;
  final trimmed = url!.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  return uri.host.trim().isNotEmpty;
}

/// يختار أفضل صورة منتج من product_images أو من image_url في products.
///
/// - أولاً: يبحث في product['product_images'] (الـ JOIN من Supabase)
///   ويرتبها حسب sort_order تنازلياً (الأعلى أولاً)،
///   ثم يرجّع أول رابط صالح (ليس فارغاً ولا placeholder).
/// - إذا لم يجد أي صورة صالحة في product_images:
///   يحاول استخدام product['image_url'] إذا كان صالحاً.
/// - إذا لم يجد شيئاً يرجّع '' (سلسلة فارغة) حتى تعرض الـ UI أيقونة fallback.
String resolveProductImage(Map<String, dynamic> product) {
  // 1) نحاول من product_images (العلاقة الفرعية من Supabase)
  final List<dynamic>? productImages =
      product['product_images'] as List<dynamic>?;

  if (productImages != null && productImages.isNotEmpty) {
    // نأخذ فقط العناصر التي هي Map (image_url + sort_order)
    final images = productImages.whereType<Map<String, dynamic>>().toList();

    // نرتبها حسب sort_order تنازلياً (الأعلى أولاً)
    images.sort((a, b) {
      final aOrder = (a['sort_order'] as num?)?.toInt() ?? 0;
      final bOrder = (b['sort_order'] as num?)?.toInt() ?? 0;
      return bOrder.compareTo(aOrder);
    });

    // نبحث عن أول رابط صالح
    for (final img in images) {
      final url = (img['image_url'] as String? ?? '').trim();
      if (isValidNetworkImageUrl(url)) {
        return url;
      }
    }
  }

  // 2) إذا لم ننجح من product_images، نجرّب image_url في جدول products
  final raw = (product['image_url'] as String?)?.trim() ?? '';
  if (isValidNetworkImageUrl(raw)) {
    return raw;
  }

  // 3) لا توجد صورة صالحة
  return '';
}

/// يختار أفضل صورة للهبة من مصفوفة image_urls في جدول donations.
///
/// يرجع أول رابط غير فارغ وغير placeholder، أو null إذا لا يوجد.
String? resolveDonationImage(List<dynamic>? imageUrls) {
  if (imageUrls == null || imageUrls.isEmpty) return null;

  for (final raw in imageUrls) {
    if (raw is! String) continue;
    final url = raw.trim();
    if (!isValidNetworkImageUrl(url)) continue;
    return url;
  }

  return null;
}

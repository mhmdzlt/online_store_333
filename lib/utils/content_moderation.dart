class ContentModeration {
  static const List<String> _blockedWords = [
    'احتيال',
    'مخدر',
    'سلاح',
    'نصب',
    'خمر',
    'fraud',
    'drugs',
    'weapon',
    'scam',
  ];

  static bool hasBlockedWord(String text) {
    final normalized = text.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    return _blockedWords.any((word) => normalized.contains(word));
  }

  static bool isLikelyNonsense(String text) {
    final trimmed = text.trim();
    if (trimmed.length < 3) return true;

    final noSpaces = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (noSpaces.isEmpty) return true;

    final uniqueChars = noSpaces.split('').toSet().length;
    if (noSpaces.length >= 6 && uniqueChars <= 2) {
      return true;
    }

    if (RegExp(r'(.)\1{4,}').hasMatch(noSpaces)) {
      return true;
    }

    return false;
  }

  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static bool isLikelyValidPhone(String phone) {
    final normalized = normalizePhone(phone);
    final digitsOnly = normalized.replaceAll('+', '');
    return digitsOnly.length >= 8 && digitsOnly.length <= 15;
  }
}

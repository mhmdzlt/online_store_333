import 'package:flutter/material.dart';

class HexColor extends Color {
  HexColor(final String hexColor) : super(_parseHexColor(hexColor));

  static int _parseHexColor(String hexColor) {
    String hex = hexColor.toUpperCase().replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return int.parse(hex, radix: 16);
  }
}

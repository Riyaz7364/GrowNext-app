// ...existing code...
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grownext/Data/theme/colors.dart';

// helper to create a MaterialColor from a single Color
MaterialColor createMaterialColor(Color color) {
  final strengths = <double>[.05];
  final swatch = <int, Color>{};
  final r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

final appTheme = ThemeData(
  primarySwatch: createMaterialColor(primaryColor),
  primaryColor: primaryColor,

  textTheme: GoogleFonts.gabaritoTextTheme(),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
  ),
);
// ...existing code...

// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _defaultFontFamily = 'Nunito';

// --- Define 8 Primary Accent Colors ---
// These are considered the MAIN, often brighter, color of the gradient.
// For a RIGHT-TO-LEFT gradient, this color (or a lighter variant) should be on the RIGHT.
const Color accentLightBlue = Color(0xFF42A5F5); // Main accent
const Color accentPurple = Color(0xFFAB47BC);
const Color accentOrange = Color(0xFFFFB74D);
const Color accentPink = Color(0xFFF06292);
const Color accentTeal = Color(0xFF26A69A);       // This is likely the one in homescreen1.jpg
const Color accentGreen = Color(0xFF66BB6A);
const Color accentRed = Color(0xFFEF5350);
const Color accentIndigo = Color(0xFF5C6BC0);
// --- End Accent Colors ---

enum AppThemeType {
  lightBlue, lightPurple, lightOrange, lightPink,
  lightTeal, lightGreen, lightRed, lightIndigo
}

const Map<AppThemeType, Color> appThemeTypeColors = {
  AppThemeType.lightBlue: accentLightBlue,
  AppThemeType.lightPurple: accentPurple,
  AppThemeType.lightOrange: accentOrange,
  AppThemeType.lightPink: accentPink,
  AppThemeType.lightTeal: accentTeal,
  AppThemeType.lightGreen: accentGreen,
  AppThemeType.lightRed: accentRed,
  AppThemeType.lightIndigo: accentIndigo,
};

// --- Gradient Color Definitions for RIGHT-TO-LEFT Flow ---
// To achieve Right (brighter) to Left (darker) with:
// begin: Alignment.centerRight, end: Alignment.centerLeft,
// The color list should be: [COLOR_FOR_RIGHT_SIDE, (optionalMiddleColor), COLOR_FOR_LEFT_SIDE]

final Map<Color, List<Color>> themeGradientColors = {
  accentLightBlue: [
    Colors.cyan.shade300,   // RIGHT side (brighter/different hue)
    accentLightBlue,        // Middle/Main
    Colors.blue.shade700,   // LEFT side (darker)
  ],
  accentPurple: [
    Colors.purple.shade300, // RIGHT
    accentPurple,           // Middle
    Colors.deepPurple.shade700, // LEFT
  ],
  accentOrange: [
    Colors.amber.shade400,  // RIGHT
    accentOrange,           // Middle
    Colors.deepOrange.shade600, // LEFT
  ],
  accentPink: [
    Colors.pink.shade200,   // RIGHT
    accentPink,             // Middle
    Colors.pink.shade700,   // LEFT
  ],
  accentTeal: [ // To match homescreen1.jpg (bright teal/cyan on right, darker teal on left)
    Colors.cyan.shade400, // RIGHT side (brighter cyan/teal)
    accentTeal,           // Middle (main accentTeal)
    Colors.teal.shade700, // LEFT side (darker teal) // Corrected from .shade800 for a slightly less dark contrast if needed
  ],
  accentGreen: [
    Colors.lightGreen.shade400, // RIGHT
    accentGreen,                // Middle
    Colors.green.shade800,      // LEFT
  ],
  accentRed: [
    Colors.orange.shade400, // RIGHT (e.g. lighter, complementary)
    accentRed,              // Middle
    Colors.red.shade800,    // LEFT
  ],
  accentIndigo: [
    Colors.blue.shade300,   // RIGHT
    accentIndigo,           // Middle
    Colors.indigo.shade700, // LEFT
  ],
};
// --- End Gradient Color Definitions ---

class AppThemes {
  static final Map<AppThemeType, ThemeData> lightThemes = {
    for (var entry in appThemeTypeColors.entries)
      entry.key: _createLightTheme(entry.value)
  };

  static ThemeData _createLightTheme(Color accent) {
    final Color primary = accent;
    final Color secondary = HSLColor.fromColor(primary).withSaturation(0.85).withLightness((HSLColor.fromColor(primary).lightness * 0.92).clamp(0.0, 1.0)).toColor();
    const Color lightBg = Color(0xFFF8F9FA);
    const Color lightSurface = Colors.white;
    const Color onLightSurface = Color(0xFF212529);

    final TextTheme baseLightTextTheme = ThemeData.light().textTheme.apply(
      fontFamily: _defaultFontFamily,
      bodyColor: onLightSurface,
      displayColor: onLightSurface.withOpacity(0.9),
    );

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      fontFamily: _defaultFontFamily,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: lightSurface,
        background: lightBg,
        error: Colors.red.shade600,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onLightSurface,
        onBackground: onLightSurface,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: baseLightTextTheme.copyWith(
        headlineSmall: baseLightTextTheme.headlineSmall?.copyWith(fontFamily: _defaultFontFamily, color: onLightSurface, fontWeight: FontWeight.bold),
        titleLarge: baseLightTextTheme.titleLarge?.copyWith(fontFamily: _defaultFontFamily, color: onLightSurface, fontWeight: FontWeight.bold),
        titleMedium: baseLightTextTheme.titleMedium?.copyWith(fontFamily: _defaultFontFamily, color: onLightSurface.withOpacity(0.95), fontWeight: FontWeight.w600),
        bodyLarge: baseLightTextTheme.bodyLarge?.copyWith(fontFamily: _primaryFontFamily, color: onLightSurface.withOpacity(0.9)),
        bodyMedium: baseLightTextTheme.bodyMedium?.copyWith(fontFamily: _primaryFontFamily, color: onLightSurface.withOpacity(0.85)),
        bodySmall: baseLightTextTheme.bodySmall?.copyWith(fontFamily: _primaryFontFamily, color: onLightSurface.withOpacity(0.75), fontWeight: FontWeight.w500),
        labelLarge: baseLightTextTheme.labelLarge?.copyWith(fontFamily: _primaryFontFamily, color: primary, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: onLightSurface),
        titleTextStyle: baseLightTextTheme.titleLarge?.copyWith(color: onLightSurface),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 4.0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              minimumSize: const Size(180, 50),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 2,
              textStyle: const TextStyle(fontFamily: _defaultFontFamily, fontWeight: FontWeight.bold, fontSize: 15)
          )
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: primary,
              textStyle: const TextStyle(fontFamily: _defaultFontFamily, fontWeight: FontWeight.w600, fontSize: 14)
          )
      ),
      chipTheme: ThemeData.light().chipTheme.copyWith(
          backgroundColor: primary.withOpacity(0.1),
          labelStyle: TextStyle(fontFamily: _defaultFontFamily, fontSize: 13, color: primary, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          side: BorderSide.none
      ),
      iconTheme: IconThemeData(color: onLightSurface.withOpacity(0.7)),
      dividerTheme: DividerThemeData(color: Colors.grey.shade300, thickness: 0.8),
    );
  }

  static final ThemeData darkTheme = _createDarkTheme();

  static get _primaryFontFamily => 'Sansation';
  static ThemeData _createDarkTheme() {
    // ... (Your existing dark theme definition - you can apply similar gradient logic here if needed)
    const Color darkPrimary = Color(0xFFBB86FC);
    const Color darkBg = Color(0xFF121212);
    const Color darkSurface = Color(0xFF1E1E1E);
    const Color onDarkSurface = Color(0xFFE0E0E0);
    const Color onDarkBg = Color(0xFFE0E0E0);
    final TextTheme baseDarkTextTheme = ThemeData.dark().textTheme.apply(fontFamily: _defaultFontFamily, bodyColor: onDarkBg, displayColor: onDarkBg.withOpacity(0.85));
    return ThemeData(brightness: Brightness.dark, primaryColor: darkPrimary, fontFamily: _defaultFontFamily, scaffoldBackgroundColor: darkBg, colorScheme: ColorScheme.dark(primary: darkPrimary, secondary: Colors.tealAccent.shade200, surface: darkSurface, background: darkBg, error: Colors.redAccent.shade100, onPrimary: Colors.black, onSecondary: Colors.black, onSurface: onDarkSurface, onBackground: onDarkBg, onError: Colors.black), textTheme: baseDarkTextTheme, appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: onDarkBg), titleTextStyle: baseDarkTextTheme.titleLarge?.copyWith(color: onDarkBg), systemOverlayStyle: SystemUiOverlayStyle.light), cardTheme: CardTheme(elevation: 3.0, color: darkSurface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 7.5)));
  }

  static ThemeData getThemeData(AppThemeType themeType) {
    return lightThemes[themeType] ?? lightThemes[AppThemeType.lightBlue]!;
  }

  static Color getPrimaryAccentColor(AppThemeType themeType) {
    return appThemeTypeColors[themeType] ?? accentLightBlue;
  }

  static AppThemeType getThemeTypeFromColor(Color accentColor) {
    return appThemeTypeColors.entries.firstWhere(
            (entry) => entry.value == accentColor,
        orElse: () => appThemeTypeColors.entries.firstWhere((element) => element.key == AppThemeType.lightBlue)
    ).key;
  }

  // Returns the LIST of colors for the gradient.
  // ORDER: [Color for RIGHT edge, (Middle Color), Color for LEFT edge]
  static List<Color> getGradientColorList(AppThemeType themeType) {
    Color mainAccent = getPrimaryAccentColor(themeType);
    return themeGradientColors[mainAccent] ?? themeGradientColors[accentLightBlue]!;
  }

  // Constructs the actual LinearGradient with RIGHT-TO-LEFT flow.
  static LinearGradient getAppPrimaryGradient(AppThemeType themeType) {
    List<Color> colors = getGradientColorList(themeType);
    // The 'colors' list is already ordered [Right, Middle, Left]
    // So, begin at Right and end at Left.
    return LinearGradient(
      colors: colors,
      begin: Alignment.centerRight, // Start gradient from the right
      end: Alignment.centerLeft,     // End gradient on the left
      // Optional: Add stops if you have 3 colors and want to control their spread
      // e.g., stops: colors.length == 3 ? [0.0, 0.4, 1.0] : null,
      // This would mean the first color (rightmost) covers 0-40%, middle 40-100% (if 2 stops for 3 colors)
      // or more precisely: stop1 for color1, stop2 for color2, stop3 for color3
      stops: colors.length == 3 ? [0.0, 0.5, 1.0] : null, // Example: even distribution for 3 colors
    );
  }
}
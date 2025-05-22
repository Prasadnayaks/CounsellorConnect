// lib/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider with ChangeNotifier {
  // --- CHANGE 1: Default Theme Mode ---
  // Set the initial default to light instead of system
  ThemeMode _themeMode = ThemeMode.light;
  // --- End Change 1 ---

  AppThemeType _appThemeType = AppThemeType.lightBlue; // Default light theme color

  static const String _themeModeKey = 'themeMode';
  static const String _appThemeTypeKey = 'appThemeType';

  ThemeProvider() {
    // Constructor no longer needs to call load, main.dart does.
    print("ThemeProvider initialized.");
  }

  // Getters (Keep these as they are)
  ThemeMode get themeMode => _themeMode;
  AppThemeType get appThemeType => _appThemeType;
  Color get currentAccentColor => AppThemes.getPrimaryAccentColor(_appThemeType);
  ThemeData get currentLightTheme => AppThemes.getThemeData(_appThemeType);
  ThemeData get darkTheme => AppThemes.darkTheme;
  List<Color> get currentAccentGradient => AppThemes.getGradientColorList(_appThemeType);

  // Load saved preferences
  Future<void> loadThemePreferences() async {
    try {
      print("Loading theme preferences...");
      final prefs = await SharedPreferences.getInstance();

      // --- CHANGE 2: Default Fallback in Loading ---
      // Load ThemeMode, but default to 'light' if nothing is saved
      final String savedThemeMode = prefs.getString(_themeModeKey) ?? 'light';
      // --- End Change 2 ---

      _themeMode = ThemeMode.values.firstWhere((e) => e.name == savedThemeMode, orElse: () => ThemeMode.light); // Fallback to light

      final String savedThemeTypeString = prefs.getString(_appThemeTypeKey) ?? AppThemeType.lightBlue.toString();
      _appThemeType = AppThemeType.values.firstWhere( (e) => e.toString() == savedThemeTypeString, orElse: () => AppThemeType.lightBlue );

      print("Loaded Theme: Mode=$_themeMode, AccentType=$_appThemeType");

    } catch (e) {
      print("Error loading theme preferences: $e. Using defaults.");
      _themeMode = ThemeMode.light; // Ensure default is light on error
      _appThemeType = AppThemeType.lightBlue;
    } finally {
      // Don't notify here if called before runApp
    }
  }

  // Save preferences (Keep as is)
  Future<void> _saveThemePreferences() async { /* ... Same save logic ... */ try { final prefs = await SharedPreferences.getInstance(); await prefs.setString(_themeModeKey, _themeMode.name); await prefs.setString(_appThemeTypeKey, _appThemeType.toString()); print("Saved Theme: Mode=$_themeMode, AccentType=$_appThemeType"); } catch (e) { print("Error saving theme preferences: $e"); } }

  // Setters (Keep as is)
  void setThemeMode(ThemeMode mode) { if (_themeMode == mode) return; _themeMode = mode; _saveThemePreferences(); notifyListeners(); print("Theme Mode Set: $_themeMode"); }
  void setAppTheme(AppThemeType themeType) { if (_appThemeType == themeType) return; _appThemeType = themeType; _saveThemePreferences(); notifyListeners(); print("App Theme Set: $_appThemeType"); }
  void toggleThemeMode() { /* ... Same toggle logic ... */ ThemeMode nextMode; if (_themeMode == ThemeMode.light) { nextMode = ThemeMode.dark; } else if (_themeMode == ThemeMode.dark) { nextMode = ThemeMode.system; } else { nextMode = ThemeMode.light; } setThemeMode(nextMode); }
}
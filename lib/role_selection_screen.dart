// lib/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

// Import theme files
import 'theme/theme_provider.dart'; // For AppThemeType if needed directly

// --- CORRECTED IMPORT for your Phone Auth Screen ---
import 'login/Phone_Auth.dart'; // Assuming it's in lib/Phone_Auth.dart
// --- End Import ---

// --- Constants ---
const String _lottieLogoAsset = 'assets/animation.json'; // Ensure path is correct
const String _primaryFontFamily = 'Nunito'; // Ensure font is set up
const double _cardRadius = 20.0;
// --- End Constants ---

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  // Helper function to build the role selection cards
  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color cardColor,
    required Color contentColor, // Color for icon and text inside
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 4.0,
          color: cardColor, // Use passed card color
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
          clipBehavior: Clip.antiAlias, // Clip child content if needed
          child: AspectRatio(
            aspectRatio: 1.0, // Keep it square-ish
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 55, color: contentColor), // Slightly larger icon
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19, // Slightly larger text
                    fontWeight: FontWeight.bold,
                    fontFamily: _primaryFontFamily,
                    color: contentColor, // Use passed content color
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    // Use theme gradient for background
    final Gradient backgroundGradient = LinearGradient(
        colors: themeProvider.currentAccentGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter);
    // Determine text/icon color contrast on gradient
    final Color onGradientColor =
    ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    // Set status bar style based on gradient
    SystemChrome.setSystemUIOverlayStyle(
        ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 35.0), // Adjusted padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3), // Adjust flex for spacing

                // Lottie Animation
                SizedBox(
                  height: 160, // Slightly larger Lottie
                  width: 160,
                  child: Lottie.asset(_lottieLogoAsset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 35),

                // Welcome Text
                Text(
                  "Welcome!",
                  style: TextStyle(
                    fontSize: 30, // Larger
                    fontWeight: FontWeight.bold,
                    fontFamily: _primaryFontFamily,
                    color: onGradientColor,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Please select your role to get started.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18, // Slightly larger
                    fontFamily: _primaryFontFamily,
                    color: onGradientColor.withOpacity(0.85), // Slightly more opaque
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 60), // More space before cards

                // Role Selection Cards
                Row(
                  children: [
                    _buildRoleCard(
                      context: context,
                      title: "User",
                      icon: Icons.person_outline,
                      cardColor: currentTheme.cardColor, // Theme card color (White/Dark Surface)
                      contentColor: colorScheme.primary, // Theme Accent Color for icon/text
                      onTap: () {
                        print("Role Selected: User");
                        // --- Navigate to LoginScreen with role ---
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const LoginScreen(role: 'user') // Pass 'user' role
                        ));
                      },
                    ),
                    const SizedBox(width: 25), // Increased space between cards
                    _buildRoleCard(
                      context: context,
                      title: "Counselor",
                      icon: Icons.health_and_safety_outlined,
                      cardColor: colorScheme.primary, // Theme Accent Color for card BG
                      contentColor: colorScheme.onPrimary, // Contrast color (White/Black)
                      onTap: () {
                        print("Role Selected: Counselor");
                        // --- Navigate to LoginScreen with role ---
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const LoginScreen(role: 'counselor') // Pass 'counselor' role
                        ));
                      },
                    ),
                  ],
                ),
                const Spacer(flex: 4), // Adjust flex for spacing
              ],
            ),
          ),
        ),
      ),
    );
  }
}
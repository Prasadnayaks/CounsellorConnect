// lib/voice_note_start_screen.dart
import 'package:counsellorconnect/voicenotes/voice_note_recording_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

// Import theme files
import '../theme/theme_provider.dart';// For AppThemeType if needed directly

// Import the NEXT screen (Recording Screen - create this as a placeholder)
import 'voice_note_start_screen.dart'; // We'll create this next

class VoiceNoteStartScreen extends StatelessWidget {
  const VoiceNoteStartScreen({Key? key}) : super(key: key);

  final String _lottieLogoAsset = 'assets/animation.json'; // Your Lottie file
  // Icon for the big button (can be mic or sound wave)
  final IconData _micIcon = Icons.graphic_eq; // From image, looks like sound waves

  // Helper for Top Bar Buttons (only Close button here)
  Widget _buildTopBarButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    final Color buttonBg = Colors.black.withOpacity(0.03); // Darker semi-transparent BG
    return Material(
      color: buttonBg,
      type: MaterialType.button,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: iconColor.withOpacity(0.3), size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: const EdgeInsets.all(11),
        constraints: const BoxConstraints(),
        splashRadius: 24,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;

    // Use the theme's current accent gradient for background
    final Gradient backgroundGradient = LinearGradient(
        colors: themeProvider.currentAccentGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter);
    // Determine contrast color for text/icons on this gradient
    final Color onGradientColor =
    ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
        ? Colors.white
        : Colors.black87; // Using black for better contrast on very light blue gradients
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.7);

    // Set status bar style based on gradient brightness
    SystemChrome.setSystemUIOverlayStyle(
        ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
            ? SystemUiOverlayStyle.light // Light icons for dark gradient
            : SystemUiOverlayStyle.dark   // Dark icons for light gradient
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          bottom: false, // Allow content to extend to bottom for button placement
          child: Column(
            children: [
              // --- Top Bar (Lottie and Close Button) ---
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 15.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 44), // Spacer for left side, to center Lottie
                    SizedBox(
                      height: 120, // Size as per image
                      width: 120,
                      child: Lottie.asset(_lottieLogoAsset, fit: BoxFit.contain),
                    ),
                    _buildTopBarButton(
                      context: context,
                      icon: Icons.close,
                      tooltip: "Close",
                      iconColor: onGradientColor,
                      onPressed: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40), // Space after top bar

              // --- Prompt Texts ---
              Text(
                "Voice Note", // Large, Faded text
                style: TextStyle(
                  fontSize: 54, // Large size
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Nunito', // Ensure Nunito is app default
                  color: onGradientColor.withOpacity(0.10), // Very transparent
                  height: 0.8, // Tight line height
                ),
              ),

              Transform.translate(
                offset: const Offset(0, -12), // move up by 10 pixels
                child: Text(
                  "What's on your mind?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Nunito',
                    color: Colors.white,
                  ),
                ),
              ),

              Text(
                "I'LL JOT IT DOWN FOR YOU",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Nunito',
                  color: onGradientMutedColor,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(), // Pushes Mic button to the bottom

              // --- Microphone Button ---
              GestureDetector(
                onTap: () {
                  print("Mic button tapped - Navigating to VoiceNoteRecordingScreen");
                  // Navigate to the actual recording screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VoiceNoteRecordingScreen()),
                  );

                },
                child: Container(
                  padding: const EdgeInsets.all(30), // Makes the circle larger
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.95), // Solid white circle
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 3,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Icon(
                    _micIcon, // Use the sound wave like icon
                    color: colorScheme.primary, // Use theme accent color from ColorScheme
                    size: 35, // Larger icon
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Text(
                "TAP TO START",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Nunito',
                  color: onGradientColor.withOpacity(0.9),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 70), // Space for gesture bar
            ],
          ),
        ),
      ),
    );
  }
}
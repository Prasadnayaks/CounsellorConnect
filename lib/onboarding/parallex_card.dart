// lib/onboarding/parallex_card.dart
// Defines the OnboardingScreen widget.
// OnboardingFeatureCard now uses Icons and a "frosted glass" style.

import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// Lottie is removed as we'll use Icons, unless you have a very specific small Lottie for the last page.
// import 'package:lottie/lottie.dart';

import '../role_selection_screen.dart';
import '../theme/theme_provider.dart';

// --- Constants for Onboarding ---
const String _fontFamilyOnboarding = 'Nunito';
// const String _appLottieAsset = 'assets/animation.json'; // We might use an icon for the last page too.
const double _featureCardRadius = 26.0; // Slightly larger radius for softer cards
const double _actionButtonRadius = 20.0;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- App-Specific Onboarding Content with Icons ---
  // TODO: Replace "CounsellorConnect" with your actual app name if different.
  // Icons from `Icons` class (Flutter's Material Design icons).
  final List<Map<String, dynamic>> _appOnboardingData = [
    {
      "icon": Icons.spa_outlined, // Icon representing wellness, peace
      "title": "Welcome to CounsellorConnect!",
      "subtitle": "Your dedicated space for personal growth, mindful reflection, and supportive connections.",
    },
    {
      "icon": Icons.track_changes_outlined, // Icon for tracking, understanding
      "title": "Discover Your Inner World",
      "subtitle": "Track your moods, explore daily truth prompts, and capture fleeting thoughts with voice notes.",
    },
    {
      "icon": Icons.lightbulb_outline_rounded, // Icon for inspiration, ideas
      "title": "Daily Strengths & Insights",
      "subtitle": "Engage with daily positive thoughts and overcome meaningful challenges designed for your growth.",
    },
    {
      "icon": Icons.support_agent_outlined, // Icon for support, connection
      "title": "Connect with Professionals",
      "subtitle": "Easily book appointments and initiate confidential chats with experienced counselors.",
    },
    {
      "icon": Icons.celebration_rounded, // Icon for starting, celebration
      "title": "Begin Your Journey",
      "subtitle": "Take the first step towards a more balanced, understood, and fulfilling life with us.",
    }
  ];
  // --- End App-Specific Data ---

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (!mounted) return;
      final newPage = _pageController.page?.round() ?? 0;
      if (newPage != _currentPage) {
        setState(() {
          _currentPage = newPage;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;

    final Gradient backgroundGradient = LinearGradient(
        colors: themeProvider.currentAccentGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight);

    final Color onGradientColor =
    ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
        ? Colors.white
        : Colors.black.withOpacity(0.85);

    SystemChrome.setSystemUIOverlayStyle(
        ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark
    );

    bool isLastPage = _currentPage == _appOnboardingData.length - 1;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10.0, left: 16, right: 16, bottom: 5.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedOpacity(
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: onGradientColor.withOpacity(0.8), size: 22),
                        onPressed: _currentPage > 0 ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic) : null,
                        tooltip: "Previous",
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: !isLastPage ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: !isLastPage ? () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const RoleSelectionScreen())) : null,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        child: Text("SKIP", style: TextStyle(
                            fontFamily: _fontFamilyOnboarding, color: onGradientColor.withOpacity(0.9),
                            fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 7, // Cards take up more space
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _appOnboardingData.length,
                  itemBuilder: (context, index) {
                    final itemData = _appOnboardingData[index];
                    return OnboardingFeatureCard(
                      title: itemData['title']!,
                      subtitle: itemData['subtitle']!,
                      iconData: itemData['icon'] as IconData, // Pass IconData
                      onCardColor: onGradientColor, // Text color on card will be onGradientColor
                    );
                  },
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      DotIndicator(
                        currentPage: _currentPage,
                        itemCount: _appOnboardingData.length,
                        activeColor: onGradientColor,
                        inactiveColor: onGradientColor.withOpacity(0.35),
                      ),
                      const SizedBox(height: 35),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isLastPage) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                              );
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            // Button background uses the theme's card color for a soft, integrated look
                            backgroundColor: currentTheme.cardColor.withOpacity(0.90), // Slightly less opaque
                            foregroundColor: colorScheme.primary, // Text color from primary accent
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_actionButtonRadius),
                            ),
                            elevation: 5,
                            shadowColor: Colors.black.withOpacity(0.25),
                          ),
                          child: Text(
                            isLastPage ? "GET STARTED" : "CONTINUE",
                            style: TextStyle(
                              fontFamily: _fontFamilyOnboarding,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 5 : 25),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData iconData;
  final Color onCardColor; // Color for text & icon, should contrast with blurred bg

  const OnboardingFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.onCardColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Make cards slightly taller to accommodate icon and text comfortably
    final cardHeight = screenHeight * 0.55;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Center( // Center the card content
        child: ClipRRect( // Clip the BackdropFilter for rounded corners
          borderRadius: BorderRadius.circular(_featureCardRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0), // Apply blur
            child: Container(
              width: double.infinity, // Card takes available width
              height: cardHeight,
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 30.0),
              decoration: BoxDecoration(
                // Semi-transparent white or black based on onCardColor for the "frosted" effect
                color: (onCardColor == Colors.white ? Colors.white : Colors.black).withOpacity(0.15),
                borderRadius: BorderRadius.circular(_featureCardRadius),
                border: Border.all(
                  color: (onCardColor == Colors.white ? Colors.white : Colors.black).withOpacity(0.25),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Vertically center content
                crossAxisAlignment: CrossAxisAlignment.center, // Horizontally center content
                children: [
                  Icon(
                    iconData,
                    size: 64, // Prominent icon size
                    color: onCardColor.withOpacity(0.9),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _fontFamilyOnboarding,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: onCardColor,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _fontFamilyOnboarding,
                      fontSize: 15,
                      color: onCardColor.withOpacity(0.85),
                      height: 1.5,
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

class DotIndicator extends StatelessWidget {
  final int currentPage;
  final int itemCount;
  final Color activeColor;
  final Color inactiveColor;

  const DotIndicator({
    super.key,
    required this.currentPage,
    required this.itemCount,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutSine, // Smoother curve
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: currentPage == index ? 26 : 10, // Active dot is noticeably wider
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5), // More rounded
            color: currentPage == index ? activeColor : inactiveColor,
            boxShadow: currentPage == index ? [ // Subtle shadow for active dot
              BoxShadow(
                  color: activeColor.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0,1)
              )
            ] : [],
          ),
        );
      }),
    );
  }
}
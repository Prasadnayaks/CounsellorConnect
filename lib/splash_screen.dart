// lib/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/theme_provider.dart';
import 'main_navigation_shell.dart';

class BreathingSplashScreen extends StatefulWidget {
  const BreathingSplashScreen({Key? key}) : super(key: key);

  @override
  _BreathingSplashScreenState createState() => _BreathingSplashScreenState();
}

class _BreathingSplashScreenState extends State<BreathingSplashScreen>
    with TickerProviderStateMixin { // Changed to TickerProviderStateMixin for multiple controllers
  late AnimationController _breathingController;
  late AnimationController _textAndButtonController; // For text and skip button fade

  // Animations for 3 circles
  late Animation<double> _circleScale1Animation; // Innermost
  late Animation<double> _circleScale2Animation; // Middle
  late Animation<double> _circleScale3Animation; // Outermost
  late Animation<double> _circleOpacity3Animation; // Opacity for outermost

  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _titleOpacityAnimation; // For "Just Breathe" title
  late Animation<double> _skipButtonOpacityAnimation;


  static const double inhaleDurationSeconds = 4.0;
  static const double holdAfterInhaleDurationSeconds = 2.0;
  static const double exhaleDurationSeconds = 6.0;
  static const double holdAfterExhaleDurationSeconds = 1.0;

  static const double totalCycleSeconds = inhaleDurationSeconds +
      holdAfterInhaleDurationSeconds +
      exhaleDurationSeconds +
      holdAfterExhaleDurationSeconds;

  String _guideText = "Inhale...";
  String _titleText = "Just Breathe"; // New shorter title
  bool _showSkipButton = false;
  bool _navigationDone = false;

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration:  Duration(seconds: totalCycleSeconds.toInt()),
    );

    _textAndButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Duration for text/button fade-in
    );


    // Circle 1 (Innermost - most pronounced scale)
    _circleScale1Animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 0.8).chain(CurveTween(curve: Curves.easeInOutSine)), weight: inhaleDurationSeconds),
      TweenSequenceItem(tween: ConstantTween<double>(0.8), weight: holdAfterInhaleDurationSeconds),
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 0.5).chain(CurveTween(curve: Curves.easeInOutSine)), weight: exhaleDurationSeconds),
      TweenSequenceItem(tween: ConstantTween<double>(0.5), weight: holdAfterExhaleDurationSeconds),
    ]).animate(_breathingController);

    // Circle 2 (Middle - slightly less scale, slight delay or different curve)
    _circleScale2Animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: inhaleDurationSeconds), // Different curve
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: holdAfterInhaleDurationSeconds),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.6).chain(CurveTween(curve: Curves.elasticIn)), weight: exhaleDurationSeconds),
      TweenSequenceItem(tween: ConstantTween<double>(0.6), weight: holdAfterExhaleDurationSeconds),
    ]).animate(_breathingController);

    // Circle 3 (Outermost - more opacity based, subtle scale)
    _circleScale3Animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.15).chain(CurveTween(curve: Curves.easeIn)), weight: inhaleDurationSeconds),
      TweenSequenceItem(tween: ConstantTween<double>(1.15), weight: holdAfterInhaleDurationSeconds),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 0.8).chain(CurveTween(curve: Curves.easeOut)), weight: exhaleDurationSeconds),
      TweenSequenceItem(tween: ConstantTween<double>(0.8), weight: holdAfterExhaleDurationSeconds),
    ]).animate(_breathingController);

    _circleOpacity3Animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.05, end: 0.2).chain(CurveTween(curve: Curves.easeIn)), weight: inhaleDurationSeconds),
      TweenSequenceItem(tween: ConstantTween<double>(0.2), weight: holdAfterInhaleDurationSeconds),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 0.05).chain(CurveTween(curve: Curves.easeOut)), weight: exhaleDurationSeconds),
      TweenSequenceItem(tween: ConstantTween<double>(0.05), weight: holdAfterExhaleDurationSeconds),
    ]).animate(_breathingController);


    _logoOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: inhaleDurationSeconds * 0.6),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: inhaleDurationSeconds * 0.4 + holdAfterInhaleDurationSeconds + exhaleDurationSeconds * 0.6),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.5).chain(CurveTween(curve: Curves.easeOut)), weight: exhaleDurationSeconds * 0.4 + holdAfterExhaleDurationSeconds),
    ]).animate(_breathingController);

    _titleOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textAndButtonController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut))
    );
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textAndButtonController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut))
    );
    _skipButtonOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textAndButtonController, curve: const Interval(0.6, 1.0, curve: Curves.easeOut))
    );


    _breathingController.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        Future.delayed(Duration.zero, () => setState(() => _guideText = "Inhale..."));
        Future.delayed( Duration(seconds: inhaleDurationSeconds.toInt()), () {
          if (mounted && _breathingController.isAnimating) setState(() => _guideText = "Hold...");
        });
        Future.delayed( Duration(seconds: (inhaleDurationSeconds + holdAfterInhaleDurationSeconds).toInt()), () {
          if (mounted && _breathingController.isAnimating) setState(() => _guideText = "Exhale...");
        });
        Future.delayed( Duration(seconds: (inhaleDurationSeconds + holdAfterInhaleDurationSeconds + exhaleDurationSeconds).toInt()), () {
          if (mounted && _breathingController.isAnimating) setState(() => _guideText = "Hold...");
        });
      } else if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _breathingController.forward();
    _textAndButtonController.forward(); // Start text and button fade-ins

    Timer(const Duration(milliseconds: 1500), () { // This timer remains for _showSkipButton
      if (mounted) {
        setState(() {
          _showSkipButton = true;
        });
      }
    });
  }

  void _navigateToHome() {
    if (_navigationDone) return;
    _navigationDone = true;
    if (_breathingController.isAnimating) {
      _breathingController.stop();
    }
    if (_textAndButtonController.isAnimating) {
      _textAndButtonController.stop();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainNavigationShell()),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _textAndButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final circleBaseDiameter = screenWidth * 0.85;
    final logoSize = screenWidth * 0.50;

    final Color baseCircleColor = themeProvider.currentAccentGradient.isNotEmpty
        ? themeProvider.currentAccentGradient.last // Use a color from the gradient
        : Colors.blueAccent;
    final Color guideTextColor = themeProvider.currentAccentGradient.isNotEmpty
        ? (ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
        ? Colors.white.withOpacity(0.9)
        : Colors.black.withOpacity(0.8))
        : Colors.black.withOpacity(0.8);
    final Color titleTextColor = themeProvider.currentAccentGradient.isNotEmpty
        ? (ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
        ? Colors.white
        : Colors.white) // Title often looks good in white on gradients
        : Colors.white;


    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: themeProvider.currentAccentGradient.last,
      systemNavigationBarIconBrightness: ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.last) == Brightness.dark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeProvider.currentAccentGradient.isNotEmpty
                ? themeProvider.currentAccentGradient
                : [Colors.lightBlue.shade200, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // --- Three Animated Circles ---
            AnimatedBuilder(
              animation: _breathingController,
              builder: (context, child) {
                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outermost Circle (more opacity based)
                      Transform.scale(
                        scale: _circleScale3Animation.value,
                        child: Opacity(
                          opacity: _circleOpacity3Animation.value,
                          child: Container(
                            width: circleBaseDiameter * 1.1, // Slightly larger base
                            height: circleBaseDiameter * 1.1,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: baseCircleColor.withOpacity(0.15), // Very subtle
                            ),
                          ),
                        ),
                      ),
                      // Middle Circle
                      Transform.scale(
                        scale: _circleScale2Animation.value,
                        child: Container(
                          width: circleBaseDiameter,
                          height: circleBaseDiameter,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: baseCircleColor.withOpacity(0.20), // A bit more visible
                              border: Border.all(
                                color: baseCircleColor.withOpacity(0.2),
                                width: 1.5,
                              )
                          ),
                        ),
                      ),
                      // Innermost Circle
                      Transform.scale(
                        scale: _circleScale1Animation.value,
                        child: Container(
                          width: circleBaseDiameter * 0.75, // Smaller base for this one
                          height: circleBaseDiameter * 0.75,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: baseCircleColor.withOpacity(0.25), // Most visible pulsating part
                              border: Border.all(
                                color: baseCircleColor.withOpacity(0.3),
                                width: 2.0,
                              )
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Center(
              child: FadeTransition(
                opacity: _logoOpacityAnimation,
                child: Image.asset(
                    'assets/logo/logo_transparent (2).png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.healing_outlined, size: logoSize * 0.8, color: guideTextColor.withOpacity(0.5));
                    }
                ),
              ),
            ),
            // Title Text "Just Breathe" - Positioned higher
            Align(
              alignment: Alignment(0.0, -0.65), // Adjust Y for positioning
              child: FadeTransition(
                opacity: _titleOpacityAnimation,
                child: Text(
                  _titleText,
                  style: TextStyle(
                    fontSize: 28, // Or your desired size
                    color: titleTextColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Nunito',
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black.withOpacity(0.25),
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: screenHeight * 0.18), // Adjusted padding
                child: FadeTransition(
                  opacity: _textOpacityAnimation,
                  child: Text(
                    _guideText,
                    style: TextStyle(
                      fontSize: 18, // Slightly smaller guide text
                      color: guideTextColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ),
            ),
            if (_showSkipButton) // Skip button uses its own opacity animation now
              Positioned(
                bottom: 40,
                right: 30,
                child: FadeTransition(
                  opacity: _skipButtonOpacityAnimation,
                  child: TextButton(
                    onPressed: _navigateToHome,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        backgroundColor: Colors.black.withOpacity(0.15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    child: Text(
                      "Skip",
                      style: TextStyle(color: guideTextColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
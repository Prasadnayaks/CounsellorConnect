import 'package:counsellorconnect/onboarding/parallex_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/delayed_animation.dart';
//import 'utils/delayed_animation.dart'; // Importing the DelayedAnimation widget


class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  _StartPageState createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with TickerProviderStateMixin {
  static const _baseDelay = 500;
  late AnimationController _popUpController;
  late AnimationController _pressController;

  final Color _primaryColor = const Color(0xFF8185E2);
  final Color _backgroundColor = const Color(0xFF6367D1);
  final Color _textColor = Colors.white;

  @override
  void initState() {
    super.initState();

    // Controller for pop-up animation
    _popUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Controller for press animation
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Start the pop-up animation after a delay
    Future.delayed(const Duration(milliseconds: 4500), () {
      _popUpController.forward();
    });
  }

  @override
  void dispose() {
    _popUpController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimatedLogo(),
              const SizedBox(height: 40),
              _buildTitleTexts(),
              const SizedBox(height: 40),
              _buildFeatureTexts(),
              const Spacer(),
              _buildActionButtons(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return DelayedAnimation(
      delay: _baseDelay + 500,
      child: Container(
        width: 150,
        height: 150,
        child: Lottie.asset(
          'assets/animation.json', // Replace with your Lottie animation file
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildTitleTexts() {
    return Column(
      children: [
        DelayedAnimation(
          delay: _baseDelay + 1000,
          child: Text(
            "Hi There",
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
        DelayedAnimation(
          delay: _baseDelay + 2000,
          child: Text(
            "I'm Prasad",
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTexts() {
    return Column(
      children: [
        DelayedAnimation(
          delay: _baseDelay + 3000,
          child: _FeatureText("Your New Personal"),
        ),
        DelayedAnimation(
          delay: _baseDelay + 3000,
          child: _FeatureText("Journaling Companion"),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        DelayedAnimation(
          delay: _baseDelay + 4000,
          child: _AnimatedButton(
            popUpController: _popUpController,
            pressController: _pressController,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => OnboardingScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        DelayedAnimation(
          delay: _baseDelay + 5000,
          child: TextButton(
            onPressed: () {},
            child: Text(
              "I ALREADY HAVE AN ACCOUNT",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textColor,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureText extends StatelessWidget {
  final String text;

  const _FeatureText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 20,
        color: Colors.white,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

class _AnimatedButton extends StatelessWidget {
  final VoidCallback onPressed;
  final AnimationController popUpController;
  final AnimationController pressController;

  const _AnimatedButton({
    required this.onPressed,
    required this.popUpController,
    required this.pressController,
  });

  @override
  Widget build(BuildContext context) {
    // Pop-up animation (small → large → normal with bounce)
    final Animation<double> popUpAnimation = Tween<double>(
      begin: 0.0, // Start small
      end: 1.0, // End at normal size
    ).animate(
      CurvedAnimation(
        parent: popUpController,
        curve: Curves.elasticOut, // Bouncy curve for pop-up effect
      ),
    );

    // Press animation (scale down when pressed, then scale back up)
    final Animation<double> pressAnimation = Tween<double>(
      begin: 1.0, // Normal size
      end: 0.95, // Slightly smaller when pressed
    ).animate(pressController);

    return ScaleTransition(
      scale: popUpAnimation,
      child: GestureDetector(
        onTapDown: (_) {
          pressController.forward(); // Scale down when pressed
        },
        onTapUp: (_) {
          pressController.reverse(); // Scale back up when released
          onPressed(); // Trigger the button's action
        },
        child: ScaleTransition(
          scale: pressAnimation,
          child: Container(
            width: 200,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                "GET STARTED",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//import 'package:counsellor_connect2/login/loginauth.dart';

import 'package:counsellorconnect/onboarding/onboarding_page.dart';
import 'package:counsellorconnect/role_selection_screen.dart';

import 'Name_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isButtonEnabled = false;

  final List<String> _titles = [
    "Welcome to App",
    "Discover Features",
    "Stay Connected",
    "Enjoy Benefits",
    "Let's Begin"
  ];

  final List<String> _subtitles = [
    "Your journey starts here.",
    "Explore amazing functionalities.",
    "Connect with people globally.",
    "Unlock exclusive rewards.",
    "Ready to get started?"
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
        _isButtonEnabled = _currentPage == _titles.length - 1;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6367D1),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _titles.length,
                    itemBuilder: (context, index) {
                      return ParallaxCard(
                        title: _titles[index],
                        subtitle: _subtitles[index],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _subtitles[_currentPage],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                DotIndicator(
                  currentPage: _currentPage,
                  itemCount: _titles.length,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isButtonEnabled
                      ? () {
                    // Navigate to the next screen or perform an action
                    // Navigator.of(context).push(MaterialPageRoute(builder: (context) => SecondScreen()));

                     Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
                     );


                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isButtonEnabled
                        ? Colors.white.withOpacity(0.9)
                        : Colors.white.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    minimumSize: const Size(250, 60),
                    elevation: 5,
                  ),
                  child: Text(
                    "CONTINUE",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF6367D1),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
            // Back Button
            Positioned(
              top: 20,
              left: 20,
              child: Visibility(
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => StartPage()),
                    );
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: Colors.white,
                  iconSize: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParallaxCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const ParallaxCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6367D1),
                Color(0xFFA67CEB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
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

  const DotIndicator({
    super.key,
    required this.currentPage,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: currentPage == index
                ? Colors.white
                : Colors.white.withOpacity(0.5),
          ),
        );
      }),
    );
  }
}
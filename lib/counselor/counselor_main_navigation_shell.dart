// lib/counselor/counselor_main_navigation_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart'; // Your ThemeProvider
import 'counselor_dashboard_screen.dart'; // Your existing dashboard
import 'counselor_chat_overview_screen.dart'; // Placeholder
import 'counselor_user_journaling_screen.dart'; // Placeholder

const String _primaryFontFamily = 'Nunito';
const double _bottomNavTopRadius = 24.0; // Radius for top corners of the nav bar container
const double _bottomNavBarHeight = 65.0; // Desired height for the custom bar area

class CounselorMainNavigationShell extends StatefulWidget {
  const CounselorMainNavigationShell({Key? key}) : super(key: key);

  @override
  State<CounselorMainNavigationShell> createState() => _CounselorMainNavigationShellState();
}

class _CounselorMainNavigationShellState extends State<CounselorMainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CounselorDashboardScreen(),
    const CounselorChatOverviewScreen(),
    const CounselorUserJournalingScreen(),
  ];

  void _onItemTapped(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;

    // System UI Overlay for this shell
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: currentTheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: currentTheme.cardColor, // Match the custom BottomNav background
      systemNavigationBarIconBrightness: currentTheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Custom Bottom Navigation Bar Implementation
      bottomNavigationBar: Container(
        height: _bottomNavBarHeight + MediaQuery.of(context).padding.bottom, // Adjust height to include safe area
        decoration: BoxDecoration(
          color: currentTheme.cardColor, // Use cardColor for a slightly elevated feel
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(_bottomNavTopRadius),
            topRight: Radius.circular(_bottomNavTopRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: currentTheme.shadowColor.withOpacity(0.1), // Subtle shadow
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, -3), // Shadow upwards
            ),
          ],
        ),
        child: ClipRRect( // Clip the BottomNavigationBar itself to respect rounded corners
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(_bottomNavTopRadius),
            topRight: Radius.circular(_bottomNavTopRadius),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent, // Make actual BottomNav background transparent
            elevation: 0, // Handled by the container
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            selectedItemColor: colorScheme.primary,
            unselectedItemColor: colorScheme.onSurface.withOpacity(0.55),
            selectedLabelStyle: const TextStyle(
              fontFamily: _primaryFontFamily,
              fontWeight: FontWeight.bold, // Selected item bolder
              fontSize: 11.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: _primaryFontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            selectedIconTheme: IconThemeData(size: 26, color: colorScheme.primary), // Slightly larger selected icon
            unselectedIconTheme: IconThemeData(size: 24, color: colorScheme.onSurface.withOpacity(0.55)),
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 2.0), // Add slight padding below icon
                  child: Icon(Icons.calendar_today_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 2.0),
                  child: Icon(Icons.calendar_today_rounded),
                ),
                label: 'Appointments',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 2.0),
                  child: Icon(Icons.chat_bubble_outline_rounded),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 2.0),
                  child: Icon(Icons.chat_bubble_rounded),
                ),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 2.0),
                  child: Icon(Icons.edit_note_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 2.0),
                  child: Icon(Icons.edit_note_rounded),
                ),
                label: 'Journal',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
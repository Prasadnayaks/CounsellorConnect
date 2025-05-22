// lib/mood_checkin_screen2.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:table_calendar/table_calendar.dart'; // Keep if using picker in screen 1
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart'; // Keep if using picker in screen 1

// Import theme files
import '../theme/theme_provider.dart';

// Screen imports
// import 'home_screen.dart'; // Not needed directly for navigation FROM here
import '../models/quote_model.dart'; // Keep if needed for user info fetch fallback
import 'mood_checkin_screen3.dart'; // Import the next screen

class MoodCheckinScreen2 extends StatefulWidget {
  final String moodLabel;
  final int moodIndex;
  final DateTime entryDateTime;

  const MoodCheckinScreen2({
    Key? key,
    required this.moodLabel,
    required this.moodIndex,
    required this.entryDateTime,
  }) : super(key: key);

  @override
  State<MoodCheckinScreen2> createState() => _MoodCheckinScreen2State();
}

class _MoodCheckinScreen2State extends State<MoodCheckinScreen2> {
  // State
  Set<String> _selectedActivities = {};
  final int _maxSelection = 10;
  String? _userName;
  bool _isLoadingName = true;
  // --- Use _isSaving consistently ---
  bool _isSaving = false; // Tracks if navigating/processing next step
  // --- End Fix ---

  // Activity Data
  final List<Map<String, dynamic>> _availableActivities = [ {'label': 'work', 'icon': Icons.work_outline}, {'label': 'family', 'icon': Icons.home_outlined}, {'label': 'friends', 'icon': Icons.people_outline}, {'label': 'hobbies', 'icon': Icons.extension_outlined}, {'label': 'school', 'icon': Icons.school_outlined}, {'label': 'relationship', 'icon': Icons.favorite_border}, {'label': 'traveling', 'icon': Icons.flight_takeoff_outlined}, {'label': 'sleep', 'icon': Icons.bedtime_outlined}, {'label': 'food', 'icon': Icons.restaurant_outlined}, {'label': 'exercise', 'icon': Icons.fitness_center_outlined}, {'label': 'health', 'icon': Icons.monitor_heart_outlined}, {'label': 'music', 'icon': Icons.music_note_outlined}, {'label': 'gaming', 'icon': Icons.sports_esports_outlined}, {'label': 'reading', 'icon': Icons.menu_book_outlined}, {'label': 'relaxing', 'icon': Icons.self_improvement_outlined}, {'label': 'chores', 'icon': Icons.home_repair_service_outlined}, {'label': 'social media', 'icon': Icons.hub_outlined}, {'label': 'news', 'icon': Icons.newspaper_outlined}, {'label': 'weather', 'icon': Icons.wb_cloudy_outlined}, {'label': 'shopping', 'icon': Icons.shopping_bag_outlined}, {'label': 'other', 'icon': Icons.add_circle_outline}, ];
  final String _lottieLogoAsset = 'assets/animation.json';

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() { super.initState(); _currentUser = _auth.currentUser; _fetchUserName(); }

  // Fetch User Name
  Future<void> _fetchUserName() async { /* ... Same as previous ... */ if (!mounted) return; setState(() { _isLoadingName = true; }); if (_currentUser == null) { if (mounted) setState(() { _userName = "Friend"; _isLoadingName = false; }); return; } try { final doc = await _firestore.collection('users').doc(_currentUser!.uid).get(); if (mounted) { setState(() { if (doc.exists && (doc.data() as Map).containsKey('name')) { _userName = (doc.data() as Map)['name']; } else { _userName = "Friend"; } _isLoadingName = false; }); } } catch (e) { if (mounted) { setState(() { _userName = "Friend"; _isLoadingName = false; }); } } }

  // Activity Selection Logic
  void _toggleActivitySelection(String activityLabel) { /* ... Same as previous ... */ if (!mounted) return; if (activityLabel == 'other') { print("Other/Add activity tapped"); return; } setState(() { if (_selectedActivities.contains(activityLabel)) { _selectedActivities.remove(activityLabel); } else { if (_selectedActivities.length < _maxSelection) { _selectedActivities.add(activityLabel); } else { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("You can select up to $_maxSelection activities."), duration: const Duration(seconds: 2)), ); } } }); }

  // --- UPDATED: Renamed Method and Reset State Correctly ---
  // Navigate to Feelings Screen
  void _proceedToFeelingsScreen() {
    if (_isSaving || _selectedActivities.isEmpty) return; // Use _isSaving check

    setState(() { _isSaving = true; }); // Indicate processing start

    print("Proceeding to Feelings - Mood: ${widget.moodLabel} (${widget.moodIndex}), Time: ${widget.entryDateTime}, Activities: ${_selectedActivities.toList()}");

    Navigator.push(context, CupertinoPageRoute(builder: (_) => MoodCheckinScreen3( // Navigate to Screen 3
      moodLabel: widget.moodLabel,
      moodIndex: widget.moodIndex,
      entryDateTime: widget.entryDateTime,
      selectedActivities: _selectedActivities.toList(),
    ))).then((_) {
      // This runs when Screen 3 is popped or finishes
      if (mounted) setState(() => _isSaving = false); // Reset processing state when returning
    });
    // Saving logic moved to Screen 3
  }
  // --- End Update ---


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    bool isButtonEnabled = _selectedActivities.isNotEmpty;

    SystemChrome.setSystemUIOverlayStyle( ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark );

    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea( bottom: false,
          child: Column( // Use Column + Expanded for fixed button
            children: [
              // Top Bar
              Padding( padding: const EdgeInsets.only(left: 8.0, right: 16.0, top: 10.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                _buildTopBarButton( context: context, icon: Icons.arrow_back_ios_new, tooltip: "Back", iconColor: onGradientColor, onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); }, ),
                SizedBox( height: 125, width: 125, child: Lottie.asset(_lottieLogoAsset, fit: BoxFit.contain), ),
                _buildTopBarButton( context: context, icon: Icons.close, tooltip: "Close Check-in", iconColor: onGradientColor, onPressed: () { int popCount = 0; Navigator.of(context).popUntil((route) => popCount++ >= 2 || !Navigator.of(context).canPop()); }, ),
              ], ), ),
              const SizedBox(height: 20),

              // Prompt Text
              Padding( padding: const EdgeInsets.symmetric(horizontal: 40.0), child: AnimatedSwitcher( duration: const Duration(milliseconds: 300), child: Text( _isLoadingName ? "Amazing! What's making..." : "Amazing! What's making your morning ${widget.moodLabel.toLowerCase()}?", key: ValueKey("${_isLoadingName}_${widget.moodLabel}"), textAlign: TextAlign.center, style: TextStyle( fontSize: 22, fontWeight: FontWeight.bold, color: onGradientColor, height: 1.3 ), ), ) ),
              const SizedBox(height: 12),
              Text( "SELECT UP TO $_maxSelection ACTIVITIES", style: TextStyle( fontSize: 12, fontWeight: FontWeight.w600, color: onGradientColor.withOpacity(0.7), letterSpacing: 0.5 ), ),
              const SizedBox(height: 30),

              // Activity Grid (Scrollable within Expanded)
              Expanded(
                child: Padding( padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: GridView.builder( padding: const EdgeInsets.only(top: 5, bottom: 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 4, crossAxisSpacing: 20.0, mainAxisSpacing: 25.0, childAspectRatio: 0.85, ),
                    itemCount: _availableActivities.length,
                    itemBuilder: (context, index) {
                      final activity = _availableActivities[index]; final String label = activity['label'] as String; final IconData icon = activity['icon'] as IconData; final bool isSelected = _selectedActivities.contains(label);
                      return _buildActivityItem( context: context, icon: icon, label: label, isSelected: isSelected, onTap: () => _toggleActivitySelection(label), );
                    }, ), ), ),

              // Continue Button (Fixed at bottom)
              Padding( padding: const EdgeInsets.symmetric(horizontal: 40.0).copyWith(bottom: 25.0, top: 15.0),
                child: ElevatedButton(
                  // --- FIXED: Use _isSaving and correct method ---
                  onPressed: isButtonEnabled && !_isSaving ? _proceedToFeelingsScreen : null,
                  style: ElevatedButton.styleFrom( backgroundColor: isButtonEnabled ? currentTheme.cardColor : currentTheme.cardColor.withOpacity(0.3), foregroundColor: isButtonEnabled ? colorScheme.primary : colorScheme.primary.withOpacity(0.5), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15)), elevation: isButtonEnabled ? 3 : 0, ),
                  child: _isSaving // Use _isSaving for indicator
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                      : const Text( "CONTINUE", style: TextStyle( fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8 ), ),
                  // --- End Fix ---
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom) // Padding for gesture bar
            ],
          ),
        ),
      ),
    );
  }

  // --- Build Helper Methods ---
  Widget _buildTopBarButton({ required BuildContext context, required IconData icon, required String tooltip, required Color iconColor, required VoidCallback onPressed, }) { /* ... Same dark background version ... */ final Color buttonBg = Colors.black.withOpacity(0.03); return Material( color: buttonBg, type: MaterialType.button, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: IconButton( icon: Icon(icon, color: iconColor.withOpacity(0.2), size: 20), tooltip: tooltip, onPressed: onPressed, padding: const EdgeInsets.all(10), constraints: const BoxConstraints(), splashRadius: 22, ), ); }
  Widget _buildActivityItem({ required BuildContext context, required IconData icon, required String label, required bool isSelected, required VoidCallback onTap, }) { /* ... Same themed version ... */ final theme = Theme.of(context); final colorScheme = theme.colorScheme; final Color defaultItemColor = theme.colorScheme.onPrimary.withOpacity(0.9); final Color selectedItemColor = colorScheme.primary; final Color selectedBgColor = theme.cardColor; bool isOtherButton = (label == 'other'); return GestureDetector( onTap: onTap, child: Container( padding: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration( color: isSelected ? selectedBgColor : Colors.transparent, borderRadius: BorderRadius.circular(15.0), border: isOtherButton && !isSelected ? Border.all(color: defaultItemColor.withOpacity(0.5), width: 1.5,) : null, boxShadow: isSelected ? [ BoxShadow( color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3), ) ] : [], ), child: Column( mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [ Icon( icon, size: 32, color: isSelected ? selectedItemColor : defaultItemColor, ), const SizedBox(height: 8), Text( label, textAlign: TextAlign.center, style: TextStyle( fontSize: 11, color: isSelected ? selectedItemColor : defaultItemColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, ), maxLines: 1, overflow: TextOverflow.ellipsis, ), ], ), ), ); }

} // End _MoodCheckinScreen2State
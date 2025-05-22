import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';

// Import theme files
import '../theme/theme_provider.dart';

// Screen imports
import '../main_navigation_shell.dart';// If needed for user info

// --- Constants ---
const double _chipRadius = 10.0; // Radius for rectangular chips
const String _primaryFontFamily = 'Nunito'; // Define desired font family
// --- End Constants ---

class MoodCheckinScreen4 extends StatefulWidget {
  // Data passed from previous screens
  final String moodLabel;
  final int moodIndex;
  final DateTime entryDateTime;
  final List<String> selectedActivities;
  final List<String> selectedFeelings;

  const MoodCheckinScreen4({
    Key? key,
    required this.moodLabel,
    required this.moodIndex,
    required this.entryDateTime,
    required this.selectedActivities,
    required this.selectedFeelings,
  }) : super(key: key);

  @override
  State<MoodCheckinScreen4> createState() => _MoodCheckinScreen4State();
}

class _MoodCheckinScreen4State extends State<MoodCheckinScreen4> {
  // State
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  bool _isSaving = false;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();
  bool _isKeyboardVisible = false;

  // Icon Maps & Assets (Ensure these are complete)
  final Map<String, IconData> _activityIcons = const { 'work': Icons.work_outline, 'family': Icons.home_outlined, 'friends': Icons.people_outline, 'hobbies': Icons.extension_outlined, 'school': Icons.school_outlined, 'relationship': Icons.favorite_border, 'traveling': Icons.flight_takeoff_outlined, 'sleep': Icons.bedtime_outlined, 'food': Icons.restaurant_outlined, 'exercise': Icons.fitness_center_outlined, 'health': Icons.monitor_heart_outlined, 'music': Icons.music_note_outlined, 'gaming': Icons.sports_esports_outlined, 'reading': Icons.menu_book_outlined, 'relaxing': Icons.self_improvement_outlined, 'chores': Icons.home_repair_service_outlined, 'social media': Icons.hub_outlined, 'news': Icons.newspaper_outlined, 'weather': Icons.wb_cloudy_outlined, 'shopping': Icons.shopping_bag_outlined, 'other': Icons.add_circle_outline, };
  final Map<String, IconData> _feelingIcons = const { 'happy': Icons.sentiment_very_satisfied, 'blessed': Icons.volunteer_activism_outlined, 'good': Icons.sentiment_satisfied, 'lucky': Icons.star_border_outlined, 'confused': Icons.sentiment_neutral, 'bored': Icons.sentiment_dissatisfied_outlined, 'awkward': Icons.sentiment_neutral_outlined, 'stressed': Icons.sentiment_very_dissatisfied_outlined, 'angry': Icons.sentiment_very_dissatisfied, 'anxious': Icons.sentiment_dissatisfied, 'down': Icons.sentiment_very_dissatisfied_sharp, 'calm': Icons.self_improvement_outlined, 'energetic': Icons.flash_on_outlined, 'tired': Icons.battery_alert_outlined, 'grateful': Icons.favorite_outline, 'other': Icons.add_circle_outline, };
  final String _lottieLogoAsset = 'assets/animation.json';

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() { super.initState(); _currentUser = _auth.currentUser; _titleController = TextEditingController(); _notesController = TextEditingController(); _titleFocusNode.addListener(_onFocusChange); _notesFocusNode.addListener(_onFocusChange); }
  @override
  void dispose() { _titleController.dispose(); _notesController.dispose(); _titleFocusNode.removeListener(_onFocusChange); _notesFocusNode.removeListener(_onFocusChange); _titleFocusNode.dispose(); _notesFocusNode.dispose(); super.dispose(); }

  // Keyboard Visibility Handler
  void _onFocusChange() { if (!mounted) return; bool keyboardVisible = _titleFocusNode.hasFocus || _notesFocusNode.hasFocus; if (_isKeyboardVisible != keyboardVisible) { setState(() { _isKeyboardVisible = keyboardVisible; }); } }

  // Final Save Logic
  Future<void> _saveFinalMoodEntry() async { /* ... Same save logic ... */ if (_isSaving || _currentUser == null) return; FocusScope.of(context).unfocus(); setState(() { _isSaving = true; }); final String title = _titleController.text.trim(); final String notes = _notesController.text.trim(); final dataToSave = { 'moodLabel': widget.moodLabel, 'moodIndex': widget.moodIndex, 'entryDateTime': Timestamp.fromDate(widget.entryDateTime), 'selectedActivities': widget.selectedActivities, 'selectedFeelings': widget.selectedFeelings, 'title': title.isEmpty ? null : title, 'notes': notes.isEmpty ? null : notes, 'createdAt': FieldValue.serverTimestamp(), }; try { await _firestore.collection('users').doc(_currentUser!.uid).collection('mood_entries').add(dataToSave); if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const MainNavigationShell()), (Route<dynamic> route) => false, ); } } catch (e) { print("Error saving final mood entry: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Could not save check-in: ${e.toString()}")) ); setState(() { _isSaving = false; }); } } }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.65); // Slightly less muted

    SystemChrome.setSystemUIOverlayStyle( ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea( bottom: false,
          child: GestureDetector( onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                // --- Top Bar ---
                Padding( padding: const EdgeInsets.only(left: 8.0, right: 16.0, top: 15.0, bottom: 8.0), // Adjusted padding
                  child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                    _buildTopBarButton( context: context, icon: Icons.arrow_back_ios_new, tooltip: "Back", iconColor: onGradientColor, onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); }, ),
                    // --- Logo Size Adjusted ---
                    SizedBox( height: 100, width: 100, child: Lottie.asset(_lottieLogoAsset, fit: BoxFit.contain), ),
                    _buildTopBarButton( context: context, icon: Icons.close, tooltip: "Close Check-in", iconColor: onGradientColor, onPressed: () { int popCount = 0; Navigator.of(context).popUntil((route) => popCount++ >= 4 || !Navigator.of(context).canPop()); }, ),
                  ], ), ),
                // Display Selected Date/Time
                Padding( padding: const EdgeInsets.only(top: 0, bottom: 30.0), // More space below date
                  child: Text( DateFormat('MMMM d, hh:mm a').format(widget.entryDateTime), style: TextStyle(color: onGradientColor.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily), ), ),

                // --- Scrollable Content Area ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0), // Slightly more horizontal padding
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Activities Section
                          _buildChipSection(context, "Activities", widget.selectedActivities, onGradientColor, _activityIcons),
                          const SizedBox(height: 35), // Increased spacing
                          // Feelings Section
                          _buildChipSection(context, "Feelings", widget.selectedFeelings, onGradientColor, _feelingIcons),
                          const SizedBox(height: 45), // Increased spacing
                          // Title Input
                          TextField( focusNode: _titleFocusNode, controller: _titleController,
                            style: TextStyle(color: onGradientColor, fontSize: 21, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily), // Larger/Styled
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration( hintText: "Title ...", hintStyle: TextStyle(color: onGradientMutedColor, fontSize: 21, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily), enabledBorder: UnderlineInputBorder( borderSide: BorderSide(color: onGradientColor.withOpacity(0.3)), ), focusedBorder: UnderlineInputBorder( borderSide: BorderSide(color: onGradientColor, width: 1.5), ), ), ),
                          const SizedBox(height: 35), // Increased spacing
                          // Notes Input
                          TextField( focusNode: _notesFocusNode, controller: _notesController,
                            style: TextStyle(color: onGradientColor, fontSize: 18, height: 1.5, fontFamily: _primaryFontFamily), // Larger/Styled
                            textCapitalization: TextCapitalization.sentences, maxLines: 8, minLines: 4,
                            decoration: InputDecoration( hintText: "Add some notes ...", hintStyle: TextStyle(color: onGradientMutedColor, fontSize: 18, fontFamily: _primaryFontFamily), fillColor: onGradientColor.withOpacity(0.08), filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), border: OutlineInputBorder( borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none ), ), ),
                          const SizedBox(height: 30), // Space at end of scroll view
                        ]
                    ),
                  ),
                ),
                // --- End Scrollable Area ---

                // --- Bottom Button Area (Conditional Visibility) ---
                Padding(
                  padding: EdgeInsets.only( left: 40.0, right: 40.0, top: 15.0,
                    bottom: _isKeyboardVisible ? MediaQuery.of(context).viewInsets.bottom + 15.0 : MediaQuery.of(context).padding.bottom + 25.0, ),
                  child: AnimatedSwitcher( duration: const Duration(milliseconds: 200),
                    child: _isKeyboardVisible
                        ? Align( alignment: Alignment.centerRight, key: const ValueKey('done_button'),
                      child: FloatingActionButton.small( onPressed: () => FocusScope.of(context).unfocus(), backgroundColor: currentTheme.cardColor, foregroundColor: colorScheme.primary, elevation: 4.0, tooltip: 'Done Editing', child: const Icon(Icons.check, size: 24), ), )
                        : SizedBox( key: const ValueKey('complete_button'), width: double.infinity, height: 60, // Larger button
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveFinalMoodEntry,
                        style: ElevatedButton.styleFrom( backgroundColor: currentTheme.cardColor, foregroundColor: colorScheme.primary, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15)), elevation: 3, ),
                        child: _isSaving ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)) : const Text( "COMPLETE CHECK-IN", style: TextStyle( fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.8, fontFamily: _primaryFontFamily ), ), // Larger text + Font
                      ), ), ), ),
                // No extra SizedBox needed here
              ],
            ),
          ),
        ),
      ),
    );
  }


  // --- Build Helpers ---
  // Helper for Top Bar Buttons
  Widget _buildTopBarButton({ required BuildContext context, required IconData icon, required String tooltip, required Color iconColor, required VoidCallback onPressed, }) {
    final Color buttonBg = Colors.transparent.withOpacity(0.03); // Slightly Darker BG
    return Material( color: buttonBg, type: MaterialType.button, shape: const CircleBorder(), clipBehavior: Clip.antiAlias,
      child: IconButton( icon: Icon(icon, color: iconColor.withOpacity(0.2), size: 22), // Less transparent Icon
        tooltip: tooltip, onPressed: onPressed, padding: const EdgeInsets.all(11), constraints: const BoxConstraints(), splashRadius: 24, ), );
  }

  // --- UPDATED: Chip Section Helper with Styled Label ---
  Widget _buildChipSection(BuildContext context, String title, List<String> items, Color onGradientColor, Map<String, IconData> iconMap) {
    final theme = Theme.of(context);
    return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
      // --- Styled Section Label ---
      Text( title, // Keep original casing
        style: TextStyle(
          fontSize: 60, // Increased font size
          fontWeight: FontWeight.bold,
          fontFamily: _primaryFontFamily, // Apply font
          color: onGradientColor.withOpacity(0.1), // Faded look
          height: 1.0,
        ),
      ),
      // --- End Styled Label --- // Increased space after label
      if (items.isEmpty) Padding( padding: const EdgeInsets.only(left: 5.0), child: Text("None selected", style: TextStyle(color: onGradientColor.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 14, fontFamily: _primaryFontFamily)), )
      else Wrap( // Use Wrap for chips
        spacing: 14.0, // Increased horizontal space
        runSpacing: 14.0, // Increased vertical space
        children: items.map((label) {
          IconData? icon = iconMap[label.toLowerCase()];
          return _buildChip(context, label, icon); // Build each chip
        }).toList(),
      ),
    ], );
  }
  // --- End Chip Section Update ---

  // --- UPDATED: Chip Builder (Rectangular, Larger, Font) ---
  Widget _buildChip(BuildContext context, String label, IconData? icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Use theme's ChipTheme or define styles
    return Chip(
      avatar: icon != null ? Icon(icon, size: 20, color: colorScheme.primary) : null, // Slightly larger icon
      label: Text(label),
      labelStyle: TextStyle(fontSize: 15, color: colorScheme.primary, fontWeight: FontWeight.w600, fontFamily: _primaryFontFamily), // Larger text, bold, font
      backgroundColor: theme.cardColor.withOpacity(0.9), // Use theme card color
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Increased padding
      // --- Rectangular Shape ---
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_chipRadius), // Use defined radius
          side: BorderSide(color: theme.dividerColor.withOpacity(0.0)) // Use theme divider color
      ),
      // --- End Shape Change ---
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
// --- End Chip Update ---

} // End _MoodCheckinScreen4State
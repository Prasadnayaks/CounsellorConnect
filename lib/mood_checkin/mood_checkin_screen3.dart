// lib/mood_checkin_screen3.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';

// Import theme files
import '../theme/theme_provider.dart';

// Screen imports
import 'mood_checkin_screen4.dart'; // Import the NEXT screen
// Removed Firebase imports if not needed for this screen's logic directly

class MoodCheckinScreen3 extends StatefulWidget {
  // Data passed from previous screens
  final String moodLabel;
  final int moodIndex;
  final DateTime entryDateTime;
  final List<String> selectedActivities;

  const MoodCheckinScreen3({
    Key? key,
    required this.moodLabel,
    required this.moodIndex,
    required this.entryDateTime,
    required this.selectedActivities, // Receive selected activities
  }) : super(key: key);

  @override
  State<MoodCheckinScreen3> createState() => _MoodCheckinScreen3State();
}

class _MoodCheckinScreen3State extends State<MoodCheckinScreen3> {
  // --- State ---
  Set<String> _selectedFeelings = {}; // Store labels of selected feelings
  final int _maxSelection = 10;
  bool _isProceeding = false; // Tracks navigation state

  // --- Feelings Data & Assets ---
  final List<Map<String, dynamic>> _availableFeelings = [ {'label': 'happy', 'icon': Icons.sentiment_very_satisfied}, {'label': 'blessed', 'icon': Icons.volunteer_activism_outlined}, {'label': 'good', 'icon': Icons.sentiment_satisfied}, {'label': 'lucky', 'icon': Icons.star_border_outlined}, {'label': 'confused', 'icon': Icons.sentiment_neutral}, {'label': 'bored', 'icon': Icons.sentiment_dissatisfied_outlined}, {'label': 'awkward', 'icon': Icons.sentiment_neutral_outlined}, {'label': 'stressed', 'icon': Icons.sentiment_very_dissatisfied_outlined}, {'label': 'angry', 'icon': Icons.sentiment_very_dissatisfied}, {'label': 'anxious', 'icon': Icons.sentiment_dissatisfied}, {'label': 'down', 'icon': Icons.sentiment_very_dissatisfied_sharp}, {'label': 'calm', 'icon': Icons.self_improvement_outlined}, {'label': 'energetic', 'icon': Icons.flash_on_outlined}, {'label': 'tired', 'icon': Icons.battery_alert_outlined}, {'label': 'grateful', 'icon': Icons.favorite_outline}, {'label': 'other', 'icon': Icons.add_circle_outline}, ];
  final String _lottieLogoAsset = 'assets/animation.json';
  // --- End State & Data ---

  @override
  void initState() {
    super.initState();
    // No async operations needed here if username isn't displayed
  }

  // --- Feeling Selection Logic ---
  void _toggleFeelingSelection(String feelingLabel) {
    if (!mounted) return;
    if (feelingLabel == 'other') {
      print("Other/Add feeling tapped");
      // TODO: Show dialog or navigate to add custom feeling
      return;
    }
    setState(() {
      if (_selectedFeelings.contains(feelingLabel)) {
        _selectedFeelings.remove(feelingLabel);
      } else {
        if (_selectedFeelings.length < _maxSelection) {
          _selectedFeelings.add(feelingLabel);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("You can select up to $_maxSelection feelings."), duration: const Duration(seconds: 2)),
          );
        }
      }
    });
  }
  // --- End Selection Logic ---

  // --- Navigate to Notes Screen (Screen 4) ---
  void _proceedToNotesScreen() {
    if (_isProceeding || _selectedFeelings.isEmpty) return; // Prevent if busy or none selected

    setState(() { _isProceeding = true; }); // Indicate processing start

    print("Proceeding to Notes - Mood: ${widget.moodLabel} (${widget.moodIndex}), Time: ${widget.entryDateTime}, Activities: ${widget.selectedActivities}, Feelings: ${_selectedFeelings.toList()}");

    // Navigate to the next screen (Notes/Final Save Screen)
    Navigator.push(context, CupertinoPageRoute(builder: (_) => MoodCheckinScreen4(
      moodLabel: widget.moodLabel,
      moodIndex: widget.moodIndex,
      entryDateTime: widget.entryDateTime,
      selectedActivities: widget.selectedActivities, // Pass along activities
      selectedFeelings: _selectedFeelings.toList(), // Pass selected feelings
    ))).then((_) {
      // Reset processing state when/if we come back
      if (mounted) setState(() => _isProceeding = false);
    });
    // Saving logic moved to Screen 4
  }
  // --- End Navigation ---


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    // Use theme gradient for screen background
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    // Determine contrast color for text/icons on this gradient
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    // Continue button enabled state
    bool isButtonEnabled = _selectedFeelings.isNotEmpty;

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle( ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark );

    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea( bottom: false,
          child: Column(
            children: [
              // --- Top Bar ---
              Padding( padding: const EdgeInsets.only(left: 8.0, right: 16.0, top: 10.0),
                child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  _buildTopBarButton( context: context, icon: Icons.arrow_back_ios_new, tooltip: "Back", iconColor: onGradientColor, onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); }, ),
                  SizedBox( height: 125, width: 125, child: Lottie.asset(_lottieLogoAsset, fit: BoxFit.contain), ), // Large Lottie
                  _buildTopBarButton( context: context, icon: Icons.close, tooltip: "Close Check-in", iconColor: onGradientColor, onPressed: () { int popCount = 0; Navigator.of(context).popUntil((route) => popCount++ >= 3 || !Navigator.of(context).canPop()); }, ), // Pop 3 times now
                ], ), ),

              const SizedBox(height: 25), // Adjusted spacing

              // --- Prompt Text ---
              Padding( padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text( "... and how are you feeling about this?", // Prompt for feelings
                  textAlign: TextAlign.center, style: TextStyle( fontSize: 22, fontWeight: FontWeight.bold, color: onGradientColor, height: 1.3 ), ), ),
              const SizedBox(height: 12),
              Text( "SELECT UP TO $_maxSelection FEELINGS", style: TextStyle( fontSize: 12, fontWeight: FontWeight.w600, color: onGradientColor.withOpacity(0.7), letterSpacing: 0.5 ), ),
              const SizedBox(height: 35),

              // --- Feelings Grid (Scrollable within Expanded) ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(top: 5, bottom: 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( crossAxisCount: 4, crossAxisSpacing: 20.0, mainAxisSpacing: 25.0, childAspectRatio: 0.85, ),
                    itemCount: _availableFeelings.length,
                    itemBuilder: (context, index) {
                      final feeling = _availableFeelings[index];
                      final String label = feeling['label'] as String;
                      final IconData icon = feeling['icon'] as IconData;
                      final bool isSelected = _selectedFeelings.contains(label);

                      // Use the same item builder as activities screen
                      return _buildFeelingItem( context: context, icon: icon, label: label, isSelected: isSelected, onTap: () => _toggleFeelingSelection(label), );
                    },
                  ),
                ),
              ),
              // --- End Feelings Grid ---

              // --- Continue Button ---
              Padding( padding: const EdgeInsets.symmetric(horizontal: 40.0).copyWith(bottom: 25.0, top: 15.0),
                child: ElevatedButton(
                  onPressed: isButtonEnabled && !_isProceeding ? _proceedToNotesScreen : null, // Call navigation method
                  style: ElevatedButton.styleFrom( backgroundColor: isButtonEnabled ? currentTheme.cardColor : currentTheme.cardColor.withOpacity(0.3), foregroundColor: isButtonEnabled ? colorScheme.primary : colorScheme.primary.withOpacity(0.5), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15)), elevation: isButtonEnabled ? 3 : 0, ),
                  child: _isProceeding ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)) : const Text( "CONTINUE", style: TextStyle( fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8 ), ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom) // Padding for gesture bar
            ],
          ),
        ),
      ),
    );
  }

  // --- Build Helpers ---
  // Helper for Top Bar Buttons
  Widget _buildTopBarButton({ required BuildContext context, required IconData icon, required String tooltip, required Color iconColor, required VoidCallback onPressed, }) { /* ... Same as previous ... */ final Color buttonBg = Colors.transparent.withOpacity(0.03); return Material( color: buttonBg, type: MaterialType.button, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: IconButton( icon: Icon(icon, color: iconColor.withOpacity(0.2), size: 20), tooltip: tooltip, onPressed: onPressed, padding: const EdgeInsets.all(10), constraints: const BoxConstraints(), splashRadius: 22, ), ); }

  // Helper: Builds single Feeling Item (Similar to Activity Item)
  Widget _buildFeelingItem({ required BuildContext context, required IconData icon, required String label, required bool isSelected, required VoidCallback onTap, }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color defaultItemColor = theme.colorScheme.onPrimary.withOpacity(0.9);
    final Color selectedItemColor = colorScheme.primary;
    final Color selectedBgColor = theme.cardColor;
    bool isOtherButton = (label == 'other');

    return GestureDetector( onTap: onTap,
      child: Container( padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(15.0),
          border: isOtherButton && !isSelected ? Border.all(color: defaultItemColor.withOpacity(0.5), width: 1.5,) : null, // Dashed/different border for 'other'
          boxShadow: isSelected ? [ BoxShadow( color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3), ) ] : [],
        ),
        child: Column( mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon( icon, size: 32, color: isSelected ? selectedItemColor : defaultItemColor, ),
          const SizedBox(height: 8),
          Text( label, textAlign: TextAlign.center, style: TextStyle( fontSize: 11, color: isSelected ? selectedItemColor : defaultItemColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, ), maxLines: 1, overflow: TextOverflow.ellipsis, ),
        ], ), ), );
  }

} // End _MoodCheckinScreen3State
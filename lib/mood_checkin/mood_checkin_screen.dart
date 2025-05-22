import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // For theme access
import 'package:lottie/lottie.dart'; // For Lottie animation
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Only needed if fetching username from here
import 'package:intl/intl.dart'; // For date formatting
import 'dart:io'; // If needed later
import 'package:table_calendar/table_calendar.dart'; // For Date Picker Modal
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart'; // For Time Picker Modal

// Import theme files
import '../theme/theme_provider.dart'; // For AppThemeType if needed directly

// Screen imports
import 'mood_checkin_screen2.dart'; // Import the next screen

class MoodCheckinScreen extends StatefulWidget {
  const MoodCheckinScreen({Key? key}) : super(key: key);

  @override
  State<MoodCheckinScreen> createState() => _MoodCheckinScreenState();
}

class _MoodCheckinScreenState extends State<MoodCheckinScreen> {
  // --- State Variables ---
  double _sliderValue = 2.0; // Default to index 2 ("Completely Okay")
  int _moodIndex = 2;
  // bool _isSaving = false; // Not saving here
  String? _userName;
  bool _isLoadingName = true;
  bool _sliderInteracted = false; // Track if slider has been moved
  DateTime _entryDateTime = DateTime.now(); // Stores selected date & time

  // --- Mood data & Assets ---
  final List<String> _moodLabels = const [ "Really Terrible", "Somewhat Bad", "Completely Okay", "Pretty Good", "Super Awesome", ];
  // Placeholder Icons (Replace with your Lottie logic or image assets)
  final List<IconData> _moodIcons = const [ Icons.sentiment_very_dissatisfied, Icons.sentiment_dissatisfied, Icons.sentiment_neutral, Icons.sentiment_satisfied, Icons.sentiment_very_satisfied, ];
  final String _lottieLogoAsset = 'assets/animation.json';

  // --- Firebase (only Auth needed if name comes from Auth profile) ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Keep if fetching name
  User? _currentUser;
  // --- End State & Data ---

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserName();
    _moodIndex = _sliderValue.round().clamp(0, _moodLabels.length - 1);
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Fetch User Name (from Firestore - adapt if using Auth display name)
  Future<void> _fetchUserName() async {
    if (!mounted) return;
    setState(() { _isLoadingName = true; });
    if (_currentUser == null) {
      if (mounted) setState(() { _userName = "Friend"; _isLoadingName = false; });
      return;
    }
    // Example: Fetch from Firestore
    try {
      final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        setState(() {
          if (doc.exists && (doc.data() as Map).containsKey('name')) {
            _userName = (doc.data() as Map)['name'];
          } else {
            _userName = _currentUser?.displayName ?? "Friend"; // Fallback to Auth display name or default
          }
          _isLoadingName = false;
        });
      }
    } catch (e) {
      print("Error fetching username: $e");
      if (mounted) {
        setState(() { _userName = _currentUser?.displayName ?? "Friend"; _isLoadingName = false; });
      }
    }
  }

  // Date & Time Picker Logic (Shows Bottom Sheet)
  Future<void> _showDateTimePickerSheet() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Gradient sheetGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.7);
    DateTime? tempSelectedDate = _entryDateTime;
    TimeOfDay? tempSelectedTime = TimeOfDay.fromDateTime(_entryDateTime);
    DateTime focusedDay = _entryDateTime;

    final DateTime? result = await showModalBottomSheet<DateTime>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder( borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)), ),
      builder: (ctx) {
        return StatefulBuilder( builder: (BuildContext context, StateSetter setSheetState) {
          DateTime currentSelection = DateTime( tempSelectedDate!.year, tempSelectedDate!.month, tempSelectedDate!.day, tempSelectedTime!.hour, tempSelectedTime!.minute );
          final theme = Theme.of(context);
          return Container( decoration: BoxDecoration( gradient: sheetGradient, borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)), ), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0), child: SingleChildScrollView( child: Column( mainAxisSize: MainAxisSize.min, children: [
            Container( padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), decoration: BoxDecoration( color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30), ), child: Text( DateFormat('MMM d – hh:mm a').format(currentSelection), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: onGradientColor), ), ),
            const SizedBox(height: 20),
            TableCalendar( firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.now().add(const Duration(days: 1)), focusedDay: focusedDay, selectedDayPredicate: (day) => isSameDay(tempSelectedDate, day), onDaySelected: (selectedDay, newFocusedDay) { if (!isSameDay(tempSelectedDate, selectedDay)) { setSheetState(() { tempSelectedDate = selectedDay; focusedDay = newFocusedDay; }); } }, calendarFormat: CalendarFormat.month, headerStyle: HeaderStyle( formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onGradientColor), leftChevronIcon: Icon(Icons.chevron_left, color: onGradientColor.withOpacity(0.8)), rightChevronIcon: Icon(Icons.chevron_right, color: onGradientColor.withOpacity(0.8)), ), calendarStyle: CalendarStyle( selectedDecoration: BoxDecoration( color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0,2))]), selectedTextStyle: TextStyle(color: themeProvider.currentAccentColor, fontWeight: FontWeight.bold), todayDecoration: BoxDecoration( border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5), shape: BoxShape.circle, ), todayTextStyle: TextStyle(color: onGradientColor), defaultTextStyle: TextStyle(color: onGradientColor), weekendTextStyle: TextStyle(color: onGradientColor.withOpacity(0.8)), outsideTextStyle: TextStyle(color: onGradientColor.withOpacity(0.4)), ), daysOfWeekStyle: DaysOfWeekStyle( weekdayStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12), weekendStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12), ), availableGestures: AvailableGestures.horizontalSwipe, ),
            Divider(height: 25, color: onGradientColor.withOpacity(0.2)),
            Text("Select Time", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onGradientColor)),
            const SizedBox(height: 10),
            TimePickerSpinner( is24HourMode: false, time: _entryDateTime, normalTextStyle: TextStyle(fontSize: 18, color: onGradientMutedColor), highlightedTextStyle: TextStyle(fontSize: 22, color: onGradientColor, fontWeight: FontWeight.bold), spacing: 40, itemHeight: 40, isForce2Digits: true, onTimeChange: (time) { setSheetState(() { tempSelectedTime = TimeOfDay.fromDateTime(time); }); }, ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.05), // Dynamic space
            Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [ IconButton( icon: const Icon(Icons.close), iconSize: 30, color: onGradientMutedColor, onPressed: () => Navigator.pop(context), tooltip: "Cancel", ), IconButton( icon: const Icon(Icons.check_circle), iconSize: 35, color: onGradientColor, onPressed: () { final finalDateTime = DateTime( tempSelectedDate!.year, tempSelectedDate!.month, tempSelectedDate!.day, tempSelectedTime!.hour, tempSelectedTime!.minute ); Navigator.pop(context, finalDateTime); }, tooltip: "Confirm", ), ], ),
            const SizedBox(height: 10),
          ], ), ), ); }, ); }, );
    if (result != null && mounted) { setState(() { _entryDateTime = result; }); print("Selected Entry DateTime: $_entryDateTime"); }
  }

  // Navigate to Next Step (Activity Selection)
  void _proceedToActivities() {
    if (!_sliderInteracted) return; // Only proceed if slider was moved

    final selectedMoodLabel = _moodLabels[_moodIndex];
    final selectedMoodIndex = _moodIndex;
    final selectedDateTime = _entryDateTime; // Use the potentially updated state

    print("Proceeding to Activities - Mood: $selectedMoodLabel ($selectedMoodIndex), Time: $selectedDateTime");

    // Navigate to the next screen, passing the collected data
    Navigator.push( context, CupertinoPageRoute(builder: (_) => MoodCheckinScreen2( moodLabel: selectedMoodLabel, moodIndex: selectedMoodIndex, entryDateTime: selectedDateTime, )), );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    bool isButtonEnabled = _sliderInteracted;

    SystemChrome.setSystemUIOverlayStyle( ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark );

    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea( bottom: false,
          child: Column(
            children: [
              // --- Top Bar with Correct Buttons and Size ---
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 16.0, top: 10.0), // Adjusted left padding
                child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Button (Date/Time Picker)
                    _buildTopBarButton( context: context, icon: Icons.calendar_today_outlined, tooltip: "Change Date/Time", iconColor: onGradientColor,
                      onPressed: _showDateTimePickerSheet, // CORRECTED: Call the sheet function
                    ),
                    // Center Lottie (Larger Size)
                    SizedBox( height: 125, width: 125,
                      child: Lottie.asset(_lottieLogoAsset, fit: BoxFit.contain), ),
                    // Right Close Button
                    _buildTopBarButton( context: context, icon: Icons.close, tooltip: "Close", iconColor: onGradientColor, onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); }, ),
                  ],
                ),
              ),
              // Display Selected Date/Time Below Buttons
              Padding( padding: const EdgeInsets.only(top: 4.0), child: Text( DateFormat('MMM d, hh:mm a').format(_entryDateTime), style: TextStyle(color: onGradientColor.withOpacity(0.8), fontSize: 12), ), ),
              // --- End Top Bar ---

              const SizedBox(height: 20),
              Padding( padding: const EdgeInsets.symmetric(horizontal: 40.0), child: AnimatedSwitcher( duration: const Duration(milliseconds: 300), child: Text( _isLoadingName ? "How are you doing right now?" : "Alrighty, ${_userName ?? 'Friend'} - how are you doing right now?", key: ValueKey(_isLoadingName), textAlign: TextAlign.center, style: const TextStyle( fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white, height: 1.4 ), ), ) ),
              const Spacer(flex: 2),

              // Face Expression Placeholder
              AnimatedSwitcher( duration: const Duration(milliseconds: 200), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
                child: Icon( _moodIcons[_moodIndex], key: ValueKey<int>(_moodIndex), size: 130, color: Colors.white.withOpacity(0.95), semanticLabel: _moodLabels[_moodIndex], ),
              ),
              const SizedBox(height: 15),

              // Mood Label
              AnimatedSwitcher( duration: const Duration(milliseconds: 200), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: Text( _moodLabels[_moodIndex].toUpperCase(), key: ValueKey<String>(_moodLabels[_moodIndex]), style: const TextStyle( fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1 ), ), ),
              const SizedBox(height: 40),

              // Slider
              Padding( padding: const EdgeInsets.symmetric(horizontal: 40.0), child: SliderTheme( data: SliderTheme.of(context).copyWith( activeTrackColor: Colors.white, inactiveTrackColor: Colors.white.withOpacity(0.3), thumbColor: Colors.white, overlayColor: colorScheme.onPrimary.withOpacity(0.2), trackHeight: 4.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0), ), child: Slider( value: _sliderValue, min: 0.0, max: (_moodLabels.length - 1).toDouble(), divisions: _moodLabels.length - 1,
                onChanged: (newValue) { if (mounted) { setState(() { _sliderValue = newValue; _moodIndex = newValue.round().clamp(0, _moodLabels.length - 1); if (!_sliderInteracted) { _sliderInteracted = true; } }); } }, ), ), ),
              const Spacer(flex: 3),

              // Continue Button
              Padding( padding: const EdgeInsets.symmetric(horizontal: 40.0).copyWith(bottom: 30.0),
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? _proceedToActivities : null, // Navigate, don't save
                  style: ElevatedButton.styleFrom( backgroundColor: isButtonEnabled ? Colors.white : Colors.white.withOpacity(0.3), foregroundColor: isButtonEnabled ? colorScheme.primary : colorScheme.primary.withOpacity(0.5), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15)), elevation: isButtonEnabled ? 3 : 0, ),
                  // No loading indicator needed here anymore
                  child: const Text( "CONTINUE", style: TextStyle( fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8 ), ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom)
            ],
          ),
        ),
      ),
    );
  }


  // Helper for Top Bar Buttons (Darker Background)
  Widget _buildTopBarButton({ required BuildContext context, required IconData icon, required String tooltip, required Color iconColor, required VoidCallback onPressed, }) {
    final Color buttonBg = Colors.black.withOpacity(0.03); // Darker semi-transparent BG
    return Material( color: buttonBg, type: MaterialType.button, shape: const CircleBorder(), clipBehavior: Clip.antiAlias,
      child: IconButton( icon: Icon(icon, color: iconColor.withOpacity(0.2), size: 20), tooltip: tooltip, onPressed: onPressed, padding: const EdgeInsets.all(10), constraints: const BoxConstraints(), splashRadius: 22, ), );
  }

} // End _MoodCheckinScreenState
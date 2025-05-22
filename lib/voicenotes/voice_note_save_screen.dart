// lib/voice_note_save_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // For ImageFilter if using blur later

// Import theme files
import '../theme/theme_provider.dart';

// Import for Date/Time Picker Modal
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';

// Import Main Shell for navigation back
import '../main_navigation_shell.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
// --- End Constants ---

class VoiceNoteSaveScreen extends StatefulWidget {
  final String transcribedText;
  final DateTime entryDateTime; // Received from recording screen

  const VoiceNoteSaveScreen({
    Key? key,
    required this.transcribedText,
    required this.entryDateTime,
  }) : super(key: key);

  @override
  State<VoiceNoteSaveScreen> createState() => _VoiceNoteSaveScreenState();
}

class _VoiceNoteSaveScreenState extends State<VoiceNoteSaveScreen> {
  // State
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime _currentEntryDateTime; // State to hold/modify date & time
  bool _isSaving = false;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _notesFocusNode = FocusNode();
  bool _isKeyboardVisible = false;

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _titleController = TextEditingController();
    _notesController = TextEditingController(text: widget.transcribedText); // Pre-fill notes
    _currentEntryDateTime = widget.entryDateTime; // Initialize with passed value
    _titleFocusNode.addListener(_onFocusChange);
    _notesFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocusNode.removeListener(_onFocusChange);
    _notesFocusNode.removeListener(_onFocusChange);
    _titleFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  // Keyboard Visibility Handler
  void _onFocusChange() { if (!mounted) return; bool keyboardVisible = _titleFocusNode.hasFocus || _notesFocusNode.hasFocus; if (_isKeyboardVisible != keyboardVisible) { setState(() { _isKeyboardVisible = keyboardVisible; }); } }

  // --- Final Save Logic ---
  Future<void> _saveFinalVoiceNote() async {
    if (_isSaving || _currentUser == null) return;
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    final String title = _titleController.text.trim();
    final String notes = _notesController.text.trim();

    if (notes.isEmpty) { // Check if notes are empty (transcription might have failed silently)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot save an empty note.")));
      return;
    }
    setState(() { _isSaving = true; });

    final dataToSave = {
      'title': title.isEmpty ? null : title,
      'text': notes, // Save the final (potentially edited) text
      'entryDateTime': Timestamp.fromDate(_currentEntryDateTime), // Save current state date/time
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      print("Saving Final Voice Note: $dataToSave");
      await _firestore.collection('users').doc(_currentUser!.uid).collection('voice_notes').add(dataToSave);
      print("Voice Note Saved Successfully!");
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
              (Route<dynamic> route) => false, // Go back to Shell, remove intermediate screens
        );
      }
    } catch (e) {
      print("Error saving final voice note: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not save note: ${e.toString()}"))); setState(() { _isSaving = false; }); }
    }
  }
  // --- End Save Logic ---

  // --- Date & Time Picker Logic (Shows Bottom Sheet) ---
  Future<void> _showDateTimePickerSheet() async {
    // Uses the same logic as MoodCheckinScreen's picker
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Gradient sheetGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.7);
    DateTime? tempSelectedDate = _currentEntryDateTime;
    TimeOfDay? tempSelectedTime = TimeOfDay.fromDateTime(_currentEntryDateTime);
    DateTime focusedDay = _currentEntryDateTime;

    final DateTime? result = await showModalBottomSheet<DateTime>( context: context, isScrollControlled: true, backgroundColor: Colors.transparent, shape: const RoundedRectangleBorder( borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)), ), builder: (ctx) { return StatefulBuilder( builder: (BuildContext context, StateSetter setSheetState) { DateTime currentSelection = DateTime( tempSelectedDate!.year, tempSelectedDate!.month, tempSelectedDate!.day, tempSelectedTime!.hour, tempSelectedTime!.minute ); final theme = Theme.of(context); return Container( decoration: BoxDecoration( gradient: sheetGradient, borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)), ), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0), child: SingleChildScrollView( child: Column( mainAxisSize: MainAxisSize.min, children: [ Container( padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), decoration: BoxDecoration( color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30), ), child: Text( DateFormat('MMM d – hh:mm a').format(currentSelection), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: onGradientColor, fontFamily: _primaryFontFamily), ), ), const SizedBox(height: 20), TableCalendar( firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.now().add(const Duration(days: 1)), focusedDay: focusedDay, selectedDayPredicate: (day) => isSameDay(tempSelectedDate, day), onDaySelected: (selectedDay, newFocusedDay) { if (!isSameDay(tempSelectedDate, selectedDay)) { setSheetState(() { tempSelectedDate = selectedDay; focusedDay = newFocusedDay; }); } }, calendarFormat: CalendarFormat.month, headerStyle: HeaderStyle( formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onGradientColor, fontFamily: _primaryFontFamily), leftChevronIcon: Icon(Icons.chevron_left, color: onGradientColor.withOpacity(0.8)), rightChevronIcon: Icon(Icons.chevron_right, color: onGradientColor.withOpacity(0.8)), ), calendarStyle: CalendarStyle( selectedDecoration: BoxDecoration( color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0,2))]), selectedTextStyle: TextStyle(color: themeProvider.currentAccentColor, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily), todayDecoration: BoxDecoration( border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5), shape: BoxShape.circle, ), todayTextStyle: TextStyle(color: onGradientColor, fontFamily: _primaryFontFamily), defaultTextStyle: TextStyle(color: onGradientColor, fontFamily: _primaryFontFamily), weekendTextStyle: TextStyle(color: onGradientColor.withOpacity(0.8), fontFamily: _primaryFontFamily), outsideTextStyle: TextStyle(color: onGradientColor.withOpacity(0.4), fontFamily: _primaryFontFamily), ), daysOfWeekStyle: DaysOfWeekStyle( weekdayStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12, fontFamily: _primaryFontFamily), weekendStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12, fontFamily: _primaryFontFamily), ), availableGestures: AvailableGestures.horizontalSwipe, ), Divider(height: 25, color: onGradientColor.withOpacity(0.2)), Text("Select Time", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onGradientColor, fontFamily: _primaryFontFamily)), const SizedBox(height: 10), TimePickerSpinner( is24HourMode: false, time: _currentEntryDateTime, normalTextStyle: TextStyle(fontSize: 18, color: onGradientMutedColor, fontFamily: _primaryFontFamily), highlightedTextStyle: TextStyle(fontSize: 22, color: onGradientColor, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily), spacing: 40, itemHeight: 40, isForce2Digits: true, onTimeChange: (time) { setSheetState(() { tempSelectedTime = TimeOfDay.fromDateTime(time); }); }, ), SizedBox(height: MediaQuery.of(context).size.height * 0.05), Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [ IconButton( icon: const Icon(Icons.close), iconSize: 30, color: onGradientMutedColor, onPressed: () => Navigator.pop(context), tooltip: "Cancel", ), IconButton( icon: const Icon(Icons.check_circle), iconSize: 35, color: onGradientColor, onPressed: () { final finalDateTime = DateTime( tempSelectedDate!.year, tempSelectedDate!.month, tempSelectedDate!.day, tempSelectedTime!.hour, tempSelectedTime!.minute ); Navigator.pop(context, finalDateTime); }, tooltip: "Confirm", ), ], ), const SizedBox(height: 10), ], ), ), ); }, ); }, );
    if (result != null && mounted) { setState(() { _currentEntryDateTime = result; }); print("Selected Entry DateTime for Voice Note: $_currentEntryDateTime"); }
  }
  // --- End Combined Date Time Picker ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.7);

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
                // --- Top Bar (Back, Centered Date/Time Button, Close) ---
                Padding( padding: const EdgeInsets.only(left: 8.0, right: 16.0, top: 15.0, bottom: 15.0),
                  child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                    _buildTopBarButton( context: context, icon: Icons.arrow_back_ios_new, tooltip: "Back", iconColor: onGradientColor, onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); }, ),
                    // --- Date/Time Button with Icon Behind ---
                    InkWell(
                      onTap: _showDateTimePickerSheet,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Faint Icon Behind
                          Icon( Icons.calendar_today_outlined, color: onGradientColor.withOpacity(0.15), size: 50, ),
                          // Positioned Text on Top
                          Transform.translate(
                            offset: const Offset(0, 0), // Adjust vertical offset if needed
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4.0), // Adjust padding
                              child: Text(
                                DateFormat('MMM d, hh:mm a').format(_currentEntryDateTime),
                                style: TextStyle(color: onGradientColor, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: _primaryFontFamily),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // --- End Date/Time Button ---
                    _buildTopBarButton( context: context, icon: Icons.close, tooltip: "Cancel", iconColor: onGradientColor, onPressed: () { int popCount = 0; Navigator.of(context).popUntil((route) => popCount++ >= 2 || !Navigator.of(context).canPop()); }, ), // Pop 2 screens
                  ], ), ),

                // --- Scrollable Content Area ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40), // Space after top bar elements
                          // Title Input
                          TextField( focusNode: _titleFocusNode, controller: _titleController, style: TextStyle(color: onGradientColor, fontSize: 21, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily), textCapitalization: TextCapitalization.sentences, decoration: InputDecoration( hintText: "Title (Optional)", hintStyle: TextStyle(color: onGradientMutedColor, fontSize: 21, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily), enabledBorder: UnderlineInputBorder( borderSide: BorderSide(color: onGradientColor.withOpacity(0.3)), ), focusedBorder: UnderlineInputBorder( borderSide: BorderSide(color: onGradientColor, width: 1.5), ), ), ),
                          const SizedBox(height: 30),
                          // Notes Input (Transcribed Text)
                          TextFormField( focusNode: _notesFocusNode, controller: _notesController, style: TextStyle(color: onGradientColor, fontSize: 18, height: 1.5, fontFamily: _primaryFontFamily), textCapitalization: TextCapitalization.sentences, maxLines: 12, minLines: 6, // Adjusted lines
                            decoration: InputDecoration( hintText: "Your voice note...", hintStyle: TextStyle(color: onGradientMutedColor, fontSize: 18, fontFamily: _primaryFontFamily), fillColor: onGradientColor.withOpacity(0.08), filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), border: OutlineInputBorder( borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none ), ), ),
                          const SizedBox(height: 30),
                        ]
                    ),
                  ),
                ),
                // --- End Scrollable Area ---

                // --- Bottom Button Area (Conditional Visibility) ---
                Padding( padding: EdgeInsets.only( left: 40.0, right: 40.0, top: 15.0, bottom: _isKeyboardVisible ? MediaQuery.of(context).viewInsets.bottom + 15.0 : MediaQuery.of(context).padding.bottom + 25.0, ),
                  child: AnimatedSwitcher( duration: const Duration(milliseconds: 200),
                    child: _isKeyboardVisible
                        ? Align( alignment: Alignment.centerRight, key: const ValueKey('done_button_save_screen'), child: FloatingActionButton.small( onPressed: () => FocusScope.of(context).unfocus(), backgroundColor: currentTheme.cardColor, foregroundColor: colorScheme.primary, elevation: 4.0, tooltip: 'Done Editing', child: const Icon(Icons.check, size: 24), ), )
                        : SizedBox( key: const ValueKey('save_note_button'), width: double.infinity, height: 60,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveFinalVoiceNote,
                        style: ElevatedButton.styleFrom( backgroundColor: currentTheme.cardColor, foregroundColor: colorScheme.primary, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15)), elevation: 3, ),
                        child: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2,)) : const Text( "SAVE NOTE", style: TextStyle( fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.8, fontFamily: _primaryFontFamily ), ),
                      ), ), ), ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // --- Build Helpers ---
  // Helper for Top Bar Buttons
  Widget _buildTopBarButton({ required BuildContext context, required IconData icon, required String tooltip, required Color iconColor, required VoidCallback onPressed, }) { /* ... Same darker background version ... */ final Color buttonBg = Colors.transparent.withOpacity(0.03); return Material( color: buttonBg, type: MaterialType.button, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: IconButton( icon: Icon(icon, color: iconColor.withOpacity(0.3), size: 22), tooltip: tooltip, onPressed: onPressed, padding: const EdgeInsets.all(11), constraints: const BoxConstraints(), splashRadius: 24, ), ); }

// NO Chip helpers needed for this screen

} // End _MoodCheckinScreen4State
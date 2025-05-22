// lib/voice_note_recording_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart'; // Only needed if you keep the logo at the top
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';

// Import theme files
import '../theme/theme_provider.dart';

// Import the NEXT screen (Save Screen)
import 'voice_note_save_screen.dart';
// Import Main Shell for navigation back (Cancel button)
import '../main_navigation_shell.dart';


class VoiceNoteRecordingScreen extends StatefulWidget {
  final DateTime? initialEntryDateTime;

  const VoiceNoteRecordingScreen({Key? key, this.initialEntryDateTime}) : super(key: key);

  @override
  State<VoiceNoteRecordingScreen> createState() => _VoiceNoteRecordingScreenState();
}

class _VoiceNoteRecordingScreenState extends State<VoiceNoteRecordingScreen> {
  // State Variables
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _transcribedText = "";
  // Use more specific status messages based on image
  String _currentStatus = "Initializing speech...";
  bool _speechEnabled = false;
  bool _hasRecordedSomething = false;
  late DateTime _entryDateTime;
  bool _isNavigating = false; // To prevent double navigation

  // Timer related
  final Stopwatch _stopwatch = Stopwatch();
  String _formattedTime = "00:00";
  Stream<int>? _timerStream;
  StreamSubscription<int>? _timerSubscription;

  // Firebase (Not used directly here, but user context might be useful)
  // User? _currentUser;

  @override
  void initState() {
    super.initState();
    // _currentUser = FirebaseAuth.instance.currentUser;
    _entryDateTime = widget.initialEntryDateTime ?? DateTime.now();
    _speech = stt.SpeechToText();
    _initializeSpeechAndStartListening();
  }

  @override
  void dispose() {
    _speech.stop();
    _stopTimer();
    super.dispose();
  }

  // --- Speech and Timer Logic (Keep as before, including corrected _onSpeechError) ---
  Future<void> _initializeSpeechAndStartListening() async { if (!mounted) return; var micStatus = await Permission.microphone.request(); var speechStatus = await Permission.speech.request(); if (micStatus.isGranted && speechStatus.isGranted) { try { bool available = await _speech.initialize( onStatus: _onSpeechStatus,  debugLogging: true, ); if (mounted) { setState(() => _speechEnabled = available); if (available) { _startListening(); } else { _currentStatus = "Speech not available."; } } } catch (e) { if (mounted) setState(() { _speechEnabled = false; _currentStatus = "Could not init speech."; }); } } else { if (mounted) setState(() { _speechEnabled = false; _currentStatus = "Permissions required."; }); } }
  void _onSpeechStatus(String status) { print('[STT Status]: $status'); if (!mounted) return; setState(() { if (status == 'listening') { _currentStatus = "Start speaking..."; } else if (status == 'notListening') { _isListening = false; if (_hasRecordedSomething && _transcribedText.trim().isNotEmpty) { _currentStatus = "DONE"; } else if (_hasRecordedSomething) { _currentStatus = "No speech detected. Tap mic."; } else { _currentStatus = "Tap mic to record"; } _stopTimer(); } else if (status == 'done') { _isListening = false; _currentStatus = "DONE"; _stopTimer(); } }); }

  void _startListening() { if (!_speechEnabled || _speech.isListening) return; if (mounted) { setState(() { _isListening = true; _hasRecordedSomething = true; _currentStatus = "Listening..."; _transcribedText = ""; }); _startTimer(); _speech.listen( onResult: (val) { if (mounted) setState(() => _transcribedText = val.recognizedWords); }, listenFor: const Duration(minutes: 2), pauseFor: const Duration(seconds: 4), localeId: "en_US", partialResults: true, onDevice: false, ); } }
  void _stopListening() { if (_speech.isListening) { _speech.stop(); print("[STT] Stop listening called by user."); } if (mounted) setState(() => _isListening = false); _stopTimer(); }
  void _startTimer() { _stopwatch.reset(); _stopwatch.start(); _timerSubscription?.cancel(); _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i + 1); _timerSubscription = _timerStream!.listen((sec) { if (mounted) { setState(() { final elapsed = Duration(seconds: sec); _formattedTime = "${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:${elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}"; }); } }); }
  void _stopTimer() { _stopwatch.stop(); _timerSubscription?.cancel(); if(mounted) setState(() { /* Reset timer display? */ _formattedTime="00:00"; }); }
  // --- End Speech/Timer Logic ---

  // Navigate to Save Screen
  void _processAndNavigateToSaveScreen() { /* ... Same as previous (navigates to VoiceNoteSaveScreen) ... */ if (_isNavigating) return; if (_transcribedText.trim().isEmpty && _hasRecordedSomething) { if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No speech was recorded."))); setState(() { _currentStatus = "Tap mic to try again."; _hasRecordedSomething = false; }); } return; } if (!_hasRecordedSomething && _transcribedText.trim().isEmpty) { if(mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tap the microphone to start recording."))); } return; } _isNavigating = true; if (_speech.isListening) { _speech.stop(); } _stopTimer(); print("Proceeding to Save Screen with text: $_transcribedText and time: $_entryDateTime"); Navigator.pushReplacement( context, MaterialPageRoute( builder: (_) => VoiceNoteSaveScreen( transcribedText: _transcribedText.trim(), entryDateTime: _entryDateTime, ), ), ).then((_) => _isNavigating = false ); }

  // Date & Time Picker Logic (Shows Bottom Sheet)
  Future<void> _showDateTimePickerSheet() async { /* ... Same as previous ... */ final themeProvider = Provider.of<ThemeProvider>(context, listen: false); final Gradient sheetGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight); final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87; final Color onGradientMutedColor = onGradientColor.withOpacity(0.7); DateTime? tempSelectedDate = _entryDateTime; TimeOfDay? tempSelectedTime = TimeOfDay.fromDateTime(_entryDateTime); DateTime focusedDay = _entryDateTime; final DateTime? result = await showModalBottomSheet<DateTime>( context: context, isScrollControlled: true, backgroundColor: Colors.transparent, shape: const RoundedRectangleBorder( borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)), ), builder: (ctx) { return StatefulBuilder( builder: (BuildContext context, StateSetter setSheetState) { DateTime currentSelection = DateTime( tempSelectedDate!.year, tempSelectedDate!.month, tempSelectedDate!.day, tempSelectedTime!.hour, tempSelectedTime!.minute ); final theme = Theme.of(context); return Container( decoration: BoxDecoration( gradient: sheetGradient, borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)), ), constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0), child: SingleChildScrollView( child: Column( mainAxisSize: MainAxisSize.min, children: [ Container( padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), decoration: BoxDecoration( color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30), ), child: Text( DateFormat('MMM d – hh:mm a').format(currentSelection), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: onGradientColor), ), ), const SizedBox(height: 20), TableCalendar( firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.now().add(const Duration(days: 1)), focusedDay: focusedDay, selectedDayPredicate: (day) => isSameDay(tempSelectedDate, day), onDaySelected: (selectedDay, newFocusedDay) { if (!isSameDay(tempSelectedDate, selectedDay)) { setSheetState(() { tempSelectedDate = selectedDay; focusedDay = newFocusedDay; }); } }, calendarFormat: CalendarFormat.month, headerStyle: HeaderStyle( formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onGradientColor), leftChevronIcon: Icon(Icons.chevron_left, color: onGradientColor.withOpacity(0.8)), rightChevronIcon: Icon(Icons.chevron_right, color: onGradientColor.withOpacity(0.8)), ), calendarStyle: CalendarStyle( selectedDecoration: BoxDecoration( color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0,2))]), selectedTextStyle: TextStyle(color: themeProvider.currentAccentColor, fontWeight: FontWeight.bold), todayDecoration: BoxDecoration( border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5), shape: BoxShape.circle, ), todayTextStyle: TextStyle(color: onGradientColor), defaultTextStyle: TextStyle(color: onGradientColor), weekendTextStyle: TextStyle(color: onGradientColor.withOpacity(0.8)), outsideTextStyle: TextStyle(color: onGradientColor.withOpacity(0.4)), ), daysOfWeekStyle: DaysOfWeekStyle( weekdayStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12), weekendStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12), ), availableGestures: AvailableGestures.horizontalSwipe, ), Divider(height: 25, color: onGradientColor.withOpacity(0.2)), Text("Select Time", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onGradientColor)), const SizedBox(height: 10), TimePickerSpinner( is24HourMode: false, time: _entryDateTime, normalTextStyle: TextStyle(fontSize: 18, color: onGradientMutedColor), highlightedTextStyle: TextStyle(fontSize: 22, color: onGradientColor, fontWeight: FontWeight.bold), spacing: 40, itemHeight: 40, isForce2Digits: true, onTimeChange: (time) { setSheetState(() { tempSelectedTime = TimeOfDay.fromDateTime(time); }); }, ), SizedBox(height: MediaQuery.of(context).size.height * 0.05), Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [ IconButton( icon: const Icon(Icons.close), iconSize: 30, color: onGradientMutedColor, onPressed: () => Navigator.pop(context), tooltip: "Cancel", ), IconButton( icon: const Icon(Icons.check_circle), iconSize: 35, color: onGradientColor, onPressed: () { final finalDateTime = DateTime( tempSelectedDate!.year, tempSelectedDate!.month, tempSelectedDate!.day, tempSelectedTime!.hour, tempSelectedTime!.minute ); Navigator.pop(context, finalDateTime); }, tooltip: "Confirm", ), ], ), const SizedBox(height: 10), ], ), ), ); }, ); }, ); if (result != null && mounted) { setState(() { _entryDateTime = result; }); } }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.7);
    bool showDoneButton = _hasRecordedSomething && !_isListening; // Show DONE when paused/stopped after recording

    SystemChrome.setSystemUIOverlayStyle( ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark );

    return Scaffold(
      // NOTE: No AppBar needed as per image for recording screen
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea( bottom: false,
          child: Column(
            children: [
              // --- Top Bar (Only Close Button and Optional DateTime) ---
              Padding( padding: const EdgeInsets.only(left: 8.0, right: 16.0, top: 15.0, bottom: 8.0),
                child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Date/Time Picker Button (Keep for consistency?)
                  _buildTopBarButton( context: context, icon: Icons.calendar_today_outlined, tooltip: "Set Date/Time", iconColor: onGradientColor, onPressed: _showDateTimePickerSheet, ),
                  // Add Spacer to push Close button right
                  const Spacer(),
                  _buildTopBarButton( context: context, icon: Icons.close, tooltip: "Cancel", iconColor: onGradientColor, onPressed: () { if (_speech.isListening) _speech.cancel(); if (Navigator.canPop(context)) Navigator.pop(context); }, ),
                ], ), ),
              // Optional: Display Selected Date/Time? Image doesn't show it clearly here.
              // Padding( padding: const EdgeInsets.only(top: 0, bottom: 15.0), child: Text( DateFormat('MMM d, hh:mm a').format(_entryDateTime), style: TextStyle(color: onGradientColor.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Nunito'), ), ),

              // --- Central Area for Text/Prompt ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                    children: [
                      if (_transcribedText.isNotEmpty || _isListening) // Show text if available OR listening
                        SingleChildScrollView( // Allow scrolling if text gets long
                          reverse: true,
                          child: Text(
                            _transcribedText.isEmpty && _isListening ? _currentStatus : _transcribedText, // Show status or text
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, color: Colors.white, height: 1.4, fontFamily: 'Nunito', fontWeight: FontWeight.bold),
                          ),
                        )
                      else // Show initial prompt if no text and not listening
                        Text(
                          _currentStatus, // e.g., "Tap mic to start..."
                          style: TextStyle(fontSize: 22, color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.bold,),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),

              // --- Recording Timer and Button Area ---
              if (_isListening) // Only show timer when listening
                Text( _formattedTime, style: TextStyle(fontSize: 16, color: onGradientColor.withOpacity(0.8), fontFamily: 'Nunito'), ),
              const SizedBox(height: 20),

              // Microphone/Pause/Stop Button
              GestureDetector(
                onTap: _speechEnabled ? (_isListening ? _stopListening : _startListening) : null,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration( shape: BoxShape.circle, color: Colors.white.withOpacity(_speechEnabled ? 0.95 : 0.5),
                    boxShadow: _isListening ? [ // Glow effect
                      BoxShadow( color: Colors.white.withOpacity(0.5), blurRadius: 20, spreadRadius: 5, ),
                      BoxShadow( color: Colors.white.withOpacity(0.3), blurRadius: 40, spreadRadius: 10, )
                    ] : [ BoxShadow( color: Colors.black.withOpacity(0.15), blurRadius: 10, spreadRadius: 3, offset: const Offset(0, 5)) ], ),
                  child: Icon(
                    _isListening ? Icons.pause_rounded : Icons.mic_none_rounded, // Mic or Pause icon
                    color: _speechEnabled ? colorScheme.primary : Colors.grey.shade400, size: 45, ),
                ),
              ),
              const SizedBox(height: 35),

              // "DONE" Button / Status Text below Mic Button
              SizedBox( // Reserve space for the button/text
                height: 40,
                child: TextButton(
                  onPressed: showDoneButton ? _processAndNavigateToSaveScreen : null, // Enable only when DONE state
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    // Make background transparent unless it's DONE? Or keep always transparent
                    // backgroundColor: showDoneButton ? Colors.white.withOpacity(0.2) : Colors.transparent,
                  ),
                  child: Text(
                    showDoneButton ? "DONE" : "", // Only show DONE text when appropriate
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Nunito',
                      color: showDoneButton ? onGradientColor.withOpacity(0.95) : Colors.transparent, // Show or hide text
                      letterSpacing: 0.8, ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 40), // Space for gesture bar
            ],
          ),
        ),
      ),
    );
  }

  // Helper for Top Bar Buttons
  Widget _buildTopBarButton({ required BuildContext context, required IconData icon, required String tooltip, required Color iconColor, required VoidCallback onPressed, }) { /* ... Same dark background version ... */ final Color buttonBg = Colors.transparent.withOpacity(0.03); return Material( color: buttonBg, type: MaterialType.button, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: IconButton( icon: Icon(icon, color: iconColor.withOpacity(0.3), size: 22), tooltip: tooltip, onPressed: onPressed, padding: const EdgeInsets.all(11), constraints: const BoxConstraints(), splashRadius: 24, ), ); }

} // End _VoiceNoteRecordingScreenState
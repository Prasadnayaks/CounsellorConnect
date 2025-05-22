// lib/settings_screen.dart
import 'package:counsellorconnect/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart'; // Ensure this is your correct path

const String _primaryFontFamily = 'Nunito';
const double _settingsCardRadius = 16.0;
final Color _dangerColor = Colors.red.shade600;

// SharedPreferences Keys
const String _checkInReminderEnabledKey = 'checkInReminderEnabled';
const String _checkInTimeHourKey = 'checkInTimeHour';
const String _checkInTimeMinuteKey = 'checkInTimeMinute';

const String _positivityReminderEnabledKey = 'positivityReminderEnabled';
const String _positivityStartTimeHourKey = 'positivityStartTimeHour';
const String _positivityStartTimeMinuteKey = 'positivityStartTimeMinute';
const String _positivityEndTimeHourKey = 'positivityEndTimeHour';
const String _positivityEndTimeMinuteKey = 'positivityEndTimeMinute';
// const String _positivityFrequencyKey = 'positivityFrequency'; // We are doing half-hourly now

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPasscodeEnabled = false;
  bool _areCheckInRemindersEnabled = false;
  TimeOfDay _checkInTime = const TimeOfDay(hour: 20, minute: 0);
  bool _arePositivityRemindersEnabled = false;
  TimeOfDay _positivityStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _positivityEndTime = const TimeOfDay(hour: 21, minute: 0);
  // int _positivityFrequency = 5; // Removed, now half-hourly

  String? _userName;
  String? _userEmail;
  String? _photoUrl;
  bool _isLoadingUserInfo = true;
  String _errorMessage = '';
  bool _hasSettingsChanged = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _loadReminderSettings();
  }

  Future<void> _fetchUserInfo() async { /* ... No change from your previous version ... */ if (!mounted) return; setState(() { _isLoadingUserInfo = true; _errorMessage = ''; _photoUrl = null; }); final user = _auth.currentUser; if (user != null) { _userEmail = user.email; _userName = user.displayName; try { final doc = await _firestore.collection('users').doc(user.uid).get(); if (doc.exists && doc.data() != null) { final data = doc.data() as Map<String, dynamic>; if (_userName == null || _userName!.isEmpty) { _userName = data['name'] as String?; } _photoUrl = data['photoUrl'] as String?; } else { if (_userName == null) _userName = "User"; _photoUrl = null; } } catch(e) { print("Error fetching Firestore details: $e"); if (_userName == null) _userName = "User"; _photoUrl = null; } } else { _userName = "Guest"; _userEmail = null; _photoUrl = null; } if (mounted) { setState(() { _isLoadingUserInfo = false; }); } }

  Future<void> _loadReminderSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _areCheckInRemindersEnabled = prefs.getBool(_checkInReminderEnabledKey) ?? false;
      _checkInTime = TimeOfDay(
        hour: prefs.getInt(_checkInTimeHourKey) ?? 20,
        minute: prefs.getInt(_checkInTimeMinuteKey) ?? 0,
      );
      _arePositivityRemindersEnabled = prefs.getBool(_positivityReminderEnabledKey) ?? false;
      _positivityStartTime = TimeOfDay(
        hour: prefs.getInt(_positivityStartTimeHourKey) ?? 9,
        minute: prefs.getInt(_positivityStartTimeMinuteKey) ?? 0,
      );
      _positivityEndTime = TimeOfDay(
        hour: prefs.getInt(_positivityEndTimeHourKey) ?? 21,
        minute: prefs.getInt(_positivityEndTimeMinuteKey) ?? 0,
      );
      // _positivityFrequency = prefs.getInt(_positivityFrequencyKey) ?? 5; // Removed
    });
  }

  Future<void> _saveReminderSettingsToPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_checkInReminderEnabledKey, _areCheckInRemindersEnabled);
    await prefs.setInt(_checkInTimeHourKey, _checkInTime.hour);
    await prefs.setInt(_checkInTimeMinuteKey, _checkInTime.minute);
    await prefs.setBool(_positivityReminderEnabledKey, _arePositivityRemindersEnabled);
    await prefs.setInt(_positivityStartTimeHourKey, _positivityStartTime.hour);
    await prefs.setInt(_positivityStartTimeMinuteKey, _positivityStartTime.minute);
    await prefs.setInt(_positivityEndTimeHourKey, _positivityEndTime.hour);
    await prefs.setInt(_positivityEndTimeMinuteKey, _positivityEndTime.minute);
    // await prefs.setInt(_positivityFrequencyKey, _positivityFrequency); // Removed
  }

  void _markSettingsChanged() {
    if (!_hasSettingsChanged && mounted) {
      setState(() => _hasSettingsChanged = true);
    }
  }

  Future<void> _saveSettingsAndScheduleNotifications() async {
    print("Save Changes tapped...");
    setState(() => _hasSettingsChanged = false);

    await _saveReminderSettingsToPrefs();

    await _notificationService.cancelDailyCheckInReminder();
    await _notificationService.cancelPositivityReminders();

    if (_areCheckInRemindersEnabled) {
      await _notificationService.scheduleDailyCheckInReminder(time: _checkInTime);
    }
    if (_arePositivityRemindersEnabled) {
      final startTimeInMinutes = _positivityStartTime.hour * 60 + _positivityStartTime.minute;
      final endTimeInMinutes = _positivityEndTime.hour * 60 + _positivityEndTime.minute;

      if (startTimeInMinutes < endTimeInMinutes) {
        await _notificationService.schedulePositivityReminders(
          startTime: _positivityStartTime,
          endTime: _positivityEndTime,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Positivity Reminder: Start time must be before end time. Reminders not scheduled."))
          );
        }
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reminder settings saved & updated!"), duration: Duration(seconds: 2)));
    }
  }

  Future<void> _signOutUser() async { /* ... same ... */ try { await FirebaseAuth.instance.signOut(); if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const RoleSelectionScreen()), (Route<dynamic> route) => false, ); } } catch (e) { print("Error signing out: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Error signing out: ${e.toString()}")), ); } } }

  Future<void> _selectTime(BuildContext context, TimeOfDay initialTime, ValueChanged<TimeOfDay> onTimeChanged) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Color currentAccent = themeProvider.currentAccentColor;
    final TimeOfDay? picked = await showTimePicker(
      context: context, initialTime: initialTime,
      builder: (context, child) { /* ... same builder ... */ return Theme( data: Theme.of(context).copyWith( colorScheme: Theme.of(context).colorScheme.copyWith( primary: currentAccent, onPrimary: Colors.white, onSurface: Theme.of(context).colorScheme.onSurface ), textButtonTheme: TextButtonThemeData( style: TextButton.styleFrom( foregroundColor: currentAccent, ), ), ), child: child!, ); },
    );
    if (picked != null && picked != initialTime) {
      if (mounted) {
        setState(() { onTimeChanged(picked); _markSettingsChanged(); });
      }
    }
  }

  // Helper for time to double (for sliders, if you re-add them)
  double _timeToDouble(TimeOfDay time) => time.hour * 60.0 + time.minute;
  TimeOfDay _doubleToTime(double value) {
    final int hours = (value / 60).floor() % 24;
    final int minutes = (value % 60).round(); // Use round for better snapping
    return TimeOfDay(hour: hours, minute: minutes);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final List<Color> currentButtonGradient = themeProvider.currentAccentGradient;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTopSection(context, _photoUrl),
              _buildUserInfoCard(),
              const SizedBox(height: 20),
              _buildSettingToggleCard( context: context, title: _isPasscodeEnabled ? "Enabled" : "Disabled", subtitle: "BIOMETRIC PASSCODE", icon: Icons.lock_outline, value: _isPasscodeEnabled, onChanged: (v){ setState(() => _isPasscodeEnabled = v); _markSettingsChanged(); }, ),
              const SizedBox(height: 15),
              _buildSettingToggleCard( context: context, title: isDarkMode ? "Enabled" : "Disabled", subtitle: "DARK MODE", icon: Icons.lightbulb_outline, value: isDarkMode,
                onChanged: (value) { themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light); },
              ),
              const SizedBox(height: 15),
              _buildSettingToggleCard(
                context: context,
                title: _areCheckInRemindersEnabled ? "Enabled" : "Disabled",
                subtitle: "CHECK-IN REMINDERS",
                icon: Icons.notifications_active_outlined,
                value: _areCheckInRemindersEnabled,
                onChanged: (v) {
                  setState(() => _areCheckInRemindersEnabled = v);
                  _markSettingsChanged();
                },
                details: _areCheckInRemindersEnabled ? _buildCheckInReminderDetails(context) : null,
              ),
              const SizedBox(height: 15),
              _buildSettingToggleCard(
                context: context,
                title: _arePositivityRemindersEnabled ? "Enabled" : "Disabled",
                subtitle: "POSITIVITY REMINDERS",
                icon: Icons.spa_outlined,
                value: _arePositivityRemindersEnabled,
                onChanged: (v) {
                  setState(() => _arePositivityRemindersEnabled = v);
                  _markSettingsChanged();
                },
                details: _arePositivityRemindersEnabled ? _buildPositivityReminderDetails(context) : null,
              ),
              const SizedBox(height: 30),
              _buildInfoCard(text: "Add custom activities by selecting 'other' when creating a moment"),
              const SizedBox(height: 15),
              _buildInfoCard(text: "Add custom feelings by selecting 'other' when creating a moment"),
              const SizedBox(height: 30),
              _buildThemeSelectionCard(themeProvider),
              const SizedBox(height: 30),
              _buildSignOutCard(),
              const SizedBox(height: 20),
              if (_hasSettingsChanged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, left: 20, right: 20),
                  child: _buildSaveChangesButton(currentButtonGradient),
                ),
              const SizedBox(height: 40),
            ],
          ),
          _buildTopLeftCardBackButton(context, topPadding),
        ],
      ),
    );
  }

  Widget _buildCheckInReminderDetails(BuildContext context) {
    final theme = Theme.of(context);
    double sliderValue = _timeToDouble(_checkInTime);

    return Column(
      children: [
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _selectTime(context, _checkInTime, (newTime) {
            setState(() => _checkInTime = newTime);
          }),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _checkInTime.format(context), // Correctly uses BuildContext
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: _primaryFontFamily),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, size: 18, color: theme.textTheme.bodySmall?.color)
            ],
          ),
        ),
        // Text("Daily at this time", style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color, fontFamily: _primaryFontFamily)),
        Slider(
          value: sliderValue,
          min: 0, max: 1439, // 24 * 60 - 1 minutes in a day
          divisions: (1440 ~/ 15) -1, // Snap to 15-minute intervals
          activeColor: theme.colorScheme.secondary,
          inactiveColor: theme.dividerColor,
          label: _checkInTime.format(context), // Show time on slider
          onChanged: (value) {
            if (mounted) {
              setState(() {
                _checkInTime = _doubleToTime(value);
                _markSettingsChanged();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildPositivityReminderDetails(BuildContext context) {
    final theme = Theme.of(context);
    double startTimeValue = _timeToDouble(_positivityStartTime);
    double endTimeValue = _timeToDouble(_positivityEndTime);

    // Ensure start is before end for RangeSlider
    if (startTimeValue >= endTimeValue) {
      if (startTimeValue > 1439/2) endTimeValue = 1439; else startTimeValue = 0;
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Text("Remind every 30 mins between:", style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color, fontFamily: _primaryFontFamily), textAlign: TextAlign.center,),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
                onTap: () => _selectTime(context, _positivityStartTime, (newTime) {
                  setState(() => _positivityStartTime = newTime);
                }),
                child: Column(children: [
                  Text(_positivityStartTime.format(context), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: _primaryFontFamily)),
                  Text("START", style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color, fontFamily: _primaryFontFamily))
                ])),
            GestureDetector(
                onTap: () => _selectTime(context, _positivityEndTime, (newTime) {
                  setState(() => _positivityEndTime = newTime);
                }),
                child: Column(children: [
                  Text(_positivityEndTime.format(context), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: _primaryFontFamily)),
                  Text("END", style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color, fontFamily: _primaryFontFamily))
                ])),
          ],
        ),
        RangeSlider(
          values: RangeValues(startTimeValue, endTimeValue),
          min: 0, max: 1439,
          divisions: (1440 ~/ 30) -1, // Snap to 30-minute intervals
          activeColor: theme.colorScheme.secondary,
          inactiveColor: theme.dividerColor,
          labels: RangeLabels(
            _doubleToTime(startTimeValue).format(context),
            _doubleToTime(endTimeValue).format(context),
          ),
          onChanged: (values){
            if (mounted) {
              if (values.start < values.end - 15) { // Ensure min 15 min diff
                setState(() {
                  _positivityStartTime = _doubleToTime(values.start);
                  _positivityEndTime = _doubleToTime(values.end);
                  _markSettingsChanged();
                });
              }
            }
          },
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  // --- UNCHANGED BUILD HELPERS (Keep these as they were) ---
  Widget _buildTopLeftCardBackButton(BuildContext context, double topPadding) { final theme = Theme.of(context); return Positioned( top: topPadding + 10, left: 16, child: Card( elevation: 2.0, color: theme.cardColor.withOpacity(0.85), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: IconButton( icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface.withOpacity(0.8), size: 20), tooltip: "Back", onPressed: () { if (Navigator.canPop(context)) { Navigator.pop(context); } }, constraints: const BoxConstraints(), padding: const EdgeInsets.all(8), ), ), ); }
  Widget _buildTopSection(BuildContext context, String? currentPhotoUrl) { final screenWidth = MediaQuery.of(context).size.width; final double cardHeight = screenWidth * 0.3; final double cardWidth = screenWidth * 0.45; bool hasPhoto = currentPhotoUrl != null && currentPhotoUrl.isNotEmpty; ImageProvider? backgroundImage; if (hasPhoto) { backgroundImage = NetworkImage(currentPhotoUrl!); } final themeProvider = Provider.of<ThemeProvider>(context, listen: false); return Container( height: 70 + cardHeight, alignment: Alignment.topRight, child: Container( height: cardHeight, width: cardWidth, margin: const EdgeInsets.only(top: 70, right: 20), decoration: BoxDecoration( borderRadius: BorderRadius.circular(_settingsCardRadius), color: hasPhoto ? Theme.of(context).colorScheme.surface : null, gradient: hasPhoto ? null : LinearGradient(colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end:Alignment.bottomRight), image: hasPhoto ? DecorationImage(image: backgroundImage!, fit: BoxFit.cover) : null, boxShadow: [ BoxShadow( color: themeProvider.currentAccentColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5), ) ] ), child: !hasPhoto ? Center( child: Icon(Icons.camera_alt_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 40), ) : null, ), ); }
  Widget _buildUserInfoCard() { String maskEmail(String? email) { if (email == null || email.length < 5 || !email.contains('@')) { return email ?? 'No email'; } final atIndex = email.indexOf('@'); final prefix = email.substring(0, 3); final domain = email.substring(atIndex); return '$prefix...$domain'; } final Color textColor = Theme.of(context).colorScheme.onSurface; final Color subtitleColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey; final Color progressColor = Theme.of(context).colorScheme.primary; return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: _isLoadingUserInfo ? SizedBox(key: const ValueKey("name_loading_info"), height: 18, width: 100, child: LinearProgressIndicator(color: progressColor.withOpacity(0.5), backgroundColor: Theme.of(context).hoverColor)) : Text( key: ValueKey(_userName ?? "name_display_info"), _userName ?? "User Name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor, fontFamily: _primaryFontFamily), ), ), const SizedBox(height: 15), Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: _isLoadingUserInfo ? SizedBox(key: const ValueKey("email_loading_info"), height: 16, width: 150, child: LinearProgressIndicator(color: progressColor.withOpacity(0.5), backgroundColor: Theme.of(context).hoverColor)) : Text( key: ValueKey(_userEmail ?? "email_display_info"), maskEmail(_userEmail), style: TextStyle(fontSize: 14, color: subtitleColor, fontFamily: _primaryFontFamily), ), ), InkWell( onTap: (){ print("Sync Tapped"); }, borderRadius: BorderRadius.circular(15), child: Container( padding: const EdgeInsets.all(5), decoration: BoxDecoration( shape: BoxShape.circle, color: Theme.of(context).hoverColor ), child: Icon(Icons.sync, size: 18, color: subtitleColor) ) ) ], ), ], ), ), ), ); }
  Widget _buildSettingToggleCard({ required BuildContext context, required String title, required String subtitle, required IconData icon, required bool value, required ValueChanged<bool> onChanged, Widget? details, }) { final Color textColor = Theme.of(context).colorScheme.onSurface; final Color subtitleColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey; final Color iconColor = subtitleColor; return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Padding( padding: EdgeInsets.only(top: 12.0, left: 20.0, right: 10.0, bottom: details != null ? 0 : 12.0), child: Column( children: [ Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( title, style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: textColor, fontFamily: _primaryFontFamily ), ), const SizedBox(height: 4), Text( subtitle, style: TextStyle( fontSize: 10, fontWeight: FontWeight.w500, color: subtitleColor, letterSpacing: 0.5, fontFamily: _primaryFontFamily ), ), ], ), ), const SizedBox(width: 15), Row( children: [ Icon(icon, color: iconColor, size: 22), const SizedBox(width: 0), Transform.scale( scale: 0.9, child: Switch( value: value, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, ), ), ], ), ], ), if (details != null) Padding( padding: const EdgeInsets.only(top: 10.0, bottom: 15.0, right: 10.0), child: details, ) ] ), ), ), ); }
  Widget _buildInfoCard({required String text}) { return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0), child: Text( text, textAlign: TextAlign.center, style: TextStyle( fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), height: 1.4, fontFamily: _primaryFontFamily ), ), ), ), ); }
  Widget _buildThemeSelectionCard(ThemeProvider themeProvider) { final List<AppThemeType> themeOptions = AppThemeType.values; return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( clipBehavior: Clip.antiAlias, child: Container( padding: const EdgeInsets.symmetric(vertical: 20.0), decoration: BoxDecoration( gradient: LinearGradient(colors: themeProvider.currentAccentGradient, begin:Alignment.topLeft, end: Alignment.bottomRight)), child: SizedBox( height: 55, child: ListView.builder( scrollDirection: Axis.horizontal, itemCount: themeOptions.length, padding: const EdgeInsets.symmetric(horizontal: 15), itemBuilder: (context, index) { final themeType = themeOptions[index]; Color color = AppThemes.getPrimaryAccentColor(themeType); bool isSelected = themeProvider.appThemeType == themeType; return Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0), child: _buildColorCircle(color: color, isSelected: isSelected, themeType: themeType, provider: themeProvider),);},),),),),); }
  Widget _buildColorCircle({required Color color, required bool isSelected, required AppThemeType themeType, required ThemeProvider provider}) { return GestureDetector( onTap: () { provider.setAppTheme(themeType); }, child: Container( width: 40, height: 40, decoration: BoxDecoration( shape: BoxShape.circle, color: color, border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9), width: 3) : Border.all(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5), width: 1), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.15), blurRadius: 5, offset: const Offset(0, 2), ) ] ), ), ); }
  Widget _buildSignOutCard() { return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Material( color: Colors.transparent, child: InkWell( onTap: _signOutUser, borderRadius: BorderRadius.circular(_settingsCardRadius), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0), child: Row( children: [ Icon(Icons.logout, color: _dangerColor, size: 22), const SizedBox(width: 15), Expanded( child: Text( "Sign Out", style: TextStyle(fontSize: 15, color: _dangerColor, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily), ), ), ], ), ), ), ), ), ); }
  Widget _buildSaveChangesButton(List<Color> gradientColors) { return ElevatedButton( onPressed: _hasSettingsChanged ? _saveSettingsAndScheduleNotifications : null, style: Theme.of(context).elevatedButtonTheme.style?.copyWith( padding: MaterialStateProperty.all(EdgeInsets.zero), elevation: MaterialStateProperty.all(0), backgroundColor: MaterialStateProperty.all(Colors.transparent), ), child: Ink( decoration: BoxDecoration( gradient: LinearGradient( colors: _hasSettingsChanged ? gradientColors : [Colors.grey.shade400, Colors.grey.shade500], begin: Alignment.centerLeft, end: Alignment.centerRight ), borderRadius: BorderRadius.circular(15), boxShadow: _hasSettingsChanged ? [ BoxShadow( color: gradientColors[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4), ) ] : [] ), child: Container( height: 55, alignment: Alignment.center, child: Text( "SAVE CHANGES", style: TextStyle( color: _hasSettingsChanged ? Colors.white: Colors.white.withOpacity(0.7) , fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5, fontFamily: _primaryFontFamily ), ), ), ), ); }

}
//import 'package:counsellorconnect/login/Phone_Auth.dart';
import 'package:counsellorconnect/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; // Import Provider

// Import your other necessary files
import 'onboarding/onboarding_page.dart';
import 'categories_screen.dart';
import 'models/quote_model.dart';
import 'theme/theme_provider.dart'; // Import ThemeProvider
import 'theme/app_theme.dart'; // Import AppThemes for enum/colors

// --- Constants ---
const Color _settingsScaffoldBg = Color(0xFFF8F9FA); // Keep light grey BG
// const Color _settingsCardBg = Colors.white; // Use Theme.cardColor
const Color _settingsTextColor = Color(0xFF343A40); // Use Theme text colors
const Color _settingsSubtitleColor = Colors.grey; // Use Theme text colors
// const Color _settingsIconColor = Colors.grey; // Use Theme icon colors
const Color _profileGradientStart = Color(0xFF20C997); // For top card placeholder & theme card
const Color _profileGradientEnd = Color(0xFF17A2B8);
const Gradient _profilePlaceholderGradient = LinearGradient( colors: [_profileGradientStart, _profileGradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight, );
const double _settingsCardRadius = 16.0;
final Color _dangerColor = Colors.red.shade600;

// Theme Color Options for Selection Card
final Color _themeColorPurple = Colors.deepPurple.shade400;
final Color _themeColorOrange = Colors.orange.shade500;
final Color _themeColorPink = Colors.pink.shade400;
final Color _themeColorLightBlue = Colors.lightBlue.shade400;
final Color _themeColorTeal = Colors.teal.shade300; // Added
final Color _themeColorGreen = Colors.green.shade400; // Added
final Color _themeColorRed = Colors.red.shade400; // Added
final Color _themeColorIndigo = Colors.indigo.shade400; // Added

// Gradients Map for Save Button (ensure all accents are keys)
final Map<Color, List<Color>> _themeGradients = {
  _themeColorPurple: [const Color(0xFF8185E2), _themeColorPurple],
  _themeColorOrange: [Colors.orange.shade400, _themeColorOrange],
  _themeColorPink: [Colors.pink.shade300, _themeColorPink],
  _themeColorLightBlue: [Colors.lightBlue.shade100, _lightBlueAccent], // Use accent defined elsewhere
  _themeColorTeal: [Colors.teal.shade200, _themeColorTeal],
  _themeColorGreen: [Colors.green.shade200, _themeColorGreen],
  _themeColorRed: [Colors.red.shade200, _themeColorRed],
  _themeColorIndigo: [Colors.indigo.shade200, _themeColorIndigo],
};
// Make sure _lightBlueAccent exists if used above
final Color _lightBlueAccent = Colors.lightBlue.shade400;

// --- End Constants ---


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- State Variables ---
  // Local Settings State
  bool _isPasscodeEnabled = false;
  bool _areCheckInRemindersEnabled = true;
  TimeOfDay _checkInTime = const TimeOfDay(hour: 22, minute: 20);
  bool _arePositivityRemindersEnabled = true;
  TimeOfDay _positivityStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _positivityEndTime = const TimeOfDay(hour: 22, minute: 0);
  int _positivityFrequency = 5;

  // User Info State
  String? _userName;
  String? _userEmail;
  String? _photoUrl;
  bool _isLoadingUserInfo = true;
  String _errorMessage = '';

  // --- NEW: State to track if non-theme settings changed ---
  bool _hasSettingsChanged = false;
  // --- End New State ---

  // Firebase Instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    // TODO: Load initial switch/time/frequency states from persistence
  }

  // --- Helper to mark settings as changed ---
  void _markSettingsChanged() {
    if (!_hasSettingsChanged && mounted) {
      setState(() => _hasSettingsChanged = true);
    }
  }
  // --- End Helper ---

  // Fetch User Info
  Future<void> _fetchUserInfo() async { /* ... Same as previous ... */ if (!mounted) return; setState(() { _isLoadingUserInfo = true; _errorMessage = ''; _photoUrl = null; }); final user = _auth.currentUser; if (user != null) { _userEmail = user.email; _userName = user.displayName; try { final doc = await _firestore.collection('users').doc(user.uid).get(); if (doc.exists && doc.data() != null) { final data = doc.data() as Map<String, dynamic>; if (_userName == null || _userName!.isEmpty) { _userName = data['name'] as String?; } _photoUrl = data['photoUrl'] as String?; } else { if (_userName == null) _userName = "User"; _photoUrl = null; } } catch(e) { print("Error fetching Firestore details: $e"); if (_userName == null) _userName = "User"; _photoUrl = null; } } else { _userName = "Guest"; _userEmail = null; _photoUrl = null; } if (mounted) { setState(() { _isLoadingUserInfo = false; }); } }

  // Save Settings Logic (Reset flag on success)
  Future<void> _saveSettings() async {
    print("Save Changes tapped...");
    // TODO: Implement saving logic for _isPasscodeEnabled, _are..., _checkInTime, etc.
    // Example placeholder save:
    await Future.delayed(const Duration(seconds: 1)); // Simulate save delay
    print("Settings saved (placeholder).");

    // Reset the changed flag after saving
    if (mounted) {
      setState(() => _hasSettingsChanged = false);
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Settings Saved!"), duration: Duration(seconds: 1)) );
    }
  }

  // Sign Out Logic
  Future<void> _signOutUser() async { /* ... Same as previous ... */ try { await FirebaseAuth.instance.signOut(); if (mounted) { Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const RoleSelectionScreen()), (Route<dynamic> route) => false, ); } } catch (e) { print("Error signing out: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Error signing out: ${e.toString()}")), ); } } }

  // Time Picker Helper (Mark settings changed on selection)
  Future<void> _selectTime(BuildContext context, TimeOfDay initialTime, ValueChanged<TimeOfDay> onTimeChanged) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Color currentAccent = themeProvider.currentAccentColor;
    final TimeOfDay? picked = await showTimePicker( context: context, initialTime: initialTime, builder: (context, child) { return Theme( data: Theme.of(context).copyWith( colorScheme: Theme.of(context).colorScheme.copyWith( primary: currentAccent, onPrimary: Colors.white, onSurface: Theme.of(context).colorScheme.onSurface ), textButtonTheme: TextButtonThemeData( style: TextButton.styleFrom( foregroundColor: currentAccent, ), ), ), child: child!, ); }, );
    if (picked != null && picked != initialTime) {
      if (mounted){
        // Call the original callback AND mark settings as changed
        setState(() {
          onTimeChanged(picked);
          _markSettingsChanged(); // Mark change
        });
      }
    } }
  double _timeToDouble(TimeOfDay time) { /* ... Same ... */ return time.hour * 60.0 + time.minute; }
  TimeOfDay _doubleToTime(double value) { /* ... Same ... */ final int hours = (value / 60).floor() % 24; final int minutes = (value % 60).floor(); return TimeOfDay(hour: hours, minute: minutes); }
  String _getTimePeriod(TimeOfDay time) { /* ... Same ... */ if (time.hour < 6) return "NIGHT"; if (time.hour < 12) return "MORNING"; if (time.hour < 18) return "AFTERNOON"; return "EVENING"; }


  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.themeMode == ThemeMode.dark || (themeProvider.themeMode == SystemUiMode && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final List<Color> currentButtonGradient = themeProvider.currentAccentGradient;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTopSection(context, _photoUrl), // Includes space for top icons
              _buildUserInfoCard(),
              const SizedBox(height: 20),
              if (_isLoadingUserInfo && (_userName == null)) Center(child: Padding(padding: const EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))),
              if (_errorMessage.isNotEmpty) Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0), child: Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)), ),

              // Settings Sections
              _buildSettingToggleCard( context: context, title: _isPasscodeEnabled ? "Enabled" : "Disabled", subtitle: "BIOMETRIC PASSCODE", icon: Icons.lock_outline, value: _isPasscodeEnabled, onChanged: (v){ setState(() => _isPasscodeEnabled = v); _markSettingsChanged(); }, ),
              const SizedBox(height: 15),
              // Dark Mode Toggle connected to Provider (doesn't trigger save button)
              _buildSettingToggleCard( context: context, title: isDarkMode ? "Enabled" : "Disabled", subtitle: "DARK MODE", icon: Icons.lightbulb_outline, value: isDarkMode,
                onChanged: (value) { themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light); },
              ),
              const SizedBox(height: 15),
              _buildSettingToggleCard( context: context, title: _areCheckInRemindersEnabled ? "Enabled" : "Disabled", subtitle: "CHECK-IN REMINDERS", icon: Icons.notifications_none, value: _areCheckInRemindersEnabled, onChanged: (v){ setState(() => _areCheckInRemindersEnabled = v); _markSettingsChanged(); }, details: _areCheckInRemindersEnabled ? _buildCheckInReminderDetails(context) : null, ),
              const SizedBox(height: 15),
              _buildSettingToggleCard( context: context, title: _arePositivityRemindersEnabled ? "Enabled" : "Disabled", subtitle: "POSITIVITY REMINDERS", icon: Icons.notifications_none, value: _arePositivityRemindersEnabled, onChanged: (v){ setState(() => _arePositivityRemindersEnabled = v); _markSettingsChanged(); }, details: _arePositivityRemindersEnabled ? _buildPositivityReminderDetails(context) : null, ),
              const SizedBox(height: 30),
              _buildInfoCard(text: "Add custom activities by selecting 'other' when creating a moment"),
              const SizedBox(height: 15),
              _buildInfoCard(text: "Add custom feelings by selecting 'other' when creating a moment"),
              const SizedBox(height: 30),
              // Theme Selection connected to Provider (doesn't trigger save button)
              _buildThemeSelectionCard(themeProvider),
              const SizedBox(height: 30),
              _buildSignOutCard(),
              const SizedBox(height: 20),

              // --- Conditionally Display Save Button ---
              if (_hasSettingsChanged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0), // Add padding below save button
                  child: _buildSaveChangesButton(currentButtonGradient),
                ),
              // --- End Conditional Save Button ---

              const SizedBox(height: 40), // Bottom padding
            ],
          ),
          // Positioned Top Icons (Back Arrow in Card)
          _buildTopLeftCardBackButton(context, topPadding), // Use new back button
        ],
      ),
    );
  }

  // --- Build Helpers ---

  // --- NEW: Top Left Back Button in Card ---
  Widget _buildTopLeftCardBackButton(BuildContext context, double topPadding) {
    return Positioned(
      top: topPadding + 10, // Below status bar
      left: 16, // Position on the left
      child: Card( // Use Card for background/shadow
        elevation: 2.0,
        // Use theme card color, maybe slightly transparent if preferred
        color: Theme.of(context).cardColor.withOpacity(0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8), size: 20),
          tooltip: "Back",
          onPressed: () { if (Navigator.canPop(context)) { Navigator.pop(context); } },
          constraints: const BoxConstraints(), // Remove default padding
          padding: const EdgeInsets.all(8), // Adjust internal padding
        ),
      ),
    );
  }
  // --- End Back Button ---

  // Top Section - Shows Photo or Placeholder Gradient
  Widget _buildTopSection(BuildContext context, String? currentPhotoUrl) { /* ... Same as previous ... */ final screenWidth = MediaQuery.of(context).size.width; final double cardHeight = screenWidth * 0.3; final double cardWidth = screenWidth * 0.45; bool hasPhoto = currentPhotoUrl != null && currentPhotoUrl.isNotEmpty; ImageProvider? backgroundImage; if (hasPhoto) { backgroundImage = CachedNetworkImageProvider(currentPhotoUrl!); } return Container( height: 70 + cardHeight, alignment: Alignment.topRight, child: Container( height: cardHeight, width: cardWidth, margin: const EdgeInsets.only(top: 70, right: 20), decoration: BoxDecoration( borderRadius: BorderRadius.circular(_settingsCardRadius), color: hasPhoto ? Theme.of(context).colorScheme.surface : null, gradient: hasPhoto ? null : _profilePlaceholderGradient, image: hasPhoto ? DecorationImage(image: backgroundImage!, fit: BoxFit.cover) : null, boxShadow: [ BoxShadow( color: _profileGradientStart.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5), ) ] ), child: !hasPhoto ? const Center( child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 40), ) : null, ), ); }

  // User Info Card - Uses Theme colors
  Widget _buildUserInfoCard() { /* ... Same as previous (uses theme) ... */ String maskEmail(String? email) { if (email == null || email.length < 5 || !email.contains('@')) { return email ?? 'No email'; } final atIndex = email.indexOf('@'); final prefix = email.substring(0, 3); final domain = email.substring(atIndex); return '$prefix...$domain'; } final Color textColor = Theme.of(context).colorScheme.onSurface; final Color subtitleColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey; final Color progressColor = Theme.of(context).colorScheme.primary; return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: _isLoadingUserInfo ? SizedBox(key: const ValueKey("name_loading_info"), height: 18, width: 100, child: LinearProgressIndicator(color: progressColor.withOpacity(0.5), backgroundColor: Theme.of(context).hoverColor)) : Text( key: ValueKey(_userName ?? "name_display_info"), _userName ?? "User Name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor), ), ), const SizedBox(height: 15), Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: _isLoadingUserInfo ? SizedBox(key: const ValueKey("email_loading_info"), height: 16, width: 150, child: LinearProgressIndicator(color: progressColor.withOpacity(0.5), backgroundColor: Theme.of(context).hoverColor)) : Text( key: ValueKey(_userEmail ?? "email_display_info"), maskEmail(_userEmail), style: TextStyle(fontSize: 14, color: subtitleColor), ), ), InkWell( onTap: (){ print("Sync Tapped"); }, borderRadius: BorderRadius.circular(15), child: Container( padding: const EdgeInsets.all(5), decoration: BoxDecoration( shape: BoxShape.circle, color: Theme.of(context).hoverColor ), child: Icon(Icons.sync, size: 18, color: subtitleColor) ) ) ], ), ], ), ), ), ); }

  // Settings Toggle Card - Relies on Theme for switch colors
  Widget _buildSettingToggleCard({ required BuildContext context, required String title, required String subtitle, required IconData icon, required bool value, /* removed activeColor */ required ValueChanged<bool> onChanged, Widget? details, }) {
    final Color textColor = Theme.of(context).colorScheme.onSurface; final Color subtitleColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey; final Color iconColor = subtitleColor;
    return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card(
      child: Padding( padding: EdgeInsets.only(top: 12.0, left: 20.0, right: 10.0, bottom: details != null ? 0 : 12.0),
        child: Column( children: [
          Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( title, style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: textColor, ), ), const SizedBox(height: 4), Text( subtitle, style: TextStyle( fontSize: 10, fontWeight: FontWeight.w500, color: subtitleColor, letterSpacing: 0.5, ), ), ], ), ),
            const SizedBox(width: 15),
            Row( children: [ Icon(icon, color: iconColor, size: 22), const SizedBox(width: 0),
              Transform.scale( scale: 0.9,
                child: Switch( value: value, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, ), // Rely on SwitchTheme
              ),
            ], ), ], ),
          if (details != null) Padding( padding: const EdgeInsets.only(top: 10.0, bottom: 15.0, right: 10.0), child: details, )
        ] ),
      ),
    ), );
  }
  // Reminder Details Widgets (Use Theme colors)
  Widget _buildCheckInReminderDetails(BuildContext context) { /* ... Same structure, uses Theme.of(context) ... */ double sliderValue = _timeToDouble(_checkInTime); final theme = Theme.of(context); return Column( children: [ const SizedBox(height: 10), GestureDetector( onTap: () => _selectTime(context, _checkInTime, (newTime) { _checkInTime = newTime; _markSettingsChanged(); }), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Text( _checkInTime.format(context), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), ), const SizedBox(width: 8), Icon(Icons.edit_outlined, size: 18, color: theme.textTheme.bodySmall?.color) ], ), ), Text( _getTimePeriod(_checkInTime), style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color), ), const SizedBox(height: 5), Slider( value: sliderValue, min: 0, max: 1439, divisions: 1440 ~/ 15, activeColor: theme.colorScheme.secondary, inactiveColor: theme.dividerColor, onChanged: (value) { if (mounted){ setState(() { _checkInTime = _doubleToTime(value); _markSettingsChanged(); }); } }, ), ], ); }
  Widget _buildPositivityReminderDetails(BuildContext context) { /* ... Same structure, uses Theme.of(context) ... */ double startValue = _timeToDouble(_positivityStartTime); double endValue = _timeToDouble(_positivityEndTime); if (startValue >= endValue) { if (startValue > 1439/2) endValue = 1439; else startValue = 0; } final theme = Theme.of(context); return Column( children: [ const SizedBox(height: 15), Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [ GestureDetector( onTap: () => _selectTime(context, _positivityStartTime, (newTime) { _positivityStartTime = newTime; _markSettingsChanged(); }), child: Column(children: [ Text(_positivityStartTime.format(context), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)), Text("START AT", style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color)) ])), GestureDetector( onTap: () => _selectTime(context, _positivityEndTime, (newTime) { _positivityEndTime = newTime; _markSettingsChanged(); }), child: Column(children: [ Text(_positivityEndTime.format(context), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)), Text("END AT", style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color)) ])), ], ), const SizedBox(height: 10), RangeSlider( values: RangeValues(startValue, endValue), min: 0, max: 1439, divisions: 1440 ~/ 30, activeColor: theme.colorScheme.secondary, inactiveColor: theme.dividerColor, onChanged: (values) { if (mounted) { if (values.start < values.end - 1) { setState(() { _positivityStartTime = _doubleToTime(values.start); _positivityEndTime = _doubleToTime(values.end); _markSettingsChanged(); }); } } }, ), const SizedBox(height: 15), Row( mainAxisAlignment: MainAxisAlignment.center, children: [ InkWell( onTap: () { if (_positivityFrequency > 1 && mounted) setState(() { _positivityFrequency--; _markSettingsChanged(); }); }, borderRadius: BorderRadius.circular(20), child: Container( padding: const EdgeInsets.all(8), decoration: BoxDecoration( shape: BoxShape.circle, color: theme.hoverColor ), child: Icon(Icons.remove, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.7)) ) ), const SizedBox(width: 25), Column(children: [ Text("${_positivityFrequency}x", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)), Text("REMINDERS", style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color)) ]), const SizedBox(width: 25), InkWell( onTap: () { if (_positivityFrequency < 20 && mounted) setState(() { _positivityFrequency++; _markSettingsChanged(); }); }, borderRadius: BorderRadius.circular(20), child: Container( padding: const EdgeInsets.all(8), decoration: BoxDecoration( shape: BoxShape.circle, color: theme.hoverColor ), child: Icon(Icons.add, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.7)) ) ), ], ), const SizedBox(height: 10), ], ); }

  // Info Card Builder - Use Theme colors
  Widget _buildInfoCard({required String text}) { /* ... Same structure, uses Theme ... */ return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0), child: Text( text, textAlign: TextAlign.center, style: TextStyle( fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), height: 1.4 ), ), ), ), ); }

  // --- UPDATED: Theme Selection Card - Now Horizontal Scroll ---
  Widget _buildThemeSelectionCard(ThemeProvider themeProvider) {
    final List<AppThemeType> themeOptions = AppThemeType.values; // All defined light themes

    return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( clipBehavior: Clip.antiAlias,
      child: Container( // Container for gradient BG
        padding: const EdgeInsets.symmetric(vertical: 20.0), // Vertical padding only
        decoration: const BoxDecoration( gradient: _profilePlaceholderGradient, ), // Keep teal gradient BG
        child: SizedBox( // Constrain the height of the ListView
          height: 55, // Height for circles + padding
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: themeOptions.length,
            padding: const EdgeInsets.symmetric(horizontal: 15), // Padding at ends of list
            itemBuilder: (context, index) {
              final themeType = themeOptions[index];
              Color color = AppThemes.getPrimaryAccentColor(themeType);
              bool isSelected = themeProvider.appThemeType == themeType;
              return Padding( // Add padding between circles
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildColorCircle(
                    color: color,
                    isSelected: isSelected,
                    themeType: themeType,
                    provider: themeProvider
                ),
              );
            },
          ),
        ),
      ),
    ), );
  }
  // Color Circle Helper
  Widget _buildColorCircle({required Color color, required bool isSelected, required AppThemeType themeType, required ThemeProvider provider}) { /* ... Same ... */ return GestureDetector( onTap: () { provider.setAppTheme(themeType); }, child: Container( width: 40, height: 40, decoration: BoxDecoration( shape: BoxShape.circle, color: color, border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9), width: 3) : Border.all(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5), width: 1), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.15), blurRadius: 5, offset: const Offset(0, 2), ) ] ), ), ); }
  // --- End Theme Selection Update ---

  // Sign Out Card Builder
  Widget _buildSignOutCard() { /* ... Same structure, uses Theme ... */ return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Material( color: Colors.transparent, child: InkWell( onTap: _signOutUser, borderRadius: BorderRadius.circular(_settingsCardRadius), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0), child: Row( children: [ Icon(Icons.logout, color: _dangerColor, size: 22), const SizedBox(width: 15), Expanded( child: Text( "Sign Out", style: TextStyle(fontSize: 15, color: _dangerColor, fontWeight: FontWeight.w500), ), ), ], ), ), ), ), ), ); }

  // Save Changes Button
  Widget _buildSaveChangesButton(List<Color> gradientColors) { /* ... Same structure, uses Theme ... */ return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: ElevatedButton( onPressed: _saveSettings, style: Theme.of(context).elevatedButtonTheme.style?.copyWith( padding: MaterialStateProperty.all(EdgeInsets.zero), elevation: MaterialStateProperty.all(0), backgroundColor: MaterialStateProperty.all(Colors.transparent), ), child: Ink( decoration: BoxDecoration( gradient: LinearGradient( colors: gradientColors, begin: Alignment.centerLeft, end: Alignment.centerRight ), borderRadius: BorderRadius.circular(15), boxShadow: [ BoxShadow( color: gradientColors[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4), ) ] ), child: Container( height: 55, alignment: Alignment.center, child: const Text( "SAVE CHANGES", style: TextStyle( color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5 ), ), ), ), ), ); }

} // End _SettingsScreenState
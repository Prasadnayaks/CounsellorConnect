// lib/Name_screen.dart
//import 'package:counsellorconnect/counselor/counselor_dashboard_screen.dart';
import 'package:counsellorconnect/counselor/get_counselor_information.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

// Import theme files
import '../theme/theme_provider.dart';

// Import main app shell and placeholder for counselor screen
import '../main_navigation_shell.dart';
import '../login/Phone_Auth.dart'; // Assuming CounselorDashboardPlaceholder is here

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const String _lottieLogoAsset = 'assets/animation.json';
// --- End Constants ---

class SecondScreen extends StatefulWidget {
  final String role; // <-- Accept role passed from OTP screen

  const SecondScreen({Key? key, required this.role}) : super(key: key);

  @override
  _SecondScreenState createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _nicknameController;
  bool _isButtonEnabled = false;
  bool _isKeyboardVisible = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isSaving = false;

  @override
  void initState() { super.initState(); _nicknameController = TextEditingController(); _nicknameController.addListener(_checkInput); _animationController = AnimationController( vsync: this, duration: const Duration(milliseconds: 300), ); _slideAnimation = Tween<Offset>( begin: Offset.zero, end: const Offset(0, -0.2), ).animate(CurvedAnimation( parent: _animationController, curve: Curves.easeInOut, )); _fadeAnimation = Tween<double>( begin: 1.0, end: 0.0, ).animate(CurvedAnimation( parent: _animationController, curve: Curves.easeInOut, )); }
  @override
  void dispose() { _nicknameController.dispose(); _animationController.dispose(); super.dispose(); }

  void _checkInput() { if (mounted) setState(() { _isButtonEnabled = _nicknameController.text.trim().isNotEmpty; }); }
  void _onFocusChange(bool hasFocus) { if (mounted) { setState(() { _isKeyboardVisible = hasFocus; }); if (hasFocus) { _animationController.forward(); } else { _animationController.reverse(); } } }


  // --- Save Name AND Role, then Navigate ---
  Future<void> _onContinuePressed() async {
    if (!_isButtonEnabled || _isSaving) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _isSaving = true; });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { /* Handle error */ setState(() => _isSaving = false); return; }

    try {
      // --- Save name AND role ---
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {'name': nickname, 'role': widget.role}, // Save name and received role
        SetOptions(merge: true), // Merge with data set in OTP screen (like phone, createdAt)
      );
      // --- End Save ---

      print("Name '$nickname' and Role '${widget.role}' saved for UID: ${user.uid}");
      if (mounted) {
        // --- Navigate based on Role ---
        if (widget.role == 'counselor') {
          print("COUNSELOR SIGNED UP - NAVIGATING TO COUNSELOR DASHBOARD");
          Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const GetCounselorInformationScreen()), (Route<dynamic> route) => false, );
        } else {
          // Navigate 'user' to the Main App Shell
          Navigator.of(context).pushReplacement( // Use pushReplacement from Name screen
            MaterialPageRoute(builder: (context) => const MainNavigationShell()),
          );
        }
      }
    } catch (e) { /* ... Error handling ... */ print("Error saving name/role: $e"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save profile: ${e.toString()}"))); setState(() { _isSaving = false; }); } }
    // No finally needed because we navigate on success
  }
  // --- End Save ---


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
                // Add a simple Back button if needed (navigates back to OTP screen)
                Align( alignment: Alignment.topLeft, child: Padding( padding: const EdgeInsets.only(left: 8.0, top: 10.0), child: IconButton( icon: Icon(Icons.arrow_back_ios_new, color: onGradientColor.withOpacity(0.8), size: 20), onPressed: () => Navigator.pop(context), ), ), ),
                Expanded( child: SingleChildScrollView( physics: const BouncingScrollPhysics(), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 25), child: Column(
                  children: [
                    const SizedBox(height: 10), // Reduced space
                    FadeTransition( opacity: _fadeAnimation, child: SlideTransition( position: _slideAnimation, child: SizedBox( width: 150, height: 150, child: Lottie.asset( _lottieLogoAsset, fit: BoxFit.contain, ), ), ), ),
                    const SizedBox(height: 40),
                    SlideTransition( position: _slideAnimation, child: Text( "So nice to meet you!\nWhat should we call you?", textAlign: TextAlign.center, style: TextStyle( fontSize: 22, fontWeight: FontWeight.w500, color: onGradientColor, fontFamily: _primaryFontFamily, height: 1.3 ), ), ),
                    const SizedBox(height: 60),
                    // Nickname TextField (Themed)
                    Container( decoration: BoxDecoration( color: onGradientColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15), boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5), ), ], ),
                      child: Focus( onFocusChange: _onFocusChange, child: TextField( controller: _nicknameController, style: TextStyle(color: onGradientColor, fontSize: 21, fontFamily: _primaryFontFamily), textAlign: TextAlign.center, decoration: InputDecoration( hintText: "Your nickname...", hintStyle: TextStyle(color: onGradientMutedColor, fontSize: 21, fontFamily: _primaryFontFamily), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20), ), textCapitalization: TextCapitalization.words, keyboardType: TextInputType.name, ), ), ),
                    const SizedBox(height: 30),
                    // Done Check Button
                    if (_isKeyboardVisible) Align( alignment: Alignment.centerRight, child: GestureDetector( onTap: () => FocusScope.of(context).unfocus(), child: Container( padding: const EdgeInsets.all(8), decoration: BoxDecoration( color: currentTheme.cardColor.withOpacity(0.9), borderRadius: BorderRadius.circular(10), ), child: Icon( Icons.check, color: colorScheme.primary, size: 30, ), ), ), ),
                    const SizedBox(height: 50),
                  ], ), ), ), ),
                // Bottom Continue Button (Themed)
                Padding( padding: EdgeInsets.only( left: 40.0, right: 40.0, top: 15.0, bottom: _isKeyboardVisible ? MediaQuery.of(context).viewInsets.bottom + 15.0 : MediaQuery.of(context).padding.bottom + 25.0, ),
                  child: AnimatedOpacity( opacity: _isKeyboardVisible ? 0.0 : 1.0, duration: const Duration(milliseconds: 300), child: IgnorePointer( ignoring: _isKeyboardVisible, child: SizedBox( width: double.infinity, height: 60,
                    child: ElevatedButton(
                      onPressed: _isButtonEnabled && !_isSaving ? _onContinuePressed : null,
                      style: ElevatedButton.styleFrom( backgroundColor: currentTheme.cardColor, foregroundColor: colorScheme.primary, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15), ), minimumSize: const Size(double.infinity, 60), elevation: 3, ),
                      child: _isSaving ? SizedBox( width: 24, height: 24, child: CircularProgressIndicator( strokeWidth: 2, color: colorScheme.primary), ) : Text( "CONTINUE", style: TextStyle( color: _isButtonEnabled && !_isSaving ? colorScheme.primary : colorScheme.primary.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 18, fontFamily: _primaryFontFamily ), ),
                    ), ), ), ), ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
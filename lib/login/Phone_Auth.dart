// lib/Phone_Auth.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart'; // Import Lottie

// Import theme files
import '../theme/theme_provider.dart';

// Import next screens
import 'otp_screen.dart'; // Assume OTPScreen is in otp_screen.dart now
import '../onboarding/Name_screen.dart';
import '../main_navigation_shell.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const String _lottieLogoAsset = 'assets/animation.json'; // Ensure path is correct
// --- End Constants ---

// --- Placeholder for Counselor Dashboard ---
class CounselorDashboardPlaceholder extends StatelessWidget {
  const CounselorDashboardPlaceholder({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text("Counselor Dashboard")), body: const Center(child: Text("Counselor UI Placeholder")));
  }
}
// --- End Placeholder ---


// --- Login Screen (Phone Number Entry) ---
class LoginScreen extends StatefulWidget {
  final String role; // Role passed from RoleSelectionScreen

  const LoginScreen({Key? key, required this.role}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;
  // Default Country Code - Consider using a picker package for robust implementation
  String countryCode = "+91";

  @override
  void initState() {
    super.initState();
    print("[LoginScreen] Initialized with role: ${widget.role}");
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  // --- Verify Phone Number and Send OTP ---
  Future<void> _verifyPhoneNumber() async {
    String phoneNumber = phoneController.text.trim();
    if (phoneNumber.isEmpty || phoneNumber.length < 10) { // Basic validation
      if (mounted) setState(() => errorMessage = "Please enter a valid 10-digit phone number");
      return;
    }
    // Format full number
    String fullPhoneNumber = phoneNumber;
    if (!phoneNumber.startsWith('+') && !phoneNumber.startsWith(countryCode)) {
      fullPhoneNumber = countryCode + phoneNumber;
    } else if (phoneNumber.startsWith('+') && !phoneNumber.startsWith(countryCode)){
      // Handle case like +8888888888, assuming default code needed
      fullPhoneNumber = countryCode + phoneNumber.substring(1);
    }
    fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    print("Attempting to verify phone: $fullPhoneNumber for role: ${widget.role}");
    if (!mounted) return;
    setState(() { isLoading = true; errorMessage = null; });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("Phone verification auto-completed.");
          if (mounted) setState(() { isLoading = false; });
          try {
            UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) await _checkProfileAndNavigateAfterSignIn(context, userCredential.user, widget.role);
          } on FirebaseAuthException catch (e) {
            if (mounted) setState(() { isLoading = false; errorMessage = e.message ?? "Auto-verification failed."; });
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          print("Phone verification failed: ${error.code} - ${error.message}");
          if (mounted) setState(() { isLoading = false; errorMessage = error.message ?? "Verification failed. Check number or try again."; });
        },
        codeSent: (String verificationId, int? resendToken) {
          print("OTP Code sent successfully. Verification ID: $verificationId");
          if (mounted) {
            setState(() { isLoading = false; });
            // --- Navigate to OTPScreen (from otp_screen.dart) ---
            Navigator.push( context, MaterialPageRoute( builder: (context) => OTPScreen(
              verificationId: verificationId, // Pass the actual ID
              phoneNumber: fullPhoneNumber,
              role: widget.role, // Pass the role
            ), ), );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("Code auto-retrieval timed out for ID: $verificationId");
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print("Error verifying phone number: $e");
      if (mounted) setState(() { isLoading = false; errorMessage = "An error occurred. Please check network or try again."; });
    }
  }

  // --- Check Profile / Navigate (Copied from OTPScreen logic for auto-verify case) ---
  Future<void> _checkProfileAndNavigateAfterSignIn(BuildContext context, User? user, String role) async {
    if (!mounted || user == null) { if(mounted) setState(() => errorMessage = "Authentication Failed."); return; }
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDocSnap = await userDocRef.get();
    bool profileHasName = userDocSnap.exists && (userDocSnap.data() as Map?)?.containsKey('name') == true && (userDocSnap.data() as Map)['name'] != null && (userDocSnap.data() as Map)['name'].isNotEmpty;

    // Ensure role is set
    await userDocRef.set({'role': role, 'phoneNumber': user.phoneNumber}, SetOptions(merge: true));

    if (profileHasName) {
      if (mounted) { if (role == 'counselor') { Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const CounselorDashboardPlaceholder()), (route) => false); } else { Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const MainNavigationShell()), (route) => false); } }
    } else {
      if (mounted) { Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => SecondScreen(role: role))); }
    }
  }
  // --- End Check Profile ---


  @override
  Widget build(BuildContext context) {
    // Get theme data
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    // Use theme gradient for background
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.7);

    // Set status bar style based on gradient
    SystemChrome.setSystemUIOverlayStyle( ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark );

    return Scaffold(
      resizeToAvoidBottomInset: true, // Allow resize for keyboard
      // Use gradient background
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Center( // Center the content vertically
            child: SingleChildScrollView( // Allow scrolling if keyboard appears
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button (Optional - if coming from Role Selection)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding( // Add padding around button
                      padding: const EdgeInsets.only(top: 0, bottom: 10),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: onGradientColor.withOpacity(0.8), size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  // Lottie Logo
                  SizedBox( height: 140, width: 140, child: Lottie.asset(_lottieLogoAsset, fit: BoxFit.contain), ),
                  const SizedBox(height: 40),

                  // Title
                  Text( "Enter Your Phone", style: TextStyle( fontSize: 26, fontWeight: FontWeight.bold, color: onGradientColor, fontFamily: _primaryFontFamily ), ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text( "We'll send a verification code to confirm it's you.", style: TextStyle( fontSize: 16, color: onGradientMutedColor, fontFamily: _primaryFontFamily, height: 1.4 ), textAlign: TextAlign.center, ),
                  const SizedBox(height: 40),

                  // --- Themed Phone field ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18), // Padding inside container
                    decoration: BoxDecoration(
                      color: onGradientColor.withOpacity(0.1), // Subtle background
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: onGradientColor.withOpacity(0.2)), // Subtle border
                    ),
                    child: Row(
                        children: [
                          Text( // Country Code Prefix
                            countryCode,
                            style: TextStyle(fontSize: 18, color: onGradientColor, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 10),
                          // Vertical Divider (optional visual separation)
                          Container(height: 25, width: 1, color: onGradientColor.withOpacity(0.2)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(fontSize: 18, color: onGradientColor, fontFamily: _primaryFontFamily, letterSpacing: 1.5),
                              decoration: InputDecoration(
                                hintText: "Phone Number",
                                hintStyle: TextStyle(fontSize: 18, color: onGradientMutedColor, fontFamily: _primaryFontFamily, letterSpacing: 0), // Reset letter spacing for hint
                                border: InputBorder.none, // Remove default underline
                                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                              ),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                        ]
                    ),
                  ),
                  // --- End Themed Phone field ---

                  // Error message
                  if (errorMessage != null) Padding( padding: const EdgeInsets.only(top: 12), child: Text( errorMessage!, style: TextStyle( color: Colors.redAccent.shade100, fontSize: 14, fontFamily: _primaryFontFamily), textAlign: TextAlign.center, ), ),
                  const SizedBox(height: 30),

                  // Continue Button (Themed)
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verifyPhoneNumber,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentTheme.cardColor.withOpacity(0.95), // White/Dark Card Color
                        foregroundColor: colorScheme.primary, // Theme Accent Text Color
                        shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15), ),
                        elevation: 3,
                      ),
                      child: isLoading
                          ? SizedBox( height: 20, width: 20, child: CircularProgressIndicator( color: colorScheme.primary, strokeWidth: 2, ), )
                          : Text( "Continue", style: TextStyle( fontSize: 17, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily ), ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Terms text (Themed)
                  Text( "By continuing, you agree to our Terms & Privacy Policy", style: TextStyle( fontSize: 12, color: onGradientMutedColor, fontFamily: _primaryFontFamily ), textAlign: TextAlign.center, ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} // End _LoginScreenState


// --- OTPScreen definition needs to be here or imported from otp_screen.dart ---
// (Make sure the OTPScreen code provided previously, which accepts 'role', is used)
// Example:
// import 'otp_screen.dart';
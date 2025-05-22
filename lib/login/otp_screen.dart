// lib/otp_screen.dart
import 'dart:async';
//import 'package:counsellorconnect/counselor/counselor_dashboard_screen.dart';
//import 'package:counsellorconnect/counselor/counselor_dashboard_screen.dart';
import 'package:counsellorconnect/counselor/counselor_main_navigation_shell.dart';
import 'package:counsellorconnect/counselor/get_counselor_information.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Import theme files
import '../theme/theme_provider.dart'; // For helpers if needed

// Import next screens
import '../onboarding/Name_screen.dart'; // Your Name Entry Screen (contains SecondScreen)
import '../main_navigation_shell.dart'; // Your Main App Shell for Users
// import 'counselor_dashboard_screen.dart'; // Import Counselor specific screen when ready

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
// --- End Constants ---

// --- Placeholder for Counselor Dashboard ---
// (Define this properly in its own file later)
class CounselorDashboardPlaceholder extends StatelessWidget {
  const CounselorDashboardPlaceholder({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Counselor Dashboard")),
      body: const Center(child: Text("Counselor UI Placeholder")),
    );
  }
}
// --- End Placeholder ---


class OTPScreen extends StatefulWidget {
  final String verificationId; // MUST be passed correctly from LoginScreen
  final String phoneNumber;
  final String role; // <-- Accept role

  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.role, // Add role to constructor
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> otpControllers = List.generate( 6, (_) => TextEditingController(), );
  final List<FocusNode> focusNodes = List.generate( 6, (_) => FocusNode(), );

  bool isLoading = false;
  String? errorMessage;

  // Timer state
  Timer? _timer;
  int _remainingTime = 60;
  bool _canResend = false;

  @override
  void initState() { super.initState(); startTimer(); }
  @override
  void dispose() { _timer?.cancel(); for (var c in otpControllers) { c.dispose(); } for (var f in focusNodes) { f.dispose(); } super.dispose(); }

  void startTimer() { _canResend = false; _remainingTime = 60; _timer?.cancel(); _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (!mounted) { timer.cancel(); return; } if (_remainingTime > 0) { setState(() => _remainingTime--); } else { setState(() => _canResend = true); timer.cancel(); } }); }

  String get otpCode => otpControllers.map((e) => e.text).join();

  // --- Verify OTP, Check Profile, Save Role, and Navigate (UPDATED LOGIC) ---
  Future<void> _verifyOtp() async {
    if (otpCode.length != 6) { if (mounted) setState(() => errorMessage = "Please enter all 6 digits"); return; }
    if (isLoading) return;
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    setState(() { isLoading = true; errorMessage = null; });

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId, // Use the actual verification ID passed in
        smsCode: otpCode,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null && mounted) {
        print("OTP Verified for user: ${user.uid}, Role chosen: ${widget.role}");

        // Define user document reference
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        // Save/Update Role and Phone Number first (using merge)
        print("Saving/Updating role: ${widget.role} for user ${user.uid}");
        try {
          await userDocRef.set(
              {'role': widget.role, 'phoneNumber': user.phoneNumber}, // Save/update role and phone
              SetOptions(merge: true) // Merge with existing data
          );
          print("Role saved/updated successfully.");
        } catch (e) {
          print("Error saving role to Firestore: $e");
          // Decide how to handle this error - maybe still proceed but log it?
          if (mounted) {
            // Keep existing error message logic below for critical auth failures
          }
        }

        // Check if User Profile Has Name
        final userDocSnap = await userDocRef.get();
        bool profileHasName = userDocSnap.exists &&
            (userDocSnap.data() as Map?)?.containsKey('name') == true &&
            (userDocSnap.data() as Map)['name'] != null &&
            (userDocSnap.data() as Map)['name'].isNotEmpty;

        if (profileHasName) {
          // Profile complete -> Navigate based on role
          print("User profile complete, navigating based on role.");
          if (mounted) {
            if (widget.role == 'counselor') {
              print("Navigating to Counselor Dashboard Placeholder");
              Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const CounselorMainNavigationShell()), (Route<dynamic> route) => false, );
            } else {
              print("Navigating to MainNavigationShell");
              Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const MainNavigationShell()), (Route<dynamic> route) => false, );
            }
          }
        } else {
          // Profile incomplete -> Go to Name Screen, PASSING role
          print("User profile incomplete, navigating to Name Screen.");
          if (mounted) {
            // Role was already set above
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => SecondScreen(role: widget.role)), // Pass role
            );
          }
        }
      } else { if (mounted) setState(() => errorMessage = "Authentication Failed. User not found."); }
    } on FirebaseAuthException catch (e) { if(mounted) setState(() => errorMessage = e.message ?? "Invalid code or error occurred."); }
    catch (e) { if(mounted) setState(() => errorMessage = "An unknown error occurred: $e"); }
    finally { if(mounted) setState(() => isLoading = false); }
  }
  // --- End Verify OTP ---


  // --- Resend Code Logic ---
  Future<void> _resendCode() async {
    if (!_canResend || isLoading) return;
    setState(() { isLoading = true; errorMessage = null; });
    print("Resend code requested for ${widget.phoneNumber}");
    // IMPORTANT: Implement actual resend logic by calling verifyPhoneNumber again
    // This likely involves going back or using a callback to the LoginScreen
    await Future.delayed(const Duration(seconds: 1)); // Simulate only
    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resend request sent (implement actual logic)."))
      );
      startTimer(); // Restart timer visually
      setState(() { isLoading = false; });
    }
    // Consider Navigator.pop(context);
  }
  // --- End Resend Code ---


  // --- BUILD METHOD (Styled) ---
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    // Use theme gradient
    final Gradient backgroundGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topCenter, end: Alignment.bottomCenter);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    final Color onGradientMutedColor = onGradientColor.withOpacity(0.7);

    SystemChrome.setSystemUIOverlayStyle( ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark );

    return Scaffold(
      // Apply gradient background via Container
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align( // Back Button
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: onGradientColor.withOpacity(0.8), size: 20),
                      onPressed: isLoading ? null : () => Navigator.pop(context), // Disable during load
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Icon
                  Container( padding: const EdgeInsets.all(20), decoration: BoxDecoration( color: onGradientColor.withOpacity(0.1), shape: BoxShape.circle, ), child: Icon( Icons.sms_outlined, size: 45, color: onGradientColor, ), ),
                  const SizedBox(height: 32),
                  // Heading
                  Text( "OTP Verification", style: TextStyle( fontSize: 26, fontWeight: FontWeight.bold, color: onGradientColor, fontFamily: _primaryFontFamily ), ),
                  const SizedBox(height: 12),
                  // Subtitle
                  Padding( padding: const EdgeInsets.symmetric(horizontal: 16), child: Text( "Enter the 6-digit code sent to ${widget.phoneNumber}", style: TextStyle( fontSize: 16, color: onGradientMutedColor, fontFamily: _primaryFontFamily ), textAlign: TextAlign.center, ), ),
                  const SizedBox(height: 40),
                  // OTP Fields
                  Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate( 6, (index) => _buildOtpField(index, context, onGradientColor), ), ),
                  // Error message
                  if (errorMessage != null) Padding( padding: const EdgeInsets.only(top: 20), child: Text( errorMessage!, style: TextStyle( color: Colors.redAccent.shade100, fontSize: 14, fontFamily: _primaryFontFamily), textAlign: TextAlign.center, ), ),
                  const SizedBox(height: 32),
                  // Verify button
                  SizedBox( width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom( backgroundColor: currentTheme.cardColor.withOpacity(0.95), foregroundColor: colorScheme.primary, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15), ), elevation: 3, ),
                      child: isLoading ? SizedBox( height: 20, width: 20, child: CircularProgressIndicator( color: colorScheme.primary, strokeWidth: 2, ), ) : const Text( "Verify", style: TextStyle( fontSize: 17, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily ), ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Resend code
                  Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Text( "Didn't receive code? ", style: TextStyle( color: onGradientMutedColor, fontSize: 14, fontFamily: _primaryFontFamily ), ), _canResend ? TextButton( onPressed: isLoading ? null : _resendCode, child: Text( "Resend Code", style: TextStyle( fontWeight: FontWeight.bold, fontSize: 14, fontFamily: _primaryFontFamily, color: onGradientColor), ), ) : Text( "Resend in $_remainingTime s", style: TextStyle( color: onGradientMutedColor, fontSize: 14, fontFamily: _primaryFontFamily ), ), ], ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build OTP field (Styled)
  Widget _buildOtpField(int index, BuildContext context, Color onGradientColor) {
    final theme = Theme.of(context);
    final bool isLight = theme.brightness == Brightness.light;

    return Container(
      width: 48, height: 56,
      decoration: BoxDecoration( color: onGradientColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: onGradientColor.withOpacity(0.2)), ),
      child: Center( child: TextField( controller: otpControllers[index], focusNode: focusNodes[index], textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 1, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: onGradientColor, fontFamily: _primaryFontFamily), decoration: const InputDecoration( counterText: "", border: InputBorder.none, contentPadding: EdgeInsets.zero, ), inputFormatters: [ FilteringTextInputFormatter.digitsOnly, ], onChanged: (value) { if (value.isNotEmpty && index < 5) { FocusScope.of(context).requestFocus(focusNodes[index + 1]); } else if (value.isEmpty && index > 0) { FocusScope.of(context).requestFocus(focusNodes[index - 1]); } if (index == 5 && value.isNotEmpty && otpCode.length == 6 && !isLoading) { _verifyOtp(); } }, ), ), );
  }

} // End _OTPScreenState
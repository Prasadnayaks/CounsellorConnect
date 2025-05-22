// lib/get_counselor_information.dart
//import 'package:counsellorconnect/counselor/counselor_dashboard_screen.dart';
import 'package:counsellorconnect/counselor/counselor_main_navigation_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import theme files
import '../theme/theme_provider.dart';
// Import Counselor Dashboard (placeholder or real)
//import '../login/Phone_Auth.dart'; // Assuming CounselorDashboardPlaceholder is here
// import 'counselor/counselor_dashboard_screen.dart'; // Import real dashboard when ready

const String _primaryFontFamily = 'Nunito';

class GetCounselorInformationScreen extends StatefulWidget {
  const GetCounselorInformationScreen({Key? key}) : super(key: key);

  @override
  State<GetCounselorInformationScreen> createState() => _GetCounselorInformationScreenState();
}

class _GetCounselorInformationScreenState extends State<GetCounselorInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _specializationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _photoUrlController = TextEditingController(); // Optional photo URL

  bool _isSaving = false;
  String? _userName; // To fetch and potentially save with counselor profile
  User? _currentUser;

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserName(); // Get the name saved on the previous screen
  }

  @override
  void dispose() {
    _specializationController.dispose();
    _descriptionController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  // Fetch user name (saved in the previous step)
  Future<void> _fetchUserName() async {
    if (_currentUser == null || !mounted) return;
    try {
      final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted && doc.exists && (doc.data() as Map).containsKey('name')) {
        setState(() { _userName = (doc.data()! as Map)['name']; });
      } else if (mounted) {
        setState(() { _userName = "Counselor"; }); // Fallback name
      }
    } catch (e) {
      print("Error fetching user name for counselor profile: $e");
      if (mounted) setState(() { _userName = "Counselor"; });
    }
  }

  // Save counselor details to 'counselors' collection
  Future<void> _saveCounselorDetails() async {
    if (!_formKey.currentState!.validate() || _isSaving || _currentUser == null) {
      return;
    }
    setState(() { _isSaving = true; });

    final counselorData = {
      'name': _userName ?? 'Counselor Name', // Use fetched name
      'specialization': _specializationController.text.trim(),
      'description': _descriptionController.text.trim(),
      'photoUrl': _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(), // Store null if empty
      'userId': _currentUser!.uid, // Link to the auth user ID
      'profileCreatedAt': FieldValue.serverTimestamp(),
      // Add other fields like qualifications, experience, etc. here
    };

    try {
      print("Saving counselor details to /counselors/${_currentUser!.uid}");
      // Use the user's UID as the document ID in the counselors collection
      await _firestore.collection('counselors').doc(_currentUser!.uid).set(counselorData);

      print("Counselor details saved successfully.");
      if (mounted) {
        // Navigate to Counselor Dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CounselorMainNavigationShell()), // Go to actual dashboard later
              (Route<dynamic> route) => false,
        );
      }

    } catch (e) {
      print("Error saving counselor details: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving details: ${e.toString()}")));
        setState(() { _isSaving = false; });
      }
    }
    // No finally needed if navigating on success
  }

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
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView( // Allow content to scroll
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    "Counselor Details",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: onGradientColor, fontFamily: _primaryFontFamily),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Please provide some additional information for your counselor profile.",
                    style: TextStyle(fontSize: 16, color: onGradientMutedColor, fontFamily: _primaryFontFamily, height: 1.4),
                  ),
                  const SizedBox(height: 40),

                  // Specialization Field
                  TextFormField(
                    controller: _specializationController,
                    style: TextStyle(color: onGradientColor, fontFamily: _primaryFontFamily, fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    decoration: _buildInputDecoration(context, "Specialization (e.g., Stress & Anxiety)", onGradientColor, onGradientMutedColor),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your specialization' : null,
                  ),
                  const SizedBox(height: 25),

                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: onGradientColor, fontFamily: _primaryFontFamily, fontSize: 16, height: 1.4),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 3,
                    decoration: _buildInputDecoration(context, "Brief Description (Bio)", onGradientColor, onGradientMutedColor),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a brief description' : null,
                  ),
                  const SizedBox(height: 25),

                  // Photo URL Field (Optional)
                  TextFormField(
                    controller: _photoUrlController,
                    style: TextStyle(color: onGradientColor, fontFamily: _primaryFontFamily, fontSize: 16),
                    keyboardType: TextInputType.url,
                    decoration: _buildInputDecoration(context, "Profile Photo URL (Optional)", onGradientColor, onGradientMutedColor),
                    // No validator for optional field
                  ),
                  const SizedBox(height: 40),

                  // Save Button
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveCounselorDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentTheme.cardColor.withOpacity(0.95), // White/Dark Card Color
                        foregroundColor: colorScheme.primary, // Theme Accent Text Color
                        shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(15), ),
                        elevation: 3,
                      ),
                      child: _isSaving
                          ? SizedBox( height: 20, width: 20, child: CircularProgressIndicator( color: colorScheme.primary, strokeWidth: 2, ), )
                          : const Text( "Save Details & Continue", style: TextStyle( fontSize: 17, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily ), ),
                    ),
                  ),
                  const SizedBox(height: 20), // Bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper for InputDecoration
  InputDecoration _buildInputDecoration(BuildContext context, String hintText, Color onGradientColor, Color onGradientMutedColor) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: onGradientMutedColor, fontSize: 16, fontFamily: _primaryFontFamily),
      fillColor: onGradientColor.withOpacity(0.08),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder( borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none, ),
      enabledBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none, ),
      focusedBorder: OutlineInputBorder( // Add a subtle border on focus
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
      ),
    );
  }

}
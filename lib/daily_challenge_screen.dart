import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For displaying uploaded image

import '../theme/theme_provider.dart';
import '../widgets/bouncing_widget.dart'; // If you use it for buttons

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
// IMPORTANT: You will provide these asset paths
const String _mountainImageWithFlag = 'assets/images/mountain_simple.png'; // For screen 1 & 2
const String _mountainImageSimple = 'assets/images/mountain_simple.png'; // For screen 3 & 4 (or same)
const String _challengeCompleteImageAsset = 'assets/images/challenge_complete_icon (2).png'; // Optional: for splash screen top if no user photo

// --- Challenge Data ---
class Challenge {
  final String id;
  final String description;

  Challenge({required this.id, required this.description});
}

// Place this class definition in your daily_challenge_screen.dart or a shared utils file
class EnhancedDelayedAnimation extends StatefulWidget {
  final Widget child;
  final int delay;
  final Offset offsetBegin;
  final Offset offsetEnd;
  final Duration duration;
  final Curve curve;

  const EnhancedDelayedAnimation({
    Key? key,
    required this.child,
    required this.delay,
    this.offsetBegin = const Offset(0, 0.1), // Default: slight slide from bottom
    this.offsetEnd = Offset.zero,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic, // A smooth easing curve
  }) : super(key: key);

  @override
  _EnhancedDelayedAnimationState createState() => _EnhancedDelayedAnimationState();
}

class _EnhancedDelayedAnimationState extends State<EnhancedDelayedAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slideIn = Tween<Offset>(begin: widget.offsetBegin, end: widget.offsetEnd)
        .animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideIn,
      child: FadeTransition(
        opacity: _fadeIn,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

final List<Challenge> _allChallenges = [
  Challenge(id: 'c1', description: 'Today I will make a doctor or dentist appointment for that "issue" I have been putting off.'),
  Challenge(id: 'c2', description: 'Spend 15 minutes tidying up one area of your home or workspace.'),
  Challenge(id: 'c3', description: 'Reach out to a friend or family member you haven\'t spoken to in a while.'),
  Challenge(id: 'c4', description: 'Drink 8 glasses of water today.'),
  Challenge(id: 'c5', description: 'Go for a 20-minute walk outside.'),
  Challenge(id: 'c6', description: 'Write down 3 things you are grateful for.'),
  Challenge(id: 'c7', description: 'Read a chapter of a book or an interesting article.'),
  Challenge(id: 'c8', description: 'Do a 10-minute guided meditation or mindfulness exercise.'),
  Challenge(id: 'c9', description: 'Learn one new thing today (a word, a fact, a skill).'),
  Challenge(id: 'c10', description: 'Compliment a stranger or a colleague.'),
  Challenge(id: 'c11', description: 'Prepare a healthy meal for yourself from scratch.'),
  Challenge(id: 'c12', description: 'Avoid sugary drinks for the entire day.'),
  Challenge(id: 'c13', description: 'Dedicate 30 minutes to a hobby you enjoy.'),
  Challenge(id: 'c14', description: 'List 5 positive affirmations and repeat them throughout the day.'),
];

// --- Enum for Screen State ---
enum ChallengeScreenState {
  loading,
  showChallenge,
  challengeAccepted,
  uploadPhoto,
  submittingPhoto, // New state for loading during submission
  challengeCompleteSplash,
}

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({Key? key}) : super(key: key);

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  ChallengeScreenState _currentScreenState = ChallengeScreenState.loading;
  Challenge? _currentChallenge;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 1)); // Default, will be updated
  Duration _timeRemaining = const Duration(hours: 24);
  Timer? _timer;

  File? _imageFileForUpload; // For the photo to be uploaded
  String? _uploadedPhotoUrlForSplash; // To pass to splash screen
  final ImagePicker _picker = ImagePicker();
  bool _isProcessingAction = false; // General flag for button presses

  User? _currentUser;
  String? _userName;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference? _dailyChallengeDocRef;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadInitialChallengeState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialChallengeState() async {
    if (_currentUser == null) {
      if (mounted) Navigator.of(context).pop(); // Should not happen if screen is protected
      return;
    }
    setState(() => _currentScreenState = ChallengeScreenState.loading);
    await _fetchUserName();

    final today = DateTime.now();
    final todayDateString = DateFormat('yyyy-MM-dd').format(today);
    _dailyChallengeDocRef = _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('dailyChallenges')
        .doc(todayDateString);

    final docSnapshot = await _dailyChallengeDocRef!.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      _currentChallenge = _allChallenges.firstWhere((c) => c.id == data['challengeId'], orElse: () => _getRandomChallenge());
      _expiresAt = (data['expiresAt'] as Timestamp? ?? Timestamp.fromDate(DateTime(today.year, today.month, today.day, 23, 59, 59))).toDate();
      final status = data['status'] as String? ?? 'not_started';

      if (status == 'completed') {
        _uploadedPhotoUrlForSplash = data['photoUrl'] as String?;
        _currentScreenState = ChallengeScreenState.challengeCompleteSplash;
      } else if (status == 'started') {
        _currentScreenState = ChallengeScreenState.uploadPhoto;
      } else { // not_started or expired
        // If expired and not_started, treat as new for today
        if (_isExpired(_expiresAt) && status == 'not_started') {
          _currentChallenge = _getRandomChallenge();
          _expiresAt = DateTime(today.year, today.month, today.day, 23, 59, 59);
          // No need to write to Firebase yet, will happen on accept
          _currentScreenState = ChallengeScreenState.showChallenge;
        } else {
          _currentScreenState = ChallengeScreenState.showChallenge;
        }
      }
    } else {
      // No challenge document for today, set up a new one (but don't save yet)
      _currentChallenge = _getRandomChallenge();
      _expiresAt = DateTime(today.year, today.month, today.day, 23, 59, 59);
      _currentScreenState = ChallengeScreenState.showChallenge;
    }

    _updateTimeRemaining();
    _startTimer();
    if (mounted) setState(() {});
  }

  bool _isExpired(DateTime expiryDate) {
    return DateTime.now().isAfter(expiryDate);
  }

  Challenge _getRandomChallenge() {
    final random = Random();
    return _allChallenges[random.nextInt(_allChallenges.length)];
  }

  Future<void> _fetchUserName() async {
    // Simplified username fetching
    _userName = _currentUser?.displayName ?? "User";
    if (_userName == "User" || _userName!.isEmpty) {
      try {
        final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (mounted && userDoc.exists) {
          _userName = (userDoc.data() as Map<String, dynamic>?)?['name'] as String? ?? 'User';
        }
      } catch (e) { /* ignore */ }
    }
    if (mounted) setState(() {});
  }

  void _updateTimeRemaining() {
    final now = DateTime.now();
    if (now.isBefore(_expiresAt)) {
      _timeRemaining = _expiresAt.difference(now);
    } else {
      _timeRemaining = Duration.zero;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateTimeRemaining();
      if (_timeRemaining.inSeconds <= 0) {
        timer.cancel();
        // Handle expiration if needed (e.g., update UI or Firebase status)
      }
      setState(() {});
    });
  }

  Future<void> _acceptAndStartChallenge() async {
    if (_dailyChallengeDocRef == null || _currentChallenge == null || _currentUser == null) return;
    setState(() => _isProcessingAction = true);
    try {
      final today = DateTime.now();
      final todayDateString = DateFormat('yyyy-MM-dd').format(today);
      // Ensure expiresAt is set for today if it wasn't already from an existing doc
      if(_dailyChallengeDocRef != null && !(await _dailyChallengeDocRef!.get()).exists) {
        _expiresAt = DateTime(today.year, today.month, today.day, 23, 59, 59);
      }

      await _dailyChallengeDocRef!.set({ // Use set with merge:true or just set if new
        'challengeId': _currentChallenge!.id,
        'assignedDate': todayDateString,
        'status': 'started',
        'expiresAt': Timestamp.fromDate(_expiresAt),
        'startedAt': FieldValue.serverTimestamp(),
        'userId': _currentUser!.uid, // Good to have for queries
        'challengeDescription': _currentChallenge!.description, // Store description
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge true in case a doc was created by _loadInitialChallengeState

      if (mounted) {
        setState(() {
          _currentScreenState = ChallengeScreenState.challengeAccepted;
          _isProcessingAction = false;
        });
      }
    } catch (e) {
      print("Error accepting challenge: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to start challenge: ${e.toString()}")));
      setState(() => _isProcessingAction = false);
    }
  }

  void _confirmStartAndPop() {
    // Status already saved in _acceptAndStartChallenge
    if (mounted) {
      Navigator.of(context).pop(); // Pop back to HomeScreen
    }
  }

  Future<void> _pickImageForUpload() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1080);
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFileForUpload = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not pick image: ${e.toString()}")));
    }
  }

  Future<void> _submitChallengeWithPhoto() async {
    if (_imageFileForUpload == null || _dailyChallengeDocRef == null || _currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add a photo to complete the challenge.")));
      return;
    }
    setState(() {
      _isProcessingAction = true;
      _currentScreenState = ChallengeScreenState.submittingPhoto; // Show loading for submission
    });

    try {
      String fileName = 'challenge_photos/${_currentUser!.uid}/${_dailyChallengeDocRef!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(_imageFileForUpload!);
      TaskSnapshot snapshot = await uploadTask;
      _uploadedPhotoUrlForSplash = await snapshot.ref.getDownloadURL();

      await _dailyChallengeDocRef!.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'photoUrl': _uploadedPhotoUrlForSplash,
      });

      if (mounted) {
        setState(() {
          _currentScreenState = ChallengeScreenState.challengeCompleteSplash;
          _isProcessingAction = false;
        });
      }
    } catch (e) {
      print("Error submitting challenge with photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to submit: ${e.toString()}")));
        setState(() {
          _currentScreenState = ChallengeScreenState.uploadPhoto; // Revert to upload screen on error
          _isProcessingAction = false;
        });
      }
    }
  }

  Widget _buildTopBar(BuildContext context, ThemeData theme, Color onGradientColor, {bool showDate = true}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, left: 16, right: 16, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showDate)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Daily Challenge", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 20, fontWeight: FontWeight.bold, color: onGradientColor)),
                Text(DateFormat('EEEE, MMMM d').format(DateTime.now()), style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 12, color: onGradientColor.withOpacity(0.8))),
              ],
            )
          else
            const SizedBox(width: 40), // Placeholder for balance if no date
          IconButton(
            icon: Icon(Icons.close, color: onGradientColor, size: 26),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }


  // --- UI Build Methods ---
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    SystemChrome.setSystemUIOverlayStyle(
        ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeProvider.currentAccentGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _buildCurrentScreenView(theme),
        ),
      ),
    );
  }

  Widget _buildCurrentScreenView(ThemeData theme) {
    switch (_currentScreenState) {
      case ChallengeScreenState.loading:
      case ChallengeScreenState.submittingPhoto: // Use same loading for submission
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case ChallengeScreenState.showChallenge:
        return _buildShowChallengeView(theme);
      case ChallengeScreenState.challengeAccepted:
        return _buildChallengeAcceptedView(theme);
      case ChallengeScreenState.uploadPhoto:
        return _buildUploadPhotoView(theme);
      case ChallengeScreenState.challengeCompleteSplash:
        return _buildChallengeCompleteSplashView(theme);
      default:
        return Center(child: Text("An error occurred.", style: TextStyle(color: Colors.white, fontFamily: _primaryFontFamily)));
    }
  }

  // --- Screen 1: Show Challenge UI ---
  Widget _buildShowChallengeView(ThemeData theme) {
    String hours = _timeRemaining.inHours.toString().padLeft(2, '0');
    String minutes = (_timeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(Provider.of<ThemeProvider>(context, listen: false).currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;

    return Column(
      children: [
        _buildTopBar(context, theme, onGradientColor),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Image.asset(_mountainImageWithFlag, height: 450, errorBuilder: (c,e,s) => Icon(Icons.landscape, size: 100, color: onGradientColor.withOpacity(0.5))),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, color: onGradientColor, size: 18),
                      const SizedBox(width: 8),
                      Text( "ENDS IN $hours:$minutes:$seconds", style: TextStyle(fontFamily: _primaryFontFamily, color: onGradientColor, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _currentChallenge?.description ?? "Loading challenge...",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 18, color: onGradientColor, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isProcessingAction ? null : _acceptAndStartChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isProcessingAction
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text("ACCEPT CHALLENGE", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Screen 2: Challenge Accepted UI ---
  Widget _buildChallengeAcceptedView(ThemeData theme) {
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(Provider.of<ThemeProvider>(context, listen: false).currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;
    String hoursStr = _timeRemaining.inHours.toString().padLeft(2,'0');
    String minutesStr = (_timeRemaining.inMinutes % 60).toString().padLeft(2,'0');
    String secondsStr = (_timeRemaining.inSeconds % 60).toString().padLeft(2,'0');
    String timeMessage = "You've got $hoursStr:$minutesStr:$secondsStr to complete today's challenge.";
    if (_timeRemaining.inHours == 0 && _timeRemaining.inMinutes > 0) {
      timeMessage = "You've got $minutesStr minutes and $secondsStr seconds left!";
    } else if (_timeRemaining.inSeconds <= 0) {
      timeMessage = "Time's up for this challenge!";
    }


    return Column(
      children: [
        _buildTopBar(context, theme, onGradientColor, showDate: false), // No date here
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Good luck, ${_userName ?? 'User'}!", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 24, fontWeight: FontWeight.bold, color: onGradientColor)),
                const SizedBox(height: 20),
                Text(timeMessage, textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 17, color: onGradientColor.withOpacity(0.9), height: 1.4)),
                const SizedBox(height: 15),
                Text("... and remember, pics or it didn't happen!", textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 17, color: onGradientColor.withOpacity(0.9), fontStyle: FontStyle.italic, height: 1.4)),
                const Spacer(),
                Opacity(
                    opacity: 0.6,
                    child: Image.asset(_mountainImageWithFlag, height: 450, errorBuilder: (c,e,s) => Icon(Icons.landscape, size: 80, color: onGradientColor.withOpacity(0.3)))
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isProcessingAction ? null : _confirmStartAndPop,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isProcessingAction
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text("I GOT THIS", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Screen 3: Upload Photo UI ---
  Widget _buildUploadPhotoView(ThemeData theme) {
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(Provider.of<ThemeProvider>(context, listen: false).currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;

    return Column(
      children: [
        _buildTopBar(context, theme, onGradientColor),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Text(
                    _currentChallenge?.description ?? "Loading challenge...",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 18, color: onGradientColor, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                GestureDetector(
                  onTap: _pickImageForUpload,
                  child: Container(
                    height: MediaQuery.of(context).size.width * 0.65, // Slightly larger
                    width: MediaQuery.of(context).size.width * 0.65,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15), // More transparent
                      borderRadius: BorderRadius.circular(20), // Less rounded for "squared transparent card"
                      // No border for truly transparent card feel around image
                    ),
                    child: _imageFileForUpload != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(_imageFileForUpload!, fit: BoxFit.cover))
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: onGradientColor.withOpacity(0.8), size: 48),
                        const SizedBox(height: 12),
                        Text("Add Photo", style: TextStyle(fontFamily: _primaryFontFamily, color: onGradientColor.withOpacity(0.8), fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Opacity(
                    opacity: 0.7,
                    child: Image.asset(_mountainImageSimple, height: 450, errorBuilder: (c,e,s) => Icon(Icons.landscape, size: 70, color: onGradientColor.withOpacity(0.3)))
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isProcessingAction || _imageFileForUpload == null ? null : _submitChallengeWithPhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                disabledBackgroundColor: Colors.white.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isProcessingAction
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(_imageFileForUpload == null ? "ADD PHOTO" : "SUBMIT CHALLENGE", style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Screen 4: Challenge Complete Splash UI ---
  // In daily_challenge_screen.dart, inside _DailyChallengeScreenState class

// Ensure this constant is defined at the top of your file or is accessible
// const String _challengeCompleteImageAsset = 'assets/images/challenge_complete_icon.png';

// --- Screen 4: Challenge Complete Splash UI (Revised) ---
  Widget _buildChallengeCompleteSplashView(ThemeData theme) {
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(
        Provider.of<ThemeProvider>(context, listen: false)
            .currentAccentGradient
            .first) ==
        Brightness.dark
        ? Colors.white
        : Colors.black87;

    // Auto-pop after a few seconds
    // You can make this duration longer for a more noticeable "splash"
    Future.delayed(const Duration(milliseconds: 3500), () { // Adjusted duration
      if (mounted &&
          _currentScreenState == ChallengeScreenState.challengeCompleteSplash) {
        Navigator.of(context).pop();
      }
    });

    // For a "smooth splash", we can use an AnimatedSwitcher
    // or simply animate the opacity and scale of the content.
    // Here, we'll wrap the content in an EnhancedDelayedAnimation
    // if you have that utility, or a simple FadeTransition.

    return PopScope( // Use PopScope to prevent accidental back navigation during splash
      canPop: false, // User must use the button or wait for auto-dismiss
      child: EnhancedDelayedAnimation( // Assuming you have this from home_screen.dart or similar
        delay: 100, // Short delay for animation to start
        duration: const Duration(milliseconds: 800), // Duration of the fade/scale
        offsetBegin: const Offset(0, 0.1), // Slight upward slide
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              "Great! You have completed the challenge.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: _primaryFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onGradientColor,
                  height: 1.3),
            ),
            const SizedBox(height: 35), // Increased spacing
            // The generic completion icon/image
            Image.asset(
              _challengeCompleteImageAsset, // Use the generic completion asset
              height: 350, // Adjust size as needed
              width: 350,
              fit: BoxFit.contain, // Ensure the whole image is visible
              errorBuilder: (context, error, stackTrace) {
                print('Error loading challenge complete asset: $error');
                // Fallback if the asset is missing
                return Icon(Icons.check_circle_outline_rounded,
                    size: 100, color: onGradientColor.withOpacity(0.9));
              },
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
              child: BouncingWidget( // Wrap ElevatedButton with BouncingWidget
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: ElevatedButton(
                  onPressed: null, // BouncingWidget handles tap
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.colorScheme.primary,
                    minimumSize: const Size(double.infinity, 55), // Ensure button is large enough
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("AWESOME!",
                      style: TextStyle(
                          fontFamily: _primaryFontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
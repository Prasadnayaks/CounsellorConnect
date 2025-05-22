// lib/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert'; // For jsonDecode
import 'package:cached_network_image/cached_network_image.dart';

// Firebase imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import theme files
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart'; // Import AppThemeType

// Import other necessary screen files
import 'profile_screen.dart';
import 'thoughts_screen.dart';
import 'models/quote_model.dart'; // For daily quote
import 'mood_checkin/mood_checkin_screen.dart';
import 'daily_challenge_screen.dart';
import 'truth_screen.dart';

// --- EnhancedDelayedAnimation Helper Widget ---
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
    this.offsetBegin = const Offset(0, 0.1),
    this.offsetEnd = Offset.zero,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.easeOutQuart,
  }) : super(key: key);

  @override
  _EnhancedDelayedAnimationState createState() =>
      _EnhancedDelayedAnimationState();
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
// --- End EnhancedDelayedAnimation ---

// --- Painter Definition ---
class HomeBackgroundPainter extends CustomPainter {
  final Gradient gradient;
  const HomeBackgroundPainter({required this.gradient});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height * 0.65));
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.45)
      ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.65, size.width, size.height * 0.45)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HomeBackgroundPainter oldDelegate) =>
      oldDelegate.gradient != gradient;
}
// --- End Painter ---

// --- Placeholders & Assets ---
const String _lottieLogoAsset = 'assets/animation.json';
const String _profileIconAsset = 'assets/icons/profile_placeholder.png';
const String _truthAvatarAsset = 'assets/images/truth_avatar_placeholder.jpeg';
const String _challengeBgAsset = 'assets/images/challenge_bg_red (1).png';
const String _quoteBgAsset = 'assets/images/quote_bg_placeholder.jpeg';
const String _challengeIconAsset = 'assets/icons/mountain_placeholder.png';
const String _dailyCheckinIconAsset = 'assets/icons/daily_checkin_placeholder.png';
String? _dailyChallengeStatus = 'not_started'; // Default
String? _currentDailyChallengeText = "Tap to see today's challenge!"; // Default
DateTime? _dailyChallengeExpiresAt;
Timer? _challengeTimer;
Duration _challengeTimeRemaining = Duration.zero;
bool _isLoadingChallengeStatus = true;
String _currentChallengePngAsset = _challengeBgAsset; // This can be dynamic if needed per challenge


const Map<AppThemeType, String> _challengeCardThemeImages = {
  AppThemeType.lightBlue: 'assets/images/challenge_bg_red (1).png',
  AppThemeType.lightPurple: 'assets/images/challenge_bg_red (1).png',
  AppThemeType.lightOrange: 'assets/images/challenge_bg_red (1).png',
  AppThemeType.lightPink: 'assets/images/challenge_bg_red (1).png',
  AppThemeType.lightTeal: 'assets/images/challenge_bg_red (1).png',
  AppThemeType.lightGreen: 'assets/images/challenge_bg_red (1).png',
  AppThemeType.lightRed: 'assets/images/challenge_bg_red (1).png',
  AppThemeType.lightIndigo: 'assets/images/challenge_bg_red (1).png',
};

// --- DailyThemePrompt class and _getDailyThemePrompt function (from truth_screen.dart logic) ---
class DailyThemePrompt {
  final String theme; // This will be our "head word"
  final String promptPrefix;
  final String promptSuffix;

  DailyThemePrompt({
    required this.theme,
    required this.promptPrefix,
    this.promptSuffix = "",
  });

  String get fullPrompt => '$promptPrefix ____ $promptSuffix';
}

DailyThemePrompt _getDailyThemePrompt(DateTime date) {
  int weekday = date.weekday;
  switch (weekday) {
    case DateTime.monday:
      return DailyThemePrompt(
          theme: "Mindfulness",
          promptPrefix: "Today, I found a moment of peace when I noticed _________",
          promptSuffix: ".");
    case DateTime.tuesday:
      return DailyThemePrompt(
          theme: "Truth",
          promptPrefix: "A truth about myself I'm embracing is that I am _________",
          promptSuffix: ".");
    case DateTime.wednesday:
      return DailyThemePrompt(
          theme: "Wisdom",
          promptPrefix: "If I could tell my younger self one thing, it would be to _________",
          promptSuffix: ".");
    case DateTime.thursday:
      return DailyThemePrompt(
          theme: "Identity",
          promptPrefix: "I express my unique identity most clearly when I _________",
          promptSuffix: ".");
    case DateTime.friday:
      return DailyThemePrompt(
          theme: "Favorites",
          promptPrefix: "My favorite small joy this week has been _________",
          promptSuffix: ".");
    case DateTime.saturday:
      return DailyThemePrompt(
          theme: "Celebration",
          promptPrefix: "I celebrate my progress in _________",
          promptSuffix: ", no matter how small.");
    case DateTime.sunday:
      return DailyThemePrompt(
          theme: "Gratitude",
          promptPrefix: "I am deeply grateful for the simple gift of _________",
          promptSuffix: " today.");
    default:
      return DailyThemePrompt(
          theme: "Reflection",
          promptPrefix: "Today, I reflected on _________",
          promptSuffix: ".");
  }
}
// --- End DailyThemePrompt related code ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDateIndex = 0;
  List<Map<String, dynamic>> _weekDates = [];
  DateTime _selectedDate = DateTime.now();
  late ScrollController _scrollController;
  double _backgroundOffset = 0.0;
  final double _parallaxFactor = 0.3;

  String? _dailyQuoteText;
  String? _dailyQuoteAuthor;
  String? _dailyQuoteImageUrl;
  bool _isQuoteLoading = true;
  final math.Random _random = math.Random();
  static const String _primaryFontFamily = 'Nunito';

  // Animation Delays
  static const int _baseDelay = 400;
  static const int _bgDelay = _baseDelay;
  static const int _topBarDelay = _baseDelay + 300;
  static const int _headerDelay = _baseDelay + 600;
  static const int _dateSelectorDelay = _baseDelay + 900;
  static const int _truthCardDelay = _baseDelay + 1200;
  static const int _challengeCardDelay = _baseDelay + 1450;
  static const int _checkinCardDelay = _baseDelay + 1700;
  static const int _quoteCardDelay = _baseDelay + 1950;

  // --- State variables for Truth Card ---
  DailyThemePrompt? _currentDailyTruthPrompt;
  bool _hasRespondedToTruthToday = false;
  bool _isLoadingTruthStatus = true;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // --- End Truth Card state variables ---

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _generateWeekDates();
    _selectTodayIndex();
    _fetchDailyQuote();
    _loadDailyTruthData(); // Load data for the truth card
    _loadDailyChallengeStatus();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
    _challengeTimer?.cancel();
  }

  void _scrollListener() {
    if (!mounted || !_scrollController.hasClients || _scrollController.position.hasPixels == false) return;
    double newOffset = -_scrollController.offset * _parallaxFactor;
    if (newOffset > 0) newOffset = 0;
    if (newOffset != _backgroundOffset) {
      setState(() {
        _backgroundOffset = newOffset;
      });
    }
  }

  void _generateWeekDates() {
    _weekDates = [];
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    for (int i = 0; i < 7; i++) {
      DateTime currentDate = monday.add(Duration(days: i));
      _weekDates.add({
        'dayLabel': DateFormat('E').format(currentDate).toUpperCase(),
        'dateLabel': DateFormat('d').format(currentDate),
        'dateTime': currentDate,
      });
    }
  }

  void _selectTodayIndex() {
    DateTime today = DateTime.now();
    int todayIndex = -1;
    if (_weekDates.isNotEmpty) {
      for (int i = 0; i < _weekDates.length; i++) {
        DateTime dateInList = _weekDates[i]['dateTime'] as DateTime;
        if (dateInList.year == today.year &&
            dateInList.month == today.month &&
            dateInList.day == today.day) {
          todayIndex = i;
          break;
        }
      }
    }
    if (mounted) {
      setState(() {
        if (todayIndex != -1) {
          _selectedDateIndex = todayIndex;
          _selectedDate = _weekDates[todayIndex]['dateTime'] as DateTime;
        } else if (_weekDates.isNotEmpty) {
          _selectedDateIndex = (_weekDates.length ~/ 2);
          _selectedDate = _weekDates[_selectedDateIndex]['dateTime'] as DateTime;
        } else {
          _selectedDateIndex = 0;
          _selectedDate = DateTime.now();
        }
      });
    }
  }

  Future<void> _fetchDailyQuote() async {
    if (!mounted) return;
    setState(() => _isQuoteLoading = true);
    try {
      final String jsonString =
      await rootBundle.loadString('assets/data/thoughts.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);

      if (jsonData.isNotEmpty) {
        final randomQuoteData =
        jsonData[_random.nextInt(jsonData.length)] as Map<String, dynamic>;
        final String imageUrl =
            randomQuoteData['imageUrl'] as String? ?? _quoteBgAsset;

        if (mounted) {
          setState(() {
            _dailyQuoteText =
                randomQuoteData['text'] as String? ?? 'Stay positive.';
            _dailyQuoteAuthor =
                randomQuoteData['author'] as String? ?? 'Unknown';
            _dailyQuoteImageUrl = imageUrl;
            _isQuoteLoading = false;
          });
        }
      } else {
        throw Exception('Local thoughts.json is empty.');
      }
    } catch (e) {
      print("[HomeScreen] Error fetching daily quote from local JSON: $e");
      if (mounted) {
        setState(() {
          _dailyQuoteText = "A beautiful thought is coming soon.";
          _dailyQuoteAuthor = "";
          _dailyQuoteImageUrl = _quoteBgAsset;
          _isQuoteLoading = false;
        });
      }
    }
  }

  // --- Methods for Truth Card ---
  Future<void> _loadDailyTruthData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTruthStatus = true;
    });

    final now = DateTime.now(); // Use current date for daily prompt
    _currentDailyTruthPrompt = _getDailyThemePrompt(now);

    final User? currentUser = _auth.currentUser;
    if (currentUser != null && _currentDailyTruthPrompt != null) {
      try {
        String formattedDate = DateFormat('yyyy-MM-dd').format(now);
        String truthDocId = '${_currentDailyTruthPrompt!.theme.toLowerCase()}_$formattedDate';

        final docSnapshot = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('truthReflections') // Ensure this matches Firebase
            .doc(truthDocId)
            .get();

        if (mounted) {
          setState(() {
            _hasRespondedToTruthToday = docSnapshot.exists;
            _isLoadingTruthStatus = false;
          });
        }
      } catch (e) {
        print("Error checking Firebase for truth response: $e");
        if (mounted) {
          setState(() {
            _hasRespondedToTruthToday = false;
            _isLoadingTruthStatus = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingTruthStatus = false;
          _hasRespondedToTruthToday = false;
        });
      }
    }
  }

  void _navigateToTruthScreenOrMoodCheckin() {
    if (_hasRespondedToTruthToday) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MoodCheckinScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TruthScreen()),
      ).then((_) {
        // Refresh data when returning from TruthScreen, in case a submission was made
        _loadDailyTruthData();
      });
    }
  }
  // --- End Truth Card methods ---

  void _navigateToThoughtsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ThoughtsScreen()),
    );
  }

  void _navigateToMoodCheckinScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MoodCheckinScreen()),
    );
  }

  void _navigateToDailyChallengeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DailyChallengeScreen()),
    );
  }

  Future<void> _loadDailyChallengeStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoadingChallengeStatus = true;
    });

    final User? currentUser = _auth.currentUser; // Assuming _auth is your FirebaseAuth instance
    if (currentUser == null) {
      setState(() {
        _dailyChallengeStatus = 'not_started';
        _currentDailyChallengeText = "Tap to see today's challenge!";
        _isLoadingChallengeStatus = false;
      });
      return;
    }

    final today = DateTime.now();
    final todayDateString = DateFormat('yyyy-MM-dd').format(today);
    final challengeDocRef = _firestore // Assuming _firestore is your FirebaseFirestore instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('dailyChallenges')
        .doc(todayDateString);

    try {
      final docSnapshot = await challengeDocRef.get();
      if (mounted && docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          _dailyChallengeStatus = data['status'] as String? ?? 'not_started';
          _currentDailyChallengeText = data['challengeDescription'] as String? ?? "Embark on a new challenge!";
          _dailyChallengeExpiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
          // Potentially load a specific PNG asset if stored with challenge
          // _currentChallengePngAsset = data['challengeImageAsset'] ?? _challengeBgAsset;
          _updateChallengeTimeRemaining();
          _startChallengeTimer();
        });
      } else if (mounted) {
        setState(() {
          _dailyChallengeStatus = 'not_started';
          // If no challenge doc, we might not have specific text to show on homescreen card yet
          _currentDailyChallengeText = "A new challenge awaits!";
          _dailyChallengeExpiresAt = DateTime(today.year, today.month, today.day, 23, 59, 59);
          _updateChallengeTimeRemaining();
          _startChallengeTimer(); // Start timer even if not started, to show "ENDS IN"
        });
      }
    } catch (e) {
      print("Error loading daily challenge status: $e");
      if (mounted) {
        setState(() {
          _dailyChallengeStatus = 'not_started';
          _currentDailyChallengeText = "Challenge details unavailable.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChallengeStatus = false;
        });
      }
    }
  }

  void _updateChallengeTimeRemaining() {
    if (_dailyChallengeExpiresAt != null) {
      final now = DateTime.now();
      if (now.isBefore(_dailyChallengeExpiresAt!)) {
        _challengeTimeRemaining = _dailyChallengeExpiresAt!.difference(now);
      } else {
        _challengeTimeRemaining = Duration.zero;
        // If time is zero and status is not completed, it's effectively expired
        if (_dailyChallengeStatus != 'completed') {
          // _dailyChallengeStatus = 'expired'; // You might want an expired status
        }
      }
    } else {
      _challengeTimeRemaining = const Duration(hours: 24); // Default if no expiry time yet
    }
  }

  void _startChallengeTimer() {
    _challengeTimer?.cancel();
    _challengeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateChallengeTimeRemaining();
      if (_challengeTimeRemaining.inSeconds <= 0 && _dailyChallengeStatus != 'completed') {
        timer.cancel();
        // Optionally update UI or status if timer hits zero and not completed
      }
      setState(() {});
    });
  }

// Modify your existing _navigateToDailyChallengeScreen
  void _navigateToDailyChallengeScreenWithRefresh() {
    if (_dailyChallengeStatus == 'completed') {
      // Card is inactive, do nothing
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DailyChallengeScreen()),
    ).then((_) {
      // When returning from DailyChallengeScreen, refresh the status
      _loadDailyChallengeStatus();
    });
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Gradient currentHomeGradient = LinearGradient(
        colors: themeProvider.currentAccentGradient,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter);
    final finalTopPadding = MediaQuery.of(context).padding.top;

    SystemChrome.setSystemUIOverlayStyle(ThemeData.estimateBrightnessForColor(
        themeProvider.currentAccentGradient.first) ==
        Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: EnhancedDelayedAnimation(
              delay: _bgDelay,
              offsetBegin: const Offset(0, -0.2),
              offsetEnd: Offset.zero,
              duration: const Duration(milliseconds: 1200),
              child: Transform.translate(
                offset: Offset(0, _backgroundOffset),
                child: CustomPaint(
                  painter: HomeBackgroundPainter(gradient: currentHomeGradient),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.only(top: finalTopPadding),
            children: [
              EnhancedDelayedAnimation(
                delay: _topBarDelay,
                offsetBegin: const Offset(0, -0.2),
                child: _buildTopBarItems(context),
              ),
              const SizedBox(height: 10),
              EnhancedDelayedAnimation(
                delay: _headerDelay,
                offsetBegin: const Offset(0, -0.1),
                child: _buildHeaderContent(context),
              ),
              const SizedBox(height: 20),
              EnhancedDelayedAnimation(
                delay: _dateSelectorDelay,
                offsetBegin: const Offset(0, -0.05),
                child: _buildNewDateSelector(context),
              ),
              const SizedBox(height: 30),
              EnhancedDelayedAnimation(
                delay: _truthCardDelay,
                offsetBegin: const Offset(0, 0.35),
                child: _buildTruthCard(context), // This will use the updated logic
              ),
              const SizedBox(height: 20),
              EnhancedDelayedAnimation(
                delay: _challengeCardDelay,
                offsetBegin: const Offset(0, 0.35),
                child: _buildChallengeCard(context),
              ),
              const SizedBox(height: 20),
              EnhancedDelayedAnimation(
                delay: _checkinCardDelay,
                offsetBegin: const Offset(0, 0.35),
                child: _buildDailyCheckinCard(context),
              ),
              const SizedBox(height: 20),
              EnhancedDelayedAnimation(
                delay: _quoteCardDelay,
                offsetBegin: const Offset(0, 0.35),
                child: GestureDetector(
                    onTap: _navigateToThoughtsScreen,
                    child: _buildQuoteCard(context)),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarItems(BuildContext context) {
    final Color iconColor = Theme.of(context).colorScheme.onPrimary;
    final Color profileButtonBg =
    Theme.of(context).colorScheme.onPrimary.withOpacity(0.25);
    final double profileIconSize = 28;
    final double profileButtonPadding = 8.0;
    final double lottieSize = 135.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
      child: SizedBox(
        height: lottieSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: lottieSize,
                height: lottieSize,
                child: Lottie.asset(
                  _lottieLogoAsset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: profileButtonBg,
                borderRadius: BorderRadius.circular(12.0),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12.0),
                  child: Padding(
                    padding: EdgeInsets.all(profileButtonPadding),
                    child: Image.asset(
                      _profileIconAsset,
                      height: profileIconSize,
                      width: profileIconSize,
                      color: iconColor,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.person_outline,
                          color: iconColor,
                          size: profileIconSize),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent(BuildContext context) {
    final Color headerColor = Theme.of(context).colorScheme.onPrimary;
    String dayOfWeekDisplay = DateFormat('EEEE').format(_selectedDate);
    String monthDayDisplay = DateFormat('MMMM d').format(_selectedDate);

    DateTime now = DateTime.now();
    bool isActuallyToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isActuallyToday ? 'Today' : dayOfWeekDisplay,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: headerColor,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              fontFamily: _primaryFontFamily,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            monthDayDisplay.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: headerColor.withOpacity(0.85),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              fontSize: 12,
              fontFamily: _primaryFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewDateSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimaryColor = theme.colorScheme.onPrimary;

    double screenWidth = MediaQuery.of(context).size.width;
    double rowParentHorizontalPadding = 20.0 * 2;
    double spacingBetweenItems = 3.5 * 6;
    double availableWidthForItems =
        screenWidth - rowParentHorizontalPadding - spacingBetweenItems;
    double itemWidth = availableWidthForItems / 7;
    itemWidth = math.max(itemWidth, 36);
    double itemHeight = itemWidth * 1.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _weekDates.map((dateData) {
          DateTime currentDate = dateData['dateTime'] as DateTime;
          String dayLabel = dateData['dayLabel'] as String;
          String dateLabel = dateData['dateLabel'] as String;
          int currentIndexInList = _weekDates.indexOf(dateData);

          DateTime today = DateTime.now();
          bool isPast =
          currentDate.isBefore(DateTime(today.year, today.month, today.day));
          bool isActuallyToday = currentDate.year == today.year &&
              currentDate.month == today.month &&
              currentDate.day == today.day;
          bool isFuture = currentDate
              .isAfter(DateTime(today.year, today.month, today.day, 23, 59, 59));

          Color currentItemDateTextColor;
          Color currentItemDayLabelTextColor;
          FontWeight currentItemDateFontWeight;
          FontWeight currentItemDayLabelFontWeight;
          Widget? backgroundCardWidget;

          if (isActuallyToday) {
            currentItemDateTextColor = Colors.white;
            currentItemDayLabelTextColor = Colors.white.withOpacity(0.9);
            currentItemDateFontWeight = FontWeight.bold;
            currentItemDayLabelFontWeight = FontWeight.w600;
            backgroundCardWidget = Container(
              width: itemWidth,
              height: itemHeight,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.35),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
            );
          } else if (isPast) {
            currentItemDateTextColor = onPrimaryColor.withOpacity(0.9);
            currentItemDayLabelTextColor = onPrimaryColor.withOpacity(0.85);
            currentItemDateFontWeight = FontWeight.bold;
            currentItemDayLabelFontWeight = FontWeight.bold;
          } else {
            // isFuture
            currentItemDateTextColor = onPrimaryColor.withOpacity(0.65);
            currentItemDayLabelTextColor = onPrimaryColor.withOpacity(0.6);
            currentItemDateFontWeight = FontWeight.w500;
            currentItemDayLabelFontWeight = FontWeight.w500;
          }

          return GestureDetector(
            onTap: () {
              if (mounted) {
                setState(() {
                  _selectedDateIndex = currentIndexInList;
                  _selectedDate = currentDate;
                  // When date changes, we might need to reload daily truth data
                  _loadDailyTruthData();
                });
              }
            },
            child: SizedBox(
              width: itemWidth,
              height: itemHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (backgroundCardWidget != null && isActuallyToday)
                    backgroundCardWidget,
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel.substring(0, math.min(3, dayLabel.length)),
                        style: TextStyle(
                          color: currentItemDayLabelTextColor,
                          fontSize: itemWidth * 0.28,
                          fontWeight: currentItemDayLabelFontWeight,
                          fontFamily: _primaryFontFamily,
                        ),
                      ),
                      SizedBox(height: itemHeight * 0.04),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          color: currentItemDateTextColor,
                          fontSize: itemWidth * 0.46,
                          fontWeight: currentItemDateFontWeight,
                          fontFamily: _primaryFontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  BoxShadow _buildEnhancedShadow(BuildContext context) {
    Color shadowColor = Theme.of(context)
        .shadowColor
        .withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.15);
    return BoxShadow(
        color: shadowColor,
        blurRadius: 20,
        spreadRadius: 1,
        offset: const Offset(0, 6));
  }

  // --- Updated Truth Card ---
  // In home_screen.dart

  Widget _buildTruthCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingTruthStatus) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Card(
          clipBehavior: Clip.none,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 250), // Consistent min height
            decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [_buildEnhancedShadow(context)]),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_currentDailyTruthPrompt == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 250), // Consistent min height
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [_buildEnhancedShadow(context)]),
            child: Text("No truth prompt for today.", style: theme.textTheme.bodyMedium),
          ),
        ),
      );
    }

    // This is the main theme/headword for the card, always visible
    String cardMainTheme = _currentDailyTruthPrompt!.theme;
    // This is the subtitle for the card, always visible
    String cardMainSubtitle = "Every ${DateFormat('EEEE').format(DateTime.now())}, reflect on your ${cardMainTheme.toLowerCase()}.";
    // Customize subtitle further if needed:
    if (cardMainTheme.toLowerCase() == "truth") {
      cardMainSubtitle = "Every Tuesday, speak your truth.";
    } else if (cardMainTheme.toLowerCase() == "identity") {
      cardMainSubtitle = "Every Thursday, reflect on who you are.";
    } // etc.


    Widget interactiveContentArea; // This is the "smaller card" that changes

    if (_hasRespondedToTruthToday) {
      // "Have more to share?" section
      interactiveContentArea = Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          // Style this like the inner bar in your image
            color: theme.cardColor, // Or a slightly different shade like theme.scaffoldBackgroundColor.withOpacity(0.5)
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1), width: 0.8) // Optional border
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Have more to share?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: _primaryFontFamily,
                color: colorScheme.primary,
              ),
            ),
            Icon(Icons.add_circle_outline_rounded,
                color: colorScheme.primary,
                size: 28),
          ],
        ),
      );
    } else {
      // Question prompt section (the original "smaller card")
      interactiveContentArea = Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.5), // Original background
          borderRadius: BorderRadius.circular(15.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _currentDailyTruthPrompt!.fullPrompt, // The actual question
                style: theme.textTheme.bodyLarge?.copyWith(
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                  fontFamily: _primaryFontFamily,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7), size: 20),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GestureDetector(
        onTap: _navigateToTruthScreenOrMoodCheckin,
        child: Card(
          clipBehavior: Clip.none, // Allow avatar to pop out
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
          child: Container(
            constraints: const BoxConstraints(minHeight: 250), // Keep overall card size consistent
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(25.0),
              boxShadow: [_buildEnhancedShadow(context)],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // This Padding positions the content column below the avatar
                Padding(
                  padding: const EdgeInsets.only(top: 45.0, left: 20.0, right: 20.0, bottom: 20.0), // Avatar radius (30) + its top offset (15) = 45
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Center content vertically within the remaining space
                    mainAxisSize: MainAxisSize.min, // Important for Column within Stack if height is not fixed
                    children: [
                      const SizedBox(height: 15), // Extra space so avatar doesn't touch text
                      Text(
                        cardMainTheme, // Display the daily theme (e.g., "Truth", "Identity")
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: _primaryFontFamily,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cardMainSubtitle, // Display the daily subtitle
                        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: _primaryFontFamily),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 25), // Space before the interactive area
                      interactiveContentArea, // This is the part that changes
                    ],
                  ),
                ),
                // Positioned Avatar - This stays the same
                Positioned(
                  top: -15,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.cardColor, // So the avatar's "border" matches card
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[200],
                      foregroundImage: AssetImage(_truthAvatarAsset),
                      onForegroundImageError: (e, s) {
                        print("Error loading truth avatar asset: $e");
                      },
                      child: const Icon(Icons.error_outline), // Fallback if image fails
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // --- End Updated Truth Card ---

  // In home_screen.dart, replace the existing _buildChallengeCard method

  // In home_screen.dart, replace the existing _buildChallengeCard method

  // In home_screen.dart, replace the existing _buildChallengeCard method

  Widget _buildChallengeCard(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = theme.colorScheme;
    final Color onAccentColor = theme.colorScheme.onPrimary;

    if (_isLoadingChallengeStatus) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              color: theme.cardColor.withOpacity(0.5), // Placeholder loading look
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    String titleText = "Daily Challenge";
    String subtitleText = "TIME LEFT - 00:00:00";
    String descriptionText = _currentDailyChallengeText ?? "Tap to start your challenge!";
    Widget topLeftIconWidget = Image.asset(
      _challengeIconAsset, // Original mountain icon
      height: 22,
      width: 22,
      color: onAccentColor,
      errorBuilder: (c, e, s) => Icon(Icons.emoji_events_outlined, color: onAccentColor, size: 22),
    );

    String hoursStr = _challengeTimeRemaining.inHours.toString().padLeft(2, '0');
    String minutesStr = (_challengeTimeRemaining.inMinutes % 60).toString().padLeft(2, '0');
    String secondsStr = (_challengeTimeRemaining.inSeconds % 60).toString().padLeft(2, '0');
    subtitleText = "TIME LEFT - $hoursStr:$minutesStr:$secondsStr";


    if (_dailyChallengeStatus == 'not_started') {
      titleText = "Daily"; // Main title becomes "Daily"
      // Subtitle "Challenge" is added below "Daily"
      descriptionText = _currentDailyChallengeText ?? "A new challenge awaits!"; // This can be the actual challenge text or a placeholder
      subtitleText = "ENDS IN $hoursStr:$minutesStr:$secondsStr"; // Keep "ENDS IN" for not_started state
      // The small icon at top-left (_challengeIconAsset) is already default
    } else if (_dailyChallengeStatus == 'started') {
      titleText = "Current Challenge";
      // Subtitle already formatted as "TIME LEFT - HH:MM:SS"
      // descriptionText is _currentDailyChallengeText (the actual challenge)
      // The small icon at top-left (_challengeIconAsset) is already default
    } else if (_dailyChallengeStatus == 'completed') {
      titleText = "Daily Challenge";
      subtitleText = "Completed!"; // Change subtitle
      descriptionText = "Great job! Come back tomorrow.";
      topLeftIconWidget = Container( // Replace icon with checkmark
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: Colors.white, // White background for the check
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_circle_rounded, // Checkmark icon
          color: colorScheme.primary, // Theme color for the checkmark
          size: 18,
        ),
      );
    }


    final TextStyle generalTextStyle = TextStyle(
      color: onAccentColor,
      fontFamily: _primaryFontFamily,
      shadows: [ Shadow(blurRadius: 2.0, color: Colors.black.withOpacity(0.4), offset: const Offset(1,1))],
    );


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GestureDetector(
        onTap: _navigateToDailyChallengeScreenWithRefresh, // Updated navigation method
        child: Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              boxShadow: [_buildEnhancedShadow(context)],
              gradient: LinearGradient(
                colors: themeProvider.currentAccentGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(25.0),
                  child: Image.asset(
                    _currentChallengePngAsset, // Use state variable for PNG
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                      return Container(color: Colors.transparent); // Transparent if image fails
                    },
                  ),
                ),
                Container( // Overlay for better text readability
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25.0),
                    color: Colors.black.withOpacity(0.20), // Adjusted overlay
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row( // Top line: Small Icon and Time/Status
                        children: [
                          topLeftIconWidget, // Dynamically shows mountain or checkmark
                          const SizedBox(width: 8),
                          Text(subtitleText, // "ENDS IN..." or "TIME LEFT..." or "Completed!"
                              style: generalTextStyle.copyWith(
                                  fontSize: theme.textTheme.labelMedium!.fontSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5
                              )),
                        ],
                      ),
                      const Spacer(), // Pushes content to top and bottom
                      // Main Title Text
                      if (_dailyChallengeStatus == 'not_started') ...[
                        Text('Daily', style: generalTextStyle.copyWith(fontSize: theme.textTheme.headlineSmall!.fontSize, fontWeight: FontWeight.w300)),
                        Text('Challenge', style: generalTextStyle.copyWith(fontSize: theme.textTheme.headlineSmall!.fontSize, fontWeight: FontWeight.bold)),
                      ] else ... [
                        Text(titleText, // "Current Challenge" or "Daily Challenge"
                            style: generalTextStyle.copyWith(fontSize: theme.textTheme.headlineSmall!.fontSize, fontWeight: FontWeight.bold)),
                      ],

                      // Description Text (Challenge text or completion message)
                      if (_dailyChallengeStatus != 'not_started' && _dailyChallengeStatus != 'completed') // Only show actual challenge text if started
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            descriptionText,
                            style: generalTextStyle.copyWith(fontSize: theme.textTheme.bodyMedium!.fontSize, fontWeight: FontWeight.w500, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else if (_dailyChallengeStatus == 'completed') // Show completion message
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            descriptionText, // "Great job! Come back tomorrow."
                            style: generalTextStyle.copyWith(fontSize: theme.textTheme.bodyMedium!.fontSize, fontWeight: FontWeight.w500, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // For 'not_started', the "Daily Challenge" text acts as the main content,
                      // and descriptionText might be a generic "Tap to see..." which is not shown directly on card but in screen.
                      // Or, if you want the challenge text always visible:
                      // if (_dailyChallengeStatus == 'not_started' && _currentDailyChallengeText != null) Text(_currentDailyChallengeText!, ...),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyCheckinCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GestureDetector(
        onTap: _navigateToMoodCheckinScreen,
        child: Card(
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
          child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(25.0),
                  boxShadow: [_buildEnhancedShadow(context)]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(_dailyCheckinIconAsset,
                            height: 18,
                            width: 18,
                            color: theme.textTheme.bodySmall?.color,
                            errorBuilder: (c, e, s) => Icon(
                                Icons.error_outline,
                                color: theme.textTheme.bodySmall?.color)),
                        const SizedBox(width: 8),
                        Text('DAILY CHECK-IN',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                fontFamily: _primaryFontFamily)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text("How are you feeling today?",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontFamily: _primaryFontFamily)),
                  ])),
        ),
      ),
    );
  }

  Widget _buildQuoteCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
        child: GestureDetector(
          onTap: _navigateToThoughtsScreen,
          child: Container(
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.0),
              boxShadow: [_buildEnhancedShadow(context)],
              image: DecorationImage(
                image: (_dailyQuoteImageUrl != null &&
                    _dailyQuoteImageUrl!.startsWith('http'))
                    ? CachedNetworkImageProvider(_dailyQuoteImageUrl!)
                as ImageProvider<Object>
                    : AssetImage(_dailyQuoteImageUrl ?? _quoteBgAsset),
                fit: BoxFit.cover,
                onError: (e, s) {},
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.55), BlendMode.darken),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 10.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: _isQuoteLoading
                            ? SizedBox(
                            key: const ValueKey('quote_loading'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white70, strokeWidth: 2))
                            : Column(
                          key: ValueKey(
                              _dailyQuoteText ?? "quote_text_fallback"),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_dailyQuoteText ?? "...",
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: _primaryFontFamily,
                                    shadows: [
                                      Shadow(
                                          blurRadius: 5.0,
                                          color: Colors.black
                                              .withOpacity(0.5),
                                          offset: const Offset(1.0, 1.0))
                                    ])),
                            if (_dailyQuoteAuthor != null &&
                                _dailyQuoteAuthor!.isNotEmpty &&
                                _dailyQuoteAuthor != "Unknown")
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "- ${_dailyQuoteAuthor!}",
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                      color: Colors.white70,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: _primaryFontFamily),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen,
                          color: Colors.white70, size: 24),
                      onPressed: () {
                        print("Expand quote tapped");
                        _navigateToThoughtsScreen(); // Also navigate on expand
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
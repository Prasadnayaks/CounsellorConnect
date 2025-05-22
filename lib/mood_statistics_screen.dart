// lib/mood_statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Sticking with fl_chart
import 'dart:math' as math;

import 'models/mood_checkin_model.dart';
import 'theme/theme_provider.dart';

// --- Icons for Activity and Feeling Chips ---
const Map<String, IconData> _activityFeelingIcons = { /* ... same ... */
  'work': Icons.work_outline_rounded, 'family': Icons.home_filled,
  'friends': Icons.people_alt_rounded, 'hobbies': Icons.extension_rounded,
  'school': Icons.school_rounded, 'relationship': Icons.favorite_rounded,
  'traveling': Icons.flight_takeoff_rounded, 'sleep': Icons.bedtime_rounded,
  'food': Icons.restaurant_rounded, 'exercise': Icons.fitness_center_rounded,
  'health': Icons.monitor_heart_rounded, 'music': Icons.music_note_rounded,
  'gaming': Icons.sports_esports_rounded, 'reading': Icons.menu_book_rounded,
  'relaxing': Icons.self_improvement_rounded, 'chores': Icons.home_repair_service_rounded,
  'social media': Icons.hub_rounded, 'news': Icons.newspaper_rounded,
  'weather': Icons.wb_cloudy_rounded, 'shopping': Icons.shopping_bag_rounded,
  'happy': Icons.sentiment_very_satisfied_rounded, 'blessed': Icons.volunteer_activism_rounded,
  'good': Icons.sentiment_satisfied_alt_rounded, 'lucky': Icons.star_rounded,
  'confused': Icons.psychology_alt_outlined, 'bored': Icons.sentiment_dissatisfied_outlined,
  'awkward': Icons.sentiment_neutral_outlined, 'stressed': Icons.sentiment_very_dissatisfied_outlined,
  'angry': Icons.whatshot_rounded, 'anxious': Icons.sentiment_dissatisfied_rounded,
  'down': Icons.arrow_downward_rounded, 'calm': Icons.spa_rounded,
  'energetic': Icons.flash_on_rounded, 'tired': Icons.battery_alert_rounded,
  'grateful': Icons.favorite_border_rounded, 'other': Icons.more_horiz_rounded,
};
// --- End Icons ---

class StatisticsBackgroundPainter extends CustomPainter { /* ... Same ... */
  final Gradient gradient;
  final BuildContext context;
  const StatisticsBackgroundPainter({required this.gradient, required this.context});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.55));
    final path = Path()..moveTo(0, 0)..lineTo(0, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.50, size.width, size.height * 0.35)
      ..lineTo(size.width, 0)..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant StatisticsBackgroundPainter oldDelegate) => oldDelegate.gradient != gradient || oldDelegate.context != context;
}

class MoodStatisticsScreen extends StatefulWidget {
  const MoodStatisticsScreen({Key? key}) : super(key: key);
  @override
  _MoodStatisticsScreenState createState() => _MoodStatisticsScreenState();
}

class _MoodStatisticsScreenState extends State<MoodStatisticsScreen> {
  // ... (State variables, initState, data fetching/processing methods remain the same)
  bool _isLoading = true;
  String _selectedPeriod = 'weekly';
  List<MoodCheckinEntry> _moodEntries = [];
  double _averageMoodScore = 0.0; String _averageMoodLabel = "Okay"; DateTime _averageMoodDate = DateTime.now();
  int _negativeDays = 0; int _positiveDays = 0; Map<int, int> _moodBreakdownData = {};
  Map<String, int> _whatMakesYouShineActivities = {}; Map<String, int> _whatMakesYouShineFeelings = {};
  Map<String, int> _whatGetsYouDownActivities = {}; Map<String, int> _whatGetsYouDownFeelings = {};
  Map<String, double> _topActivitiesPercentages = {}; Map<String, double> _frequentFeelingsPercentages = {};
  DateTime _currentWeekStart = DateTime.now(); DateTime _currentWeekEnd = DateTime.now();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  static const String _primaryFontFamily = 'Nunito';
  static const double _cardRadius = 22.0;
  static const Color _cardBackgroundColor = Colors.white;
  static const Color _primaryTextColorOnWhite = Color(0xFF3A4A6A);
  static const Color _secondaryTextColorOnWhite = Color(0xFF7C8BA9);
  static const Color _fadedTitleColorOnCard = Color(0xFFEEF3FE);
  static const Color _lightBlueChipColor = Color(0xFFEAF2FF);
  static const Color _lightBlueChipTextColor = Color(0xFF5E8BFF);

  late ScrollController _scrollController;
  double _backgroundOffset = 0.0;
  final double _parallaxFactor = 0.3;

  @override
  void initState() { super.initState(); _scrollController = ScrollController()..addListener(_scrollListener); _calculateWeekDisplay(); _fetchDataForPeriod(); }
  void _scrollListener() { if (!mounted || !_scrollController.hasClients) return; double newOffset = -_scrollController.offset * _parallaxFactor; if (newOffset > 0) newOffset = 0; if (newOffset != _backgroundOffset) { setState(() { _backgroundOffset = newOffset; }); } }
  @override
  void dispose() { _scrollController.removeListener(_scrollListener); _scrollController.dispose(); super.dispose(); }
  void _calculateWeekDisplay() { DateTime now = DateTime.now(); _currentWeekStart = now.subtract(Duration(days: now.weekday - 1)); _currentWeekEnd = _currentWeekStart.add(const Duration(days: 6)); }
  void _changeWeek(int direction) { setState(() { _currentWeekStart = _currentWeekStart.add(Duration(days: 7 * direction)); _currentWeekEnd = _currentWeekEnd.add(Duration(days: 7 * direction)); _fetchDataForPeriod(); }); }
  Future<void> _fetchDataForPeriod() async { if (_currentUser == null) { setState(() => _isLoading = false); return; } setState(() => _isLoading = true); DateTime startDate; DateTime endDate; if (_selectedPeriod == 'weekly') { startDate = DateTime(_currentWeekStart.year, _currentWeekStart.month, _currentWeekStart.day); endDate = DateTime(_currentWeekEnd.year, _currentWeekEnd.month, _currentWeekEnd.day, 23, 59, 59); } else { final now = DateTime.now(); startDate = DateTime(now.year, now.month, 1); endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59); } try { final snapshot = await _firestore.collection('users').doc(_currentUser!.uid).collection('mood_entries').where('entryDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate)).where('entryDateTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate)).orderBy('entryDateTime', descending: false).get(); _moodEntries = snapshot.docs.map((doc) => MoodCheckinEntry.fromJson(doc.data())).toList(); _processMoodEntries(); } catch (e) { print("Error fetching mood entries: $e"); } finally { if (mounted) setState(() => _isLoading = false); } }
  void _processMoodEntries() { if (_moodEntries.isEmpty) { _averageMoodScore = 0.0; _averageMoodLabel = "N/A"; _averageMoodDate = _selectedPeriod == 'weekly' ? _currentWeekStart : DateTime(_currentWeekStart.year, _currentWeekStart.month, 1); _negativeDays = 0; _positiveDays = 0; _moodBreakdownData = {}; _whatMakesYouShineActivities = {}; _whatMakesYouShineFeelings = {}; _whatGetsYouDownActivities = {}; _whatGetsYouDownFeelings = {}; _topActivitiesPercentages = {}; _frequentFeelingsPercentages = {}; if(mounted) setState((){}); return; } double totalMoodIndex = 0; _moodEntries.forEach((entry) => totalMoodIndex += entry.moodIndex); double rawAverage = totalMoodIndex / _moodEntries.length; _averageMoodScore = (rawAverage / 4.0) * 10.0; _averageMoodLabel = _getMoodLabelFromIndex(rawAverage.round()); _averageMoodDate = _moodEntries.isNotEmpty ? _moodEntries.last.entryDateTime : DateTime.now(); Set<String> uniqueNegativeDays = {}; Set<String> uniquePositiveDays = {}; for (var entry in _moodEntries) { String dayKey = DateFormat('yyyy-MM-dd').format(entry.entryDateTime); if (entry.moodIndex <= 1) uniqueNegativeDays.add(dayKey); else if (entry.moodIndex >= 3) uniquePositiveDays.add(dayKey); } _negativeDays = uniqueNegativeDays.length; _positiveDays = uniquePositiveDays.length; _moodBreakdownData = {0:0, 1:0, 2:0, 3:0, 4:0}; for (var entry in _moodEntries) { _moodBreakdownData[entry.moodIndex] = (_moodBreakdownData[entry.moodIndex] ?? 0) + 1; } _whatMakesYouShineActivities.clear(); _whatMakesYouShineFeelings.clear(); _whatGetsYouDownActivities.clear(); _whatGetsYouDownFeelings.clear(); for (var entry in _moodEntries) { if (entry.moodIndex >= 3) { entry.selectedActivities.forEach((act) => _whatMakesYouShineActivities[act] = (_whatMakesYouShineActivities[act] ?? 0) + 1); entry.selectedFeelings.forEach((feel) => _whatMakesYouShineFeelings[feel] = (_whatMakesYouShineFeelings[feel] ?? 0) + 1); } else if (entry.moodIndex <= 1) { entry.selectedActivities.forEach((act) => _whatGetsYouDownActivities[act] = (_whatGetsYouDownActivities[act] ?? 0) + 1); entry.selectedFeelings.forEach((feel) => _whatGetsYouDownFeelings[feel] = (_whatGetsYouDownFeelings[feel] ?? 0) + 1); } } Map<String, int> allActivitiesCount = {}; Map<String, int> allFeelingsCount = {}; int totalActivitySelections = 0; int totalFeelingSelections = 0; for (var entry in _moodEntries) { entry.selectedActivities.forEach((act) { allActivitiesCount[act] = (allActivitiesCount[act] ?? 0) + 1; totalActivitySelections++; }); entry.selectedFeelings.forEach((feel) { allFeelingsCount[feel] = (allFeelingsCount[feel] ?? 0) + 1; totalFeelingSelections++; });} _topActivitiesPercentages = {}; if (totalActivitySelections > 0) { var sortedActivities = allActivitiesCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value)); for (var i = 0; i < math.min(3, sortedActivities.length); i++) { _topActivitiesPercentages[sortedActivities[i].key] = (sortedActivities[i].value / totalActivitySelections) * 100; }} _frequentFeelingsPercentages = {}; if (totalFeelingSelections > 0) { var sortedFeelings = allFeelingsCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value)); for (var i = 0; i < math.min(3, sortedFeelings.length); i++) { _frequentFeelingsPercentages[sortedFeelings[i].key] = (sortedFeelings[i].value / totalFeelingSelections) * 100; }} if(mounted) setState((){}); }
  String _getMoodLabelFromIndex(int index) { if (index < 0 || index >= 5) return "Okay"; const labels = ["Really Terrible", "Somewhat Bad", "Completely Okay", "Pretty Good", "Super Awesome"]; return labels[index]; }
  List<BoxShadow> _getCardBoxShadow(BuildContext context) { return [ BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 16.0, spreadRadius: 1.0, offset: const Offset(0, 8.0)), BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8.0, offset: const Offset(0, 2.0)) ]; }


  @override
  Widget build(BuildContext context) { /* ... Same build method structure ... */
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Gradient currentGradient = LinearGradient(colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight);
    final Brightness statusBarBrightnessForGradient = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Brightness.light : Brightness.dark;
    final SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: statusBarBrightnessForGradient, systemNavigationBarColor: Colors.white, systemNavigationBarIconBrightness: Brightness.dark, systemNavigationBarDividerColor: Colors.transparent);
    final Color onGradientTextColor = statusBarBrightnessForGradient == Brightness.dark ? Colors.white : Colors.black.withOpacity(0.75);
    final topSafeAreaPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(children: [
          Positioned.fill(child: Transform.translate(offset: Offset(0, _backgroundOffset), child: CustomPaint(painter: StatisticsBackgroundPainter(gradient: currentGradient, context: context), child: Container()))),
          Padding(padding: EdgeInsets.only(top: topSafeAreaPadding), child: ListView(controller: _scrollController, padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), children: [
            Padding(padding: const EdgeInsets.only(top: 10.0, bottom: 20.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
              Material( color: Colors.transparent, child: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: onGradientTextColor, size: 20), onPressed: () => Navigator.of(context).pop(), tooltip: 'Back')),
              Flexible(child: _buildTopPeriodToggle(themeProvider, onGradientTextColor)),
              const SizedBox(width: 40)])),
            _isLoading ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 50.0), child: CircularProgressIndicator(color: _primaryTextColorOnWhite))) : _buildStatisticsContent(themeProvider),
          ]))
        ]),
      ),
    );
  }

  Widget _buildTopPeriodToggle(ThemeProvider themeProvider, Color onGradientColor) { /* ... Same ... */
    final Color selectedBgColor = onGradientColor.withOpacity(0.20); final Color unselectedBgColor = Colors.transparent; final Color selectedTextColor = onGradientColor; final Color unselectedTextColor = onGradientColor.withOpacity(0.75);
    return Container( margin: const EdgeInsets.only(bottom: 0), padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: onGradientColor.withOpacity(0.08), borderRadius: BorderRadius.circular(25)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[ Flexible(child: _buildToggleChip("Weekly", 'weekly', selectedBgColor, unselectedBgColor, selectedTextColor, unselectedTextColor)), const SizedBox(width: 6), Flexible(child: _buildToggleChip("Monthly", 'monthly', selectedBgColor, unselectedBgColor, selectedTextColor, unselectedTextColor)) ]));
  }
  Widget _buildToggleChip(String label, String value, Color selectedBg, Color unselectedBg, Color selectedText, Color unselectedText) { /* ... Same ... */
    bool isSelected = _selectedPeriod == value;
    return GestureDetector(
        onTap: () { if (_selectedPeriod != value) { setState(() { _selectedPeriod = value; if (value == 'monthly') { final now = DateTime.now(); _currentWeekStart = DateTime(now.year, now.month, 1); _currentWeekEnd = DateTime(now.year, now.month + 1, 0); } else { _calculateWeekDisplay(); } _fetchDataForPeriod(); }); }},
        child: AnimatedContainer( duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10), decoration: BoxDecoration(color: isSelected ? selectedBg : unselectedBg, borderRadius: BorderRadius.circular(20)),
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 13.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? selectedText : unselectedText), overflow: TextOverflow.ellipsis, maxLines: 1)));
  }

  Widget _buildStatisticsContent(ThemeProvider themeProvider) { /* ... Same structure ... */
    final Color fadedTitleOnCard = _fadedTitleColorOnCard;
    return Column(children: [
      _buildAverageMoodCard(fadedTitleOnCard), const SizedBox(height: 20),
      if (_selectedPeriod == 'weekly') ...[_buildThisWeekNavigator(), const SizedBox(height: 20)],
      _buildNegativePositiveDaysCard(), const SizedBox(height: 20),
      _buildMoodBreakdownCard(fadedTitleOnCard), const SizedBox(height: 20),
      _buildWhatMakesYouShineCard(fadedTitleOnCard), const SizedBox(height: 20),
      _buildWhatGetsYouDownCard(fadedTitleOnCard), const SizedBox(height: 20),
      _buildTopActivitiesCard(fadedTitleOnCard), const SizedBox(height: 20),
      _buildFrequentFeelingsCard(fadedTitleOnCard),
    ]);
  }

  Widget _buildInfoCard({ required String largeFadedTitle, required String? descriptiveHeader, required Widget content, double cardHeight = 200, double descriptiveHeaderVerticalOffset = 30.0, double titleOverlapFactor = 0.5 }) { /* ... Same as previous fixed version ... */
    return Container( decoration: BoxDecoration(color: _cardBackgroundColor, borderRadius: BorderRadius.circular(_cardRadius), boxShadow: _getCardBoxShadow(context)),
        child: ClipRRect( borderRadius: BorderRadius.circular(_cardRadius), child: SizedBox(width: double.infinity, height: cardHeight,
            child: Stack(alignment: Alignment.topCenter, children: [
              if (largeFadedTitle.isNotEmpty) Positioned(top: 8, left: 0, right: 0, child: Text(largeFadedTitle.toUpperCase(), textAlign: TextAlign.center, overflow: TextOverflow.clip, maxLines: 1, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 38, fontWeight: FontWeight.w800, color: _fadedTitleColorOnCard, height: 0.95))),
              Padding( padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (descriptiveHeader != null) Padding( padding: EdgeInsets.only(top: descriptiveHeaderVerticalOffset - (15 * titleOverlapFactor) + (largeFadedTitle.isNotEmpty ? 0 : 10), bottom: 10.0), child: Text(descriptiveHeader, style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 15, fontWeight: FontWeight.bold, color: _primaryTextColorOnWhite))),
                if (descriptiveHeader == null && largeFadedTitle.isNotEmpty) const SizedBox(height: 45),
                Expanded(child: Center(child: content))]))]))));
  }
  Widget _buildAverageMoodCard(Color fadedTitleOnCardColor) { /* ... Same content, calls _buildInfoCard ... */
    Widget graphContent = _moodEntries.length < 2 ? const Text("Not enough data for trend line.", style: TextStyle(color: _secondaryTextColorOnWhite, fontFamily: _primaryFontFamily, fontSize: 13))
        : SizedBox(height: 70, child: LineChart(LineChartData( gridData: FlGridData(show: false), titlesData: FlTitlesData(show: false), borderData: FlBorderData(show: false),
        lineBarsData: [LineChartBarData( spots: _moodEntries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.moodIndex.toDouble() + 1)).toList(), isCurved: true, color: _primaryTextColorOnWhite.withOpacity(0.5), barWidth: 2.5, isStrokeCapRound: true, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: _primaryTextColorOnWhite.withOpacity(0.05)))],
        minX: 0, maxX: (_moodEntries.length - 1).toDouble(), minY: 0, maxY: 5)));
    return _buildInfoCard(largeFadedTitle: _averageMoodLabel.isNotEmpty ? _averageMoodLabel : "MOOD", descriptiveHeader: "AVERAGE MOOD", cardHeight: 220, descriptiveHeaderVerticalOffset: 38, titleOverlapFactor: 0.7,
        content: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [ Text(_averageMoodScore.toStringAsFixed(1), style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 34, fontWeight: FontWeight.bold, color: _primaryTextColorOnWhite)), const SizedBox(width: 4), Text("/ 10", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 15, color: _secondaryTextColorOnWhite, fontWeight: FontWeight.w600))]), Text(DateFormat('dd MMM, yy').format(_averageMoodDate).toUpperCase(), style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 11, color: _secondaryTextColorOnWhite, fontWeight: FontWeight.w500, letterSpacing: 0.5)), const SizedBox(height: 10), Expanded(child: graphContent), const SizedBox(height: 5)]));
  }
  Widget _buildThisWeekNavigator() { /* ... Same ... */
    return Card( elevation: 1.0, color: _cardBackgroundColor, shadowColor: Colors.grey.withOpacity(0.25), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _secondaryTextColorOnWhite, size: 18), onPressed: () => _changeWeek(-1)), Column(children: [ const Text("THIS WEEK", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 11, color: _secondaryTextColorOnWhite, fontWeight: FontWeight.w600, letterSpacing: 0.5)), const SizedBox(height: 2), Text("${DateFormat('d MMM').format(_currentWeekStart)} - ${DateFormat('d MMM').format(_currentWeekEnd)}", style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 14, color: _primaryTextColorOnWhite, fontWeight: FontWeight.bold))]), IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, color: _secondaryTextColorOnWhite, size: 18), onPressed: () => _changeWeek(1))])));
  }
  Widget _buildNegativePositiveDaysCard() { /* ... Same ... */
    return _buildInfoCard( largeFadedTitle: "BALANCE", descriptiveHeader: null, cardHeight: 130, descriptiveHeaderVerticalOffset: 15, titleOverlapFactor: 0,
        content: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [ Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Text("$_negativeDays", style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 36, fontWeight: FontWeight.bold, color: _primaryTextColorOnWhite)), const Text("negative days", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 12, color: _secondaryTextColorOnWhite, fontWeight: FontWeight.w500))]), Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Text("$_positiveDays", style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 36, fontWeight: FontWeight.bold, color: _primaryTextColorOnWhite)), const Text("positive days", style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 12, color: _secondaryTextColorOnWhite, fontWeight: FontWeight.w500))])]));
  }
  Widget _buildMoodBreakdownCard(Color fadedTitleOnCard) { /* ... Same ... */
    Widget graphContent = _moodBreakdownData.values.every((count) => count == 0) ? const Text("No mood breakdown data.", style: TextStyle(color: _secondaryTextColorOnWhite, fontFamily: _primaryFontFamily, fontSize: 13))
        : SizedBox(height: 90, child: BarChart(BarChartData( alignment: BarChartAlignment.spaceAround, maxY: (_moodBreakdownData.values.isNotEmpty ? _moodBreakdownData.values.reduce(math.max).toDouble() : 0.0) * 1.2 + 1, barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(show: true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _getMoodBreakdownTitlesWidget, reservedSize: 28)), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
        borderData: FlBorderData(show: false), barGroups: _moodBreakdownData.entries.map((entry) => BarChartGroupData(x: entry.key, barRods: [BarChartRodData(toY: entry.value.toDouble(), color: _getMoodColor(entry.key, context), width: 15, borderRadius: BorderRadius.circular(4))])).toList(), gridData: FlGridData(show: false))));
    return _buildInfoCard(largeFadedTitle: "BREAKDOWN", descriptiveHeader: "Mood Breakdown", cardHeight: 190, descriptiveHeaderVerticalOffset: 30, titleOverlapFactor: 0.6, content: graphContent);
  }
  Widget _getMoodBreakdownTitlesWidget(double value, TitleMeta meta) { /* ... Same ... */
    IconData iconData; switch (value.toInt()) { case 0: iconData = Icons.sentiment_very_dissatisfied_rounded; break; case 1: iconData = Icons.sentiment_dissatisfied_rounded; break; case 2: iconData = Icons.sentiment_neutral_rounded; break; case 3: iconData = Icons.sentiment_satisfied_rounded; break; case 4: iconData = Icons.sentiment_very_satisfied_rounded; break; default: iconData = Icons.help_outline_rounded; }
    return SideTitleWidget(meta: meta, space: 3.0, child: Icon(iconData, color: _secondaryTextColorOnWhite, size: 16));
  }
  Color _getMoodColor(int moodIndex, BuildContext context) { /* ... Same ... */
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false); switch (moodIndex) { case 0: return Colors.red.shade300; case 1: return Colors.orange.shade300; case 2: return Colors.grey.shade400; case 3: return themeProvider.currentAccentColor.withOpacity(0.7); case 4: return themeProvider.currentAccentColor; default: return Colors.blueGrey; }
  }
  Widget _buildWhatMakesYouShineCard(Color fadedTitleOnCard) { /* ... Same ... */
    List<Widget> chips = _buildLimitedChips(_whatMakesYouShineActivities, _whatMakesYouShineFeelings, limit: 4);
    return _buildInfoCard(largeFadedTitle: "SHINE", descriptiveHeader: "What makes you shine", cardHeight: 170, descriptiveHeaderVerticalOffset: 30, titleOverlapFactor: 0.6, content: chips.isEmpty ? const Text("No data yet.", style: TextStyle(color: _secondaryTextColorOnWhite, fontFamily: _primaryFontFamily, fontSize: 13)) : Wrap(spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.center, children: chips));
  }
  Widget _buildWhatGetsYouDownCard(Color fadedTitleOnCard) { /* ... Same ... */
    List<Widget> chips = _buildLimitedChips(_whatGetsYouDownActivities, _whatGetsYouDownFeelings, limit: 4);
    return _buildInfoCard(largeFadedTitle: "CHALLENGES", descriptiveHeader: "What gets you down", cardHeight: 170, descriptiveHeaderVerticalOffset: 30, titleOverlapFactor: 0.6, content: chips.isEmpty ? const Text("No data yet.", style: TextStyle(color: _secondaryTextColorOnWhite, fontFamily: _primaryFontFamily, fontSize: 13)) : Wrap(spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.center, children: chips));
  }
  List<Widget> _buildLimitedChips(Map<String, int> activities, Map<String, int> feelings, {int limit = 5}) { /* ... Same ... */
    List<MapEntry<String, int>> combined = [...activities.entries, ...feelings.entries];
    combined.sort((a, b) => b.value.compareTo(a.value)); List<Widget> chips = [];
    for (int i = 0; i < math.min(limit, combined.length); i++) { chips.add(_buildActivityChipWithIcon(combined[i].key)); } return chips;
  }
  Widget _buildActivityChipWithIcon(String label) { /* Uses _activityFeelingIcons */
    IconData? iconData = _activityFeelingIcons[label.toLowerCase()];
    return Chip( avatar: iconData != null ? Icon(iconData, size: 15, color: _lightBlueChipTextColor.withOpacity(0.9)) : null, label: Text(label, style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 12, color: _lightBlueChipTextColor, fontWeight: FontWeight.w500)), backgroundColor: _lightBlueChipColor.withOpacity(0.85), padding: EdgeInsets.symmetric(horizontal: iconData != null ? 7 : 9, vertical: 5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap);
  }

  // --- CUSTOMIZED PIE CHART WITH FL_CHART (Doughnut style) ---
  Widget _buildCustomDoughnutChartWithLegend(Map<String, double> data, Color Function(String) colorFunction) {
    if (data.isEmpty) return const SizedBox(height: 120, child: Center(child: Text("No data for chart.", style: TextStyle(color: _secondaryTextColorOnWhite, fontFamily: _primaryFontFamily))));

    // Calculate total to make sure sections add up to 100% for a full circle if needed,
    // or use a background section. For the "arc" style, we only show top items.
    // Let's assume data values are already percentages.

    // Determine the sweep angle for the "track" or background of the arc.
    // For the image, it looks like about 270 degrees or 3/4 of a circle.
    const double totalAngle = 360.0;
    const double startAngleOffset = -90.0; // Start from the top

    // Create sections for actual data and a background/track section
    List<PieChartSectionData> sections = [];
    double currentAngle = 0;

    // Main data sections (top 3 usually)
    data.forEach((key, value) { // value is percentage
      final double sweepAngle = (value / 100.0) * totalAngle * 0.75; // Make the arc segments proportional to a 270deg total
      sections.add(PieChartSectionData(
        color: colorFunction(key),
        value: value, // Value is used for drawing proportion
        title: '', // No title on segment, legend handles it
        radius: 20, // Thickness of the arc
        // No titleStyle needed if title is empty
      ));
      currentAngle += sweepAngle;
    });

    // Add a background section for the remaining part of the 270-degree arc
    if (currentAngle < (totalAngle * 0.75) && sections.isNotEmpty) {
      sections.add(PieChartSectionData(
        color: Colors.grey.shade200, // Light grey for the track
        value: ((totalAngle * 0.75) - currentAngle) / (totalAngle * 0.75) * 100, // Remaining percentage of the 270deg arc
        title: '',
        radius: 20,
      ));
    }
    // If no data, show a full grey track
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        color: Colors.grey.shade200,
        value: 100,
        title: '',
        radius: 20,
      ));
    }


    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0, // No space for a continuous arc look
                centerSpaceRadius: 28, // Makes it a doughnut, controls hole size
                startDegreeOffset: startAngleOffset, // Start from top
                sections: sections,
                // borderData: FlBorderData(show: false), // Already default
                // pieTouchData: PieTouchData(enabled: false), // Disable touch if not needed
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Disable scroll for legend if short
              itemCount: data.length,
              itemBuilder: (context, index) {
                MapEntry<String, double> entry = data.entries.elementAt(index);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: colorFunction(entry.key))),
                    const SizedBox(width: 6),
                    Flexible(child: Text("${entry.key} (${entry.value.toStringAsFixed(0)}%)", style: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 11, color: _primaryTextColorOnWhite, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ]),
                );
              },
            ),
          )
        ],
      ),
    );
  }


  Widget _buildTopActivitiesCard(Color fadedTitleOnCard) {
    Widget graphContent = _topActivitiesPercentages.isEmpty
        ? const Text("No activity data.", style: TextStyle(color: _secondaryTextColorOnWhite, fontFamily: _primaryFontFamily, fontSize: 13))
        : _buildCustomDoughnutChartWithLegend(_topActivitiesPercentages, _getColorForActivity);
    return _buildInfoCard(largeFadedTitle: "ACTIVITIES", descriptiveHeader: "Top Activities", cardHeight: 190, descriptiveHeaderVerticalOffset: 30, titleOverlapFactor: 0.6, content: graphContent);
  }

  Widget _buildFrequentFeelingsCard(Color fadedTitleOnCard) {
    Widget graphContent = _frequentFeelingsPercentages.isEmpty
        ? const Text("No feeling data.", style: TextStyle(color: _secondaryTextColorOnWhite, fontFamily: _primaryFontFamily, fontSize: 13))
        : _buildCustomDoughnutChartWithLegend(_frequentFeelingsPercentages, _getColorForFeeling);
    return _buildInfoCard(largeFadedTitle: "FEELINGS", descriptiveHeader: "Frequent Feelings", cardHeight: 190, descriptiveHeaderVerticalOffset: 30, titleOverlapFactor: 0.6, content: graphContent);
  }

  Color _getColorForActivity(String name) { /* ... Same ... */ int hash = name.hashCode; return Color((hash & 0x00FFFFFF) | 0xFF000000).withOpacity(1.0); }
  Color _getColorForFeeling(String name) { /* ... Same ... */ int hash = name.hashCode; return Color(((hash >> 5) & 0x00FFFFFF) | 0xFF000000).withOpacity(1.0); }
}
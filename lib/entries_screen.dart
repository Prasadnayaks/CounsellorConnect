// lib/entries_screen.dart
import 'package:counsellorconnect/mood_statistics_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'theme/theme_provider.dart';
import 'models/mood_checkin_model.dart';
import 'models/voice_note_model.dart';
import 'models/truth_reflection_model.dart';
import 'models/daily_challenge_completion_model.dart';
import 'models/general_photo_model.dart'; // Import the new model

import 'profile_screen.dart';
import 'widgets/bouncing_widget.dart';

// --- TimelineEntry Definition ---
enum EntryType { mood, voice, truth, challenge, photo } // Added photo

class TimelineEntry implements Comparable<TimelineEntry> {
  final DateTime date;
  final EntryType type;
  final dynamic data;
  final String? id;

  TimelineEntry({required this.date, required this.type, required this.data, this.id});

  @override
  int compareTo(TimelineEntry other) {
    return other.date.compareTo(date); // Sorts newest first
  }
}
// --- End TimelineEntry Definition ---

const String _profileIconAsset = 'assets/icons/profile_placeholder.png';
const String _primaryFontFamily = 'Nunito';
const double _cardCornerRadius = 18.0;

const List<IconData> _moodIconsList = [
  Icons.sentiment_very_dissatisfied_rounded, Icons.sentiment_dissatisfied_rounded,
  Icons.sentiment_neutral_rounded, Icons.sentiment_satisfied_rounded,
  Icons.sentiment_very_satisfied_rounded,
];

const Map<String, IconData> _activityFeelingIcons = {
  // Moods & Activities (existing)
  'work': Icons.work_outline_rounded, 'family': Icons.home_filled,
  'friends': Icons.people_alt_rounded, 'hobbies': Icons.extension_rounded,
  'school': Icons.school_rounded, 'relationship': Icons.favorite_rounded,
  'traveling': Icons.flight_takeoff_rounded, 'sleep': Icons.bedtime_rounded,
  'food': Icons.restaurant_rounded, 'exercise': Icons.fitness_center_rounded,
  'health': Icons.monitor_heart_rounded, 'music': Icons.music_note_rounded,
  'gaming': Icons.sports_esports_rounded, 'reading': Icons.menu_book_rounded,
  'relaxing': Icons.self_improvement_rounded, 'chores': Icons.home_repair_service_outlined,
  'social media': Icons.hub_rounded, 'news': Icons.newspaper_rounded,
  'weather': Icons.wb_cloudy_rounded, 'shopping': Icons.shopping_bag_outlined,
  'happy': Icons.sentiment_very_satisfied_rounded, 'blessed': Icons.volunteer_activism_rounded,
  'good': Icons.sentiment_satisfied_alt_rounded, 'lucky': Icons.star_rounded,
  'confused': Icons.psychology_alt_outlined, 'bored': Icons.sentiment_dissatisfied_outlined,
  'awkward': Icons.sentiment_neutral_outlined, 'stressed': Icons.sentiment_very_dissatisfied_outlined,
  'angry': Icons.whatshot_rounded, 'anxious': Icons.sentiment_dissatisfied_rounded,
  'down': Icons.arrow_downward_rounded, 'calm': Icons.spa_rounded,
  'energetic': Icons.flash_on_rounded, 'tired': Icons.battery_alert_rounded,
  'grateful': Icons.favorite_border_rounded, 'other': Icons.more_horiz_rounded,
  // Truth Themes
  'mindfulness': Icons.self_improvement_outlined, 'truth': Icons.check_circle_outline,
  'wisdom': Icons.lightbulb_outline, 'identity': Icons.face_retouching_natural,
  'favorites': Icons.star_outline, 'celebration': Icons.celebration_outlined,
  'gratitude': Icons.volunteer_activism_outlined, 'reflection': Icons.history_edu_outlined,
  // Daily Challenge
  'challenge': Icons.flag_outlined,
  // General Photo
  'photo': Icons.photo_library_outlined,
};


class EntriesScreen extends StatefulWidget {
  const EntriesScreen({Key? key}) : super(key: key);

  @override
  _EntriesScreenState createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  List<TimelineEntry> _allEntries = [];
  bool _isLoading = true;
  String? _userName;
  int _reflectionCount = 0; // Voice Notes count
  int _checkInCount = 0;    // Mood Check-ins count
  int _photoCount = 0;      // General Photos count

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _fetchUserName();
    await _fetchAllEntriesAndOriginalCounts();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUserName() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _userName = "Friend");
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        _userName = (doc.data() as Map<String, dynamic>?)?['name'] as String? ?? _currentUser?.displayName ?? "Friend";
      }
    } catch (e) {
      print("Error fetching user name: $e");
      if (mounted) _userName = "Friend";
    }
  }

  Future<void> _fetchAllEntriesAndOriginalCounts() async {
    if (_currentUser == null || !mounted) return;

    List<TimelineEntry> fetchedEntries = [];
    int tempVoiceNoteCountForSummary = 0;
    int tempMoodCheckInCountForSummary = 0;
    int tempGeneralPhotoCount = 0; // For the "Photos" count in summary

    final String userId = _currentUser!.uid;

    try {
      // 1. Fetch Mood Check-ins
      final moodSnapshot = await _firestore.collection('users').doc(userId).collection('mood_entries').get();
      tempMoodCheckInCountForSummary = moodSnapshot.docs.length;
      for (var doc in moodSnapshot.docs) {
        try {
          final entry = MoodCheckinEntry.fromJson(doc.data());
          fetchedEntries.add(TimelineEntry(id: doc.id, date: entry.entryDateTime, type: EntryType.mood, data: entry));
        } catch (e) { print("Error parsing MoodCheckinEntry ${doc.id}: $e");}
      }

      // 2. Fetch Voice Notes (Original "Reflections")
      final voiceSnapshot = await _firestore.collection('users').doc(userId).collection('voice_notes').get();
      tempVoiceNoteCountForSummary = voiceSnapshot.docs.length;
      for (var doc in voiceSnapshot.docs) {
        try {
          final entry = VoiceNoteEntry.fromJson(doc.data());
          fetchedEntries.add(TimelineEntry(id: doc.id, date: entry.entryDateTime, type: EntryType.voice, data: entry));
        } catch (e) { print("Error parsing VoiceNoteEntry ${doc.id}: $e");}
      }

      // 3. Fetch Truth Reflections
      final truthSnapshot = await _firestore.collection('users').doc(userId).collection('truthReflections').get();
      for (var doc in truthSnapshot.docs) {
        try {
          final entry = TruthReflectionEntry.fromFirestore(doc);
          fetchedEntries.add(TimelineEntry(id: doc.id, date: entry.entryDateTime, type: EntryType.truth, data: entry));
        } catch (e) { print("Error parsing TruthReflectionEntry ${doc.id}: $e");}
      }

      // 4. Fetch Completed Daily Challenges
      final challengeSnapshot = await _firestore.collection('users').doc(userId).collection('dailyChallenges').where('status', isEqualTo: 'completed').get();
      for (var doc in challengeSnapshot.docs) {
        try {
          final entry = DailyChallengeCompletionEntry.fromFirestore(doc);
          fetchedEntries.add(TimelineEntry(id: doc.id, date: entry.completedAt, type: EntryType.challenge, data: entry));
        } catch (e) { print("Error parsing DailyChallengeCompletionEntry ${doc.id}: $e");}
      }

      // 5. Fetch General Photos
      final generalPhotosSnapshot = await _firestore.collection('users').doc(userId).collection('userPhotos').get();
      tempGeneralPhotoCount = generalPhotosSnapshot.docs.length;
      for (var doc in generalPhotosSnapshot.docs) {
        try {
          final entry = GeneralPhotoEntry.fromFirestore(doc);
          fetchedEntries.add(TimelineEntry(id: doc.id, date: entry.uploadedAt, type: EntryType.photo, data: entry));
        } catch (e) { print("Error parsing GeneralPhotoEntry ${doc.id}: $e");}
      }


      fetchedEntries.sort(); // Sorts newest first

      if (mounted) {
        setState(() {
          _allEntries = fetchedEntries;
          _reflectionCount = tempVoiceNoteCountForSummary;
          _checkInCount = tempMoodCheckInCountForSummary;
          _photoCount = tempGeneralPhotoCount; // Set the photo count
        });
      }
    } catch (e) {
      print("Error fetching all entries: $e");
      if (mounted) {
        setState(() {
          _allEntries = []; _reflectionCount = 0; _checkInCount = 0; _photoCount = 0;
        });
      }
    }
  }

  Future<void> _deleteEntry(TimelineEntry entry) async {
    if (_currentUser == null || entry.id == null) return;
    String collectionName;
    switch (entry.type) {
      case EntryType.mood: collectionName = 'mood_entries'; break;
      case EntryType.voice: collectionName = 'voice_notes'; break;
      case EntryType.truth: collectionName = 'truthReflections'; break;
      case EntryType.challenge: collectionName = 'dailyChallenges'; break;
      case EntryType.photo: collectionName = 'userPhotos'; break; // Added case for photo
    }

    bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) { /* ... Confirmation Dialog (same as before) ... */
          final dialogTheme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardCornerRadius)),
            title: const Text('Delete Entry?', style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to delete this entry? This action cannot be undone.', style: TextStyle(fontFamily: _primaryFontFamily)),
            actions: <Widget>[
              TextButton(child: Text('Cancel', style: TextStyle(fontFamily: _primaryFontFamily, color: dialogTheme.hintColor)), onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(child: Text('Delete', style: TextStyle(fontFamily: _primaryFontFamily, color: dialogTheme.colorScheme.error, fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          );
        });

    if (confirmDelete == true) {
      try {
        await _firestore.collection('users').doc(_currentUser!.uid).collection(collectionName).doc(entry.id!).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry deleted.")));
          _fetchAllEntriesAndOriginalCounts();
        }
      } catch (e) {
        print("Error deleting entry: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete entry: ${e.toString()}")));
      }
    }
  }

  void _editEntry(TimelineEntry entry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Edit for ${entry.type.name} entries coming soon!")),
    );
  }

  List<BoxShadow> _getCardBoxShadow(BuildContext context) { /* ... Same ... */ return [BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 16.0, spreadRadius: 0.5, offset: const Offset(0, 8.0)), BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8.0, offset: const Offset(0, 2.0))];}

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color scaffoldBgColor = Colors.white;
    final Color primaryTextColor = Colors.black87;
    final Color secondaryTextColor = Colors.black54;
    final Color accentColor = colorScheme.primary;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white, statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white, systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    Map<String, List<TimelineEntry>> groupedEntriesByDate = {};
    for (var entry in _allEntries) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(entry.date);
      groupedEntriesByDate.putIfAbsent(formattedDate, () => []).add(entry);
    }
    List<String> sortedDates = groupedEntriesByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SafeArea(
        top: true, bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchInitialData,
          color: accentColor,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [_buildProfileButton(context, primaryTextColor)]),
                    const SizedBox(height: 5),
                    Text(
                      _userName != null && _userName != "Friend" ? "${_userName}'s Journal" : "A Look Back",
                      style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextColor),
                    ),
                    const SizedBox(height: 20),
                    _buildCombinedSummaryCard(context, reflections: _reflectionCount, checkIns: _checkInCount, photos: _photoCount, textColor: primaryTextColor, iconColor: secondaryTextColor),
                    const SizedBox(height: 10),
                    _buildStatsCard(context, colorScheme),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
              if (_allEntries.isEmpty && !_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 30.0),
                  child: Center(child: Text("No entries yet.\nYour reflections, check-ins, and completed challenges will appear here!", textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, color: secondaryTextColor))),
                )
              else
                ...sortedDates.expand((dateString) {
                  List<Widget> dateGroupWidgets = [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildDateHeader(DateTime.parse(dateString), theme, primaryTextColor, secondaryTextColor),
                    )
                  ];
                  groupedEntriesByDate[dateString]?.forEach((entry) {
                    dateGroupWidgets.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildSlidableEntryCard(entry, theme, primaryTextColor, secondaryTextColor, accentColor),
                        )
                    );
                  });
                  return dateGroupWidgets;
                }).toList(),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context, Color iconColor) { /* ... Same ... */ return Material(color: Colors.grey.shade200.withOpacity(0.85), borderRadius: BorderRadius.circular(12.0), clipBehavior: Clip.antiAlias, elevation: 1.0, shadowColor: Colors.black.withOpacity(0.1), child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())), borderRadius: BorderRadius.circular(12.0), child: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset(_profileIconAsset, height: 24, width: 24, color: iconColor.withOpacity(0.9), errorBuilder: (context, error, stackTrace) => Icon(Icons.person_outline_rounded, color: iconColor.withOpacity(0.9), size: 24)))));}
  Widget _buildCombinedSummaryCard(BuildContext context, { required int reflections, required int checkIns, required int photos, required Color textColor, required Color iconColor }) { /* ... Same (Reflections, Check-ins, Photos) ... */ return Card(elevation: 2.0, shadowColor: Colors.grey.withOpacity(0.25), clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)), color: Colors.white, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 18.0), child: IntrinsicHeight(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildSummaryItem(context, count: reflections, label: "Reflections", icon: Icons.graphic_eq_rounded, textColor: textColor, iconColor: iconColor), VerticalDivider(color: Colors.grey.shade300, thickness: 1, indent: 8, endIndent: 8), _buildSummaryItem(context, count: checkIns, label: "Check-ins", icon: Icons.sentiment_satisfied_alt_rounded, textColor: textColor, iconColor: iconColor), VerticalDivider(color: Colors.grey.shade300, thickness: 1, indent: 8, endIndent: 8), _buildSummaryItem(context, count: photos, label: "Photos", icon: Icons.photo_library_rounded, textColor: textColor, iconColor: iconColor)]))));}
  Widget _buildSummaryItem(BuildContext context, {required int count, required String label, required IconData icon, required Color textColor, required Color iconColor}) { /* ... Same ... */ return Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [Stack(alignment: Alignment.center, children: [Icon(icon, size: 36, color: iconColor.withOpacity(0.12)), Text("$count", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily, color: textColor))]), const SizedBox(height: 4), Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontFamily: _primaryFontFamily, color: textColor.withOpacity(0.75), fontWeight: FontWeight.w600, letterSpacing: 0.3))]));}
  Widget _buildStatsCard(BuildContext context, ColorScheme colorScheme) { /* ... Same ... */ return Card(elevation: 2.0, shadowColor: Colors.grey.withOpacity(0.25), clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)), child: InkWell(onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => const MoodStatisticsScreen()));}, borderRadius: BorderRadius.circular(20.0), child: Container(height: 70, padding: const EdgeInsets.symmetric(horizontal: 20.0), decoration: BoxDecoration(gradient: LinearGradient(colors: [colorScheme.primaryContainer.withOpacity(0.7), colorScheme.primary.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20.0)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text("Mood Statistics", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily)), const SizedBox(height: 2), Text("View your mood trends & insights", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer.withOpacity(0.9), fontFamily: _primaryFontFamily))]), Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.onPrimaryContainer.withOpacity(0.8), size: 20)]))));}
  Widget _buildDateHeader(DateTime date, ThemeData theme, Color primaryTextColor, Color secondaryTextColor) { /* ... Same ... */ String displayDate; if (isSameDay(date, DateTime.now())) { displayDate = "Today"; } else if (isSameDay(date, DateTime.now().subtract(const Duration(days: 1)))) { displayDate = "Yesterday"; } else { displayDate = DateFormat('MMMM d, yyyy').format(date); } return Padding(padding: const EdgeInsets.only(top: 25.0, bottom: 15.0), child: Text(displayDate, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily, color: primaryTextColor.withOpacity(0.9))));}

  // In lib/entries_screen.dart, inside _EntriesScreenState class

  Widget _buildSlidableEntryCard(TimelineEntry timelineEntry, ThemeData theme,
      Color primaryTextColor, Color secondaryTextColor, Color accentColor) {
    final ColorScheme colorScheme = theme.colorScheme;

    // Define a consistent size for the action buttons' visual effect
    // This is more about how much space they appear to take.
    // The actual tappable area is the SlidableAction.
    const double visualActionButtonWidth = 60.0; // For calculating extentRatio

    return Slidable(
      key: ValueKey(timelineEntry.id ?? UniqueKey().toString()),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        // Calculate extentRatio based on desired visual width of buttons
        // Example: Two buttons, each visually 60 wide, plus some spacing.
        // This needs to be a fraction of the total card width.
        // Let's aim for roughly 30-40% of the card width for the action pane.
        extentRatio: 0.35, // Adjust this value as needed
        children: [
          SlidableAction(
            onPressed: (context) => _editEntry(timelineEntry),
            backgroundColor: Colors.grey.shade200, // Neutral background for the button
            foregroundColor: primaryTextColor.withOpacity(0.9), // Icon color
            icon: Icons.edit_rounded,
            // label: 'Edit', // You can add labels if desired
            borderRadius: const BorderRadius.only( // Apply rounding to the action itself
                topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            padding: const EdgeInsets.all(8), // Padding around the icon/label
            flex: 1, // Distribute space if multiple actions
          ),
          // Add a small visual spacer if desired, or rely on SlidableAction's own spacing if any
          // const SizedBox(width: 1), // This won't work directly here, spacing is via flex or margins on SlidableAction
          SlidableAction(
            onPressed: (context) => _deleteEntry(timelineEntry),
            backgroundColor: colorScheme.errorContainer.withOpacity(0.9),
            foregroundColor: colorScheme.onErrorContainer,
            icon: Icons.delete_outline_rounded,
            // label: 'Delete',
            borderRadius: const BorderRadius.only( // Apply rounding to the action itself
                topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
            padding: const EdgeInsets.all(8),
            flex: 1,
          ),
        ],
      ),
      child: BouncingWidget(
        onPressed: () {
          print("Tapped on ${timelineEntry.type} entry: ${timelineEntry.id}");
          // Optional: Navigate to a detail view or other action
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 7.0), // Original margin for the card
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_cardCornerRadius),
            boxShadow: _getCardBoxShadow(context), // Your existing shadow
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildEntryContent(
                timelineEntry, theme, primaryTextColor, secondaryTextColor, accentColor),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryContent(TimelineEntry timelineEntry, ThemeData theme, Color primaryTextColor, Color secondaryTextColor, Color accentColor) {
    switch (timelineEntry.type) {
      case EntryType.mood: return _buildMoodCheckinCardContent(timelineEntry.data as MoodCheckinEntry, theme, primaryTextColor, secondaryTextColor, accentColor);
      case EntryType.voice: return _buildVoiceNoteCardContent(timelineEntry.data as VoiceNoteEntry, theme, primaryTextColor, secondaryTextColor, accentColor);
      case EntryType.truth: return _buildTruthReflectionCardContent(timelineEntry.data as TruthReflectionEntry, theme, primaryTextColor, secondaryTextColor, accentColor);
      case EntryType.challenge: return _buildDailyChallengeCardContent(timelineEntry.data as DailyChallengeCompletionEntry, theme, primaryTextColor, secondaryTextColor, accentColor);
      case EntryType.photo: return _buildGeneralPhotoCardContent(timelineEntry.data as GeneralPhotoEntry, theme, primaryTextColor, secondaryTextColor, accentColor); // New case
    }
  }

  // --- Specific Card Content Builders ---
  Widget _buildMoodCheckinCardContent(MoodCheckinEntry entry, ThemeData theme, Color primaryTextColor, Color secondaryTextColor, Color accentColor) { /* ... Same as before ... */ IconData moodIconData = (entry.moodIndex >= 0 && entry.moodIndex < _moodIconsList.length) ? _moodIconsList[entry.moodIndex] : Icons.sentiment_neutral_rounded; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(moodIconData, color: accentColor, size: 26), const SizedBox(width: 10), Expanded(child: Text(entry.title != null && entry.title!.isNotEmpty ? entry.title! : entry.moodLabel, style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600, fontSize:16.5, fontFamily: _primaryFontFamily), overflow: TextOverflow.ellipsis)), Text(DateFormat('hh:mm a').format(entry.entryDateTime), style: TextStyle(color: secondaryTextColor, fontSize: 11, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500))]), if (entry.notes != null && entry.notes!.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 36.0, top: 8.0, bottom: 8.0), child: Text(entry.notes!, style: TextStyle(color: primaryTextColor.withOpacity(0.85), fontSize: 13.5, fontFamily: _primaryFontFamily, height: 1.45), maxLines: 3, overflow: TextOverflow.ellipsis)), if (entry.selectedActivities.isNotEmpty || entry.selectedFeelings.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 36.0, top: 8), child: Wrap(spacing: 8.0, runSpacing: 6.0, children: [...entry.selectedActivities.map((activity) => _buildEntryChip(context, activity, primaryTextColor, secondaryTextColor)).toList(), ...entry.selectedFeelings.map((feeling) => _buildEntryChip(context, feeling, primaryTextColor, secondaryTextColor)).toList()]))]); }
  Widget _buildVoiceNoteCardContent(VoiceNoteEntry entry, ThemeData theme, Color primaryTextColor, Color secondaryTextColor, Color accentColor) { /* ... Same as before ... */ return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.graphic_eq_rounded, color: accentColor, size: 26), const SizedBox(width: 10), Expanded(child: Text(entry.title.isNotEmpty ? entry.title : "Voice Note", style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600, fontSize:16.5, fontFamily: _primaryFontFamily), overflow: TextOverflow.ellipsis)), Text(DateFormat('hh:mm a').format(entry.entryDateTime), style: TextStyle(color: secondaryTextColor, fontSize: 11, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500))]), if (entry.text.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 36.0, top: 8.0), child: Text(entry.text, style: TextStyle(color: primaryTextColor.withOpacity(0.85), fontSize: 13.5, fontFamily: _primaryFontFamily, height: 1.45), maxLines: 4, overflow: TextOverflow.ellipsis))]); }
  Widget _buildTruthReflectionCardContent(TruthReflectionEntry entry, ThemeData theme, Color primaryTextColor, Color secondaryTextColor, Color accentColor) { /* ... Same as before ... */ IconData themeIcon = _activityFeelingIcons[entry.dayTheme.toLowerCase()] ?? Icons.lightbulb_outline_rounded; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(themeIcon, color: accentColor, size: 26), const SizedBox(width: 10), Expanded(child: Text(entry.dayTheme, style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600, fontSize:16.5, fontFamily: _primaryFontFamily), overflow: TextOverflow.ellipsis)), Text(DateFormat('hh:mm a').format(entry.entryDateTime), style: TextStyle(color: secondaryTextColor, fontSize: 11, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500))]), if (entry.reflectionText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0, left: 36), child: Text(entry.reflectionText, style: TextStyle(color: primaryTextColor.withOpacity(0.85), fontSize: 13.5, fontFamily: _primaryFontFamily, height: 1.45), maxLines: 3, overflow: TextOverflow.ellipsis)), if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10.0, left: 36), child: ClipRRect(borderRadius: BorderRadius.circular(_cardCornerRadius * 0.6), child: CachedNetworkImage(imageUrl: entry.imageUrl!, height: 100, width: double.infinity, fit: BoxFit.cover, placeholder: (context, url) => Container(height:100, color: Colors.grey.shade200, child: Center(child: Icon(Icons.image_outlined, color: secondaryTextColor, size: 30))), errorWidget: (context, url, error) => Container(height:100, color: Colors.grey.shade200, child: Center(child: Icon(Icons.broken_image_outlined, color: secondaryTextColor, size: 30))))))]); }
  Widget _buildDailyChallengeCardContent(DailyChallengeCompletionEntry entry, ThemeData theme, Color primaryTextColor, Color secondaryTextColor, Color accentColor) { /* ... Same as before ... */ return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.flag_circle_rounded, color: accentColor, size: 26), const SizedBox(width: 10), Expanded(child: Text("Daily Challenge Completed!", style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600, fontSize:16.5, fontFamily: _primaryFontFamily), overflow: TextOverflow.ellipsis)), Text(DateFormat('hh:mm a').format(entry.completedAt), style: TextStyle(color: secondaryTextColor, fontSize: 11, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500))]), Padding(padding: const EdgeInsets.only(top:8.0, left: 36, bottom: 10), child: Text(entry.challengeDescription, style: TextStyle(color: primaryTextColor.withOpacity(0.80), fontStyle: FontStyle.italic, fontSize: 13, fontFamily: _primaryFontFamily, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)), Padding(padding: const EdgeInsets.only(left: 36), child: ClipRRect(borderRadius: BorderRadius.circular(_cardCornerRadius*0.6), child: CachedNetworkImage(imageUrl: entry.photoUrl, height: 120, width: double.infinity, fit: BoxFit.cover, placeholder: (context, url) => Container(height:120, color: Colors.grey.shade200, child: Center(child: Icon(Icons.image_outlined, color: secondaryTextColor, size: 30))), errorWidget: (context, url, error) => Container(height:120, color: Colors.grey.shade200, child: Center(child: Icon(Icons.broken_image_outlined, color: secondaryTextColor, size: 30))))))]); }

  // --- NEW Card Content Builder for General Photos ---
  Widget _buildGeneralPhotoCardContent(GeneralPhotoEntry entry, ThemeData theme, Color primaryTextColor, Color secondaryTextColor, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_activityFeelingIcons['photo'] ?? Icons.photo_library_outlined, color: accentColor, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Photo Entry", // Or a caption if you add it
                style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600, fontSize: 16.5, fontFamily: _primaryFontFamily),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              DateFormat('hh:mm a').format(entry.uploadedAt),
              style: TextStyle(color: secondaryTextColor, fontSize: 11, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10.0, left: 0), // Align image with card edge
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_cardCornerRadius * 0.7), // Slightly smaller radius for inner image
            child: CachedNetworkImage(
              imageUrl: entry.imageUrl,
              // Decide on a consistent height for photo entries or make it dynamic
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  height: 150,
                  color: Colors.grey.shade200,
                  child: Center(child: Icon(Icons.image_outlined, color: secondaryTextColor, size: 30))),
              errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: Colors.grey.shade200,
                  child: Center(child: Icon(Icons.broken_image_outlined, color: secondaryTextColor, size: 30))),
            ),
          ),
        ),
        // If you add captions in the future, display them here
        // if (entry.caption != null && entry.caption!.isNotEmpty)
        //   Padding(padding: const EdgeInsets.only(left: 36.0, top: 8.0), child: Text(entry.caption!, ...)),
      ],
    );
  }


  Widget _buildEntryChip(BuildContext context, String label, Color primaryTextColor, Color secondaryTextColor) { /* ... Same ... */ IconData? chipIcon = _activityFeelingIcons[label.toLowerCase()]; return Chip(avatar: chipIcon != null ? Icon(chipIcon, size: 15, color: secondaryTextColor.withOpacity(0.9)) : null, label: Text(label, style: TextStyle(fontSize: 11, color: primaryTextColor.withOpacity(0.85), fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500)), backgroundColor: Colors.grey.shade100, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0), side: BorderSide(color: Colors.grey.shade200, width: 0.8)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: EdgeInsets.symmetric(horizontal: chipIcon != null ? 7.0 : 9.0, vertical: 4.5));}
  bool isSameDay(DateTime? a, DateTime? b) { /* ... Same ... */ if (a == null || b == null) return false; return a.year == b.year && a.month == b.month && a.day == b.day;}
}
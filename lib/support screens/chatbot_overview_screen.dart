// lib/support screens/chatbot_overview_screen.dart
// This screen will now function as a "Self Care" overview.

import 'package:counsellorconnect/self_care/screens/general_chatbot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';
// Remove profile_screen import if not used on this specific screen (back button handles navigation)
// import '../profile_screen.dart';

// Import the renamed model and the detail screen (conceptually renamed)
import 'models/chatbot_info.dart'; // Path is the same, but class inside is SelfCareItem
import 'specific_chatbot_screen.dart'; // This will display SelfCareItem details

import '../widgets/bouncing_widget.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _cardCornerRadius = 24.0;
const double _conceptualOverlap = 20.0;
const double _iconContainerSize = 48.0;
const double _iconContainerRadius = 12.0;
// --- End Constants ---

class ChatbotOverviewScreen extends StatefulWidget { // Keep class name for now to avoid breaking imports elsewhere, will be SelfCareOverviewScreen
  const ChatbotOverviewScreen({Key? key}) : super(key: key);

  @override
  State<ChatbotOverviewScreen> createState() => _ChatbotOverviewScreenState();
}

class _ChatbotOverviewScreenState extends State<ChatbotOverviewScreen> {
  // Use SelfCareItem instead of ChatbotInfo
  late List<SelfCareItem> _allItems;
  List<SelfCareItem> _specialItems = [];
  List<SelfCareItem> _categoryItems = [];


  @override
  void initState() {
    super.initState();
    _allItems = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final colorScheme = Theme.of(context).colorScheme;
      // Define all self-care items here
      _allItems = [
        // Quick Access (kept for structure, adapt their purpose as needed)
        SelfCareItem(
            id: 'general_assistant', // Use a specific ID
            name: 'General Assistant',
            subtitle: 'Talk about anything', // Or "Your AI helper"
            icon: Icons.support_agent_rounded, // Or a more generic chat icon
            gradientColors: [colorScheme.primary.withOpacity(0.8), colorScheme.primary.withOpacity(0.6)]
        ),
        SelfCareItem(id: 'favorites', name: 'My Favorites', subtitle: 'Your saved items', icon: Icons.favorite_rounded, gradientColors: [colorScheme.secondary.withOpacity(0.8), colorScheme.secondary.withOpacity(0.6)]),

        // New Self Care Items based on images
        // You'll need to choose appropriate icons and gradients for each

        SelfCareItem(id: 'productivity_pack', name: 'Productivity Pack', subtitle: '8 EXERCISES', icon: Icons.rocket_launch_outlined, gradientColors: [Colors.blueGrey.shade500, Colors.blueGrey.shade700]),
        SelfCareItem(id: 'beat_stress', name: 'Beat Stress', subtitle: '14 EXERCISES', icon: Icons.sentiment_neutral_outlined, gradientColors: [Colors.cyan.shade500, Colors.cyan.shade700]),
        SelfCareItem(id: 'calm_your_mind', name: 'Calm your Mind', subtitle: '10 EXERCISES', icon: Icons.nightlight_outlined, gradientColors: [Colors.indigo.shade400, Colors.indigo.shade700]),
        SelfCareItem(id: 'inspire_yourself', name: 'Inspire Yourself', subtitle: '6 EXERCISES', icon: Icons.lightbulb_circle_outlined, gradientColors: [Colors.green.shade300, Colors.teal.shade500]),

        SelfCareItem(id: 'manage_anger', name: 'Manage Anger', subtitle: '7 EXERCISES', icon: Icons.local_fire_department_outlined, gradientColors: [Colors.red.shade400, Colors.red.shade700]),
        SelfCareItem(id: 'put_mind_to_ease', name: 'Put Your Mind to Ease', subtitle: '8 EXERCISES', icon: Icons.spa_outlined, gradientColors: [Colors.teal.shade200, Colors.teal.shade400]),
        SelfCareItem(id: 'assess_yourself', name: 'Assess Yourself', subtitle: '7 EXERCISES', icon: Icons.psychology_outlined, gradientColors: [Colors.green.shade400, Colors.green.shade600]),
        SelfCareItem(id: 'for_being_mindful', name: 'For Being Mindful', subtitle: '5 EXERCISES', icon: Icons.self_improvement_outlined, gradientColors: [Colors.lightBlue.shade400, Colors.lightBlue.shade600]),

        SelfCareItem(id: 'health_anxiety', name: 'For Health Anxiety', subtitle: '9 EXERCISES', icon: Icons.monitor_heart_outlined, gradientColors: [Colors.lightBlue.shade300, Colors.lightBlue.shade500]),
        SelfCareItem(id: 'deep_sleep', name: 'For Deep Sleep', subtitle: '8 EXERCISES', icon: Icons.bedtime_outlined, gradientColors: [Colors.deepPurple.shade400, Colors.indigo.shade600]),
        SelfCareItem(id: 'build_confidence', name: 'Build Confidence', subtitle: '8 EXERCISES', icon: Icons.emoji_events_outlined, gradientColors: [Colors.amber.shade400, Colors.orange.shade600]),
        SelfCareItem(id: 'sleep_habit_pack', name: 'Sleep Habit Pack', subtitle: '8 EXERCISES', icon: Icons.nightlight_round_outlined, gradientColors: [Colors.blueGrey.shade400, Colors.blueGrey.shade600]),

        // Add more items from your images...
        // Example for "Sleep Sounds" which has a different subtitle format
        SelfCareItem(id: 'sleep_sounds', name: 'Sleep Sounds', subtitle: '18 AUDIOS', icon: Icons.music_note_outlined, gradientColors: [Colors.blue.shade700, Colors.blue.shade900]),
        SelfCareItem(id: 'sleep_stories', name: 'Sleep Stories', subtitle: '33 STORIES', icon: Icons.book_outlined, gradientColors: [Colors.purple.shade700, Colors.purple.shade900]),

        SelfCareItem(id: 'overcome_grief', name: 'Overcome Grief', subtitle: '8 EXERCISES', icon: Icons.healing_outlined, gradientColors: [Colors.deepPurple.shade300, Colors.deepPurple.shade500]),
        SelfCareItem(id: 'for_trauma', name: 'For Trauma', subtitle: '5 EXERCISES', icon: Icons.sentiment_very_dissatisfied_outlined, gradientColors: [Colors.indigo.shade300, Colors.indigo.shade500]),
        SelfCareItem(id: 'for_breakups', name: 'For Breakups', subtitle: '9 EXERCISES', icon: Icons.heart_broken_outlined, gradientColors: [Colors.red.shade300, Colors.red.shade500]),
        SelfCareItem(id: 'relationship_pack', name: 'Relationship Pack', subtitle: '9 EXERCISES', icon: Icons.people_alt_outlined, gradientColors: [Colors.orange.shade300, Colors.orange.shade500]),

        SelfCareItem(id: 'for_pregnancy', name: 'For Pregnancy', subtitle: '9 EXERCISES', icon: Icons.pregnant_woman_rounded, gradientColors: [Colors.pink.shade300, Colors.pink.shade500]),
        SelfCareItem(id: 'for_students', name: 'For Students', subtitle: '9 EXERCISES', icon: Icons.school_outlined, gradientColors: [Colors.blue.shade300, Colors.blue.shade500]),
        SelfCareItem(id: 'overcome_loneliness', name: 'Overcome Loneliness', subtitle: '7 EXERCISES', icon: Icons.group_outlined, gradientColors: [Colors.teal.shade300, Colors.teal.shade500]),
        SelfCareItem(id: 'financial_anxiety', name: 'For Financial Anxiety', subtitle: '5 EXERCISES', icon: Icons.attach_money_rounded, gradientColors: [Colors.green.shade300, Colors.green.shade500]),






        // ... Continue adding all items from the images
      ];

      setState(() {
        _specialItems = _allItems.where((item) => item.id == 'general_assistant' || item.id == 'favorites').toList();
        _categoryItems = _allItems.where((item) => item.id != 'general_assistant' && item.id != 'favorites').toList();
      });
    });
  }

  

  List<BoxShadow> _getCardShadow(BuildContext context, {Color? shadowColorHint}) {
    final theme = Theme.of(context);
    Color baseShadowColor = shadowColorHint?.withOpacity(0.35) ?? Colors.black.withOpacity(0.18);
    if (theme.brightness == Brightness.dark) {
      baseShadowColor = shadowColorHint?.withOpacity(0.6) ?? Colors.black.withOpacity(0.35);
    }
    return [
      BoxShadow(
        color: baseShadowColor,
        blurRadius: 20,
        spreadRadius: 1,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: baseShadowColor.withOpacity(0.1),
        blurRadius: 10.0,
        offset: const Offset(0, 4.0),
      ),
    ];
  }

  Widget _buildBackButton(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.8);
    final profileButtonBg = theme.brightness == Brightness.light
        ? Colors.grey.shade200
        : theme.colorScheme.surfaceContainerHighest;

    return BouncingWidget(
      onPressed: () {
        Navigator.pop(context);
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: profileButtonBg,
          borderRadius: BorderRadius.circular(12.0),
          clipBehavior: Clip.antiAlias,
          elevation: 1.0,
          shadowColor: theme.shadowColor.withOpacity(0.1),
          child: Icon(Icons.arrow_back_ios_new, color: iconColor, size: 20),
        ),
      ),
    );
  }


  // Renamed navigation method
  void _navigateToSelfCareItemDetail(BuildContext context, SelfCareItem item) {
    if (item.id == 'general_assistant') { // Check for the specific ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GeneralChatbotScreen(item: item),
        ),
      );
    } else {
      // Navigate to your existing SelfCareItemDetailScreen for other items
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelfCareItemDetailScreen(item: item),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    ));

    if (_allItems.isEmpty) {
      return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(child: CircularProgressIndicator(color: colorScheme.primary))
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 10,
                left: 16,
                right: 16,
                bottom: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBackButton(context), // Keep back button
                ],
              ),
            ),
          ),
          SliverToBoxAdapter( // Updated Title Section
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0, bottom: _conceptualOverlap + 15),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text( // Large Faded Text
                    "SELF CARE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 64, // Adjusted size
                      fontWeight: FontWeight.w900,
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.displayLarge?.color?.withOpacity(0.05),
                      height: 0.8,
                    ),
                  ),
                  Transform.translate( // Prominent Title
                    offset: const Offset(0, -2),
                    child: Text(
                      "Self Care Exercises",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: _primaryFontFamily,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color?.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_specialItems.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 18.0,
                  mainAxisSpacing: 18.0,
                  childAspectRatio: 0.85, // Adjust aspect ratio if needed
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final item = _specialItems[index];
                    // Use _buildSelfCareItemCard instead of _buildChatbotCard
                    return _buildSelfCareItemCard(context, item, theme, colorScheme);
                  },
                  childCount: _specialItems.length,
                ),
              ),
            ),

          if (_specialItems.isNotEmpty && _categoryItems.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                child: Divider(thickness: 0.7),
              ),
            ),

          if (_categoryItems.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 18.0,
                  mainAxisSpacing: 18.0,
                  childAspectRatio: 0.85, // Adjust aspect ratio
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final item = _categoryItems[index];
                    // Use _buildSelfCareItemCard
                    return _buildSelfCareItemCard(context, item, theme, colorScheme);
                  },
                  childCount: _categoryItems.length,
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 30)),
        ],
      ),
    );
  }

  // Renamed card builder method
  Widget _buildSelfCareItemCard(
      BuildContext context,
      SelfCareItem item, // Use SelfCareItem model
      ThemeData theme,
      ColorScheme colorScheme) {

    Color contentColor = ThemeData.estimateBrightnessForColor(item.gradientColors.first) == Brightness.dark
        ? Colors.white.withOpacity(0.95)
        : Colors.black.withOpacity(0.85);

    return BouncingWidget(
      onPressed: () => _navigateToSelfCareItemDetail(context, item), // Use renamed navigation
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: item.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(_cardCornerRadius),
          boxShadow: _getCardShadow(context, shadowColorHint: item.gradientColors.last.withOpacity(0.6)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_cardCornerRadius),
          child: InkWell(
            onTap: () => _navigateToSelfCareItemDetail(context, item), // Use renamed navigation
            borderRadius: BorderRadius.circular(_cardCornerRadius),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: _iconContainerSize,
                        height: _iconContainerSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(_iconContainerRadius),
                        ),
                        child: Icon(item.icon, size: 26, color: contentColor),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 18, color: contentColor.withOpacity(0.7)),
                    ],
                  ),
                  const Spacer(), // Pushes text to bottom
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 17, // Adjust as needed
                          fontWeight: FontWeight.bold,
                          fontFamily: _primaryFontFamily,
                          color: contentColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text( // Using subtitle field from SelfCareItem
                        item.subtitle,
                        style: TextStyle(
                            fontSize: 11, // Smaller font for subtitle
                            fontFamily: _primaryFontFamily,
                            color: contentColor.withOpacity(0.9),
                            fontWeight: FontWeight.w600, // Bolder subtitle
                            letterSpacing: 0.5,
                            height: 1.3
                        ),
                        maxLines: 1, // Subtitle usually one line
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
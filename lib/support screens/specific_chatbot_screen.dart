// lib/support screens/self_care_item_detail_screen.dart
// Or preferably: lib/self_care/self_care_item_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Assuming SelfCareItem is in models/ within the same parent directory or updated path
import 'models/chatbot_info.dart'; // This file now contains the SelfCareItem class
// Or if you moved it: import '../models/self_care_item_model.dart';

import '../theme/theme_provider.dart';
// Potentially import widgets for specific content types if they become complex
// import 'widgets/audio_player_widget.dart';
// import 'widgets/exercise_card_widget.dart';

const String _primaryFontFamily = 'Nunito';

class SelfCareItemDetailScreen extends StatefulWidget { // Changed to StatefulWidget for potential internal state
  final SelfCareItem item;

  const SelfCareItemDetailScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<SelfCareItemDetailScreen> createState() => _SelfCareItemDetailScreenState();
}

class _SelfCareItemDetailScreenState extends State<SelfCareItemDetailScreen> {
  // Example: State for loading content if fetched from Firestore
  bool _isLoadingContent = false;
  List<Map<String, String>> _exercises = []; // Example: {'title': 'Breathing Exercise', 'description': '...'}
  List<String> _audioUrls = []; // Example
  String? _storyText;       // Example

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    // This is where you'd fetch content based on widget.item.id or widget.item.subtitle
    // For now, let's use dummy data based on subtitle type
    if (!mounted) return;

    setState(() {
      _isLoadingContent = true;
    });

    // Simulate fetching or loading data
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network/file load

    if (widget.item.subtitle.toUpperCase().contains("EXERCISES")) {
      // Dummy exercise data
      _exercises = List.generate(
          int.tryParse(widget.item.subtitle.split(" ")[0]) ?? 5, // Get count from subtitle
              (index) => {
            'title': '${widget.item.name} Exercise ${index + 1}',
            'description': 'Detailed instructions for exercise ${index + 1} go here. Focus on technique and mindfulness.',
            'duration': '${(index % 3 + 2) * 5} min' // e.g., 10 min, 15 min, 5 min
          }
      );
    } else if (widget.item.subtitle.toUpperCase().contains("AUDIOS")) {
      // Dummy audio data
      _audioUrls = List.generate(
          int.tryParse(widget.item.subtitle.split(" ")[0]) ?? 3,
              (index) => 'sample_audio_url_${index + 1}.mp3' // Placeholder URLs
      );
    } else if (widget.item.subtitle.toUpperCase().contains("STORIES")) {
      _storyText = "Once upon a time, in a land of tranquility, began a story about ${widget.item.name.toLowerCase()}... (Full story content would go here)";
    }
    // Add more conditions for other types of content

    if (mounted) {
      setState(() {
        _isLoadingContent = false;
      });
    }
  }


  Widget _buildContentArea(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoadingContent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.item.subtitle.toUpperCase().contains("EXERCISES") && _exercises.isNotEmpty) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(), // If inside SingleChildScrollView
        itemCount: _exercises.length,
        itemBuilder: (context, index) {
          final exercise = _exercises[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: widget.item.gradientColors.isNotEmpty ? widget.item.gradientColors.last.withOpacity(0.7) : colorScheme.primaryContainer,
                foregroundColor: widget.item.gradientColors.isNotEmpty ? (ThemeData.estimateBrightnessForColor(widget.item.gradientColors.last) == Brightness.dark ? Colors.white70 : Colors.black87) : colorScheme.onPrimaryContainer,
                child: Text("${index + 1}", style: const TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold)),
              ),
              title: Text(exercise['title']!, style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, color: theme.textTheme.titleMedium?.color)),
              subtitle: Text(exercise['description']!, style: TextStyle(fontFamily: _primaryFontFamily, color: theme.textTheme.bodyMedium?.color, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis,),
              trailing: Text(exercise['duration']!, style: TextStyle(fontFamily: _primaryFontFamily, color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
              onTap: () {
                // Potentially navigate to a more detailed exercise screen
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Tapped on ${exercise['title']!}"))
                );
              },
            ),
          );
        },
      );
    } else if (widget.item.subtitle.toUpperCase().contains("AUDIOS") && _audioUrls.isNotEmpty) {
      return Column(
        children: _audioUrls.map((url) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 2.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.play_circle_fill_rounded, color: widget.item.gradientColors.isNotEmpty ? widget.item.gradientColors.last : colorScheme.primary, size: 36,),
            title: Text("Audio Track: ${url.split('_').last.split('.').first}", style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.w600)),
            subtitle: Text("Tap to play (audio player placeholder)", style: TextStyle(fontFamily: _primaryFontFamily)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Play $url (Implement audio player)"))
              );
            },
          ),
        )).toList(),
      );
    } else if (widget.item.subtitle.toUpperCase().contains("STORIES") && _storyText != null) {
      return Text(
        _storyText!,
        style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, height: 1.6, color: theme.textTheme.bodyLarge?.color),
      );
    }

    // Default placeholder if no specific content type matches
    return Text(
      'Detailed content for "${widget.item.name}" (${widget.item.subtitle}) will be displayed here. This could be a list of exercises, an audio player, an article, etc.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        fontFamily: _primaryFontFamily,
        color: theme.textTheme.bodyMedium?.color,
        height: 1.5,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false); // listen:false if not reacting to theme changes within build
    final colorScheme = theme.colorScheme;

    final Brightness appBarBrightness = ThemeData.estimateBrightnessForColor(
        widget.item.gradientColors.isNotEmpty ? widget.item.gradientColors.first : themeProvider.currentAccentGradient.first
    );
    final Color appBarContentColor =
    appBarBrightness == Brightness.dark ? Colors.white : Colors.black87;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: appBarBrightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: widget.item.gradientColors.isNotEmpty
                    ? widget.item.gradientColors
                    : themeProvider.currentAccentGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: appBarContentColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.item.name,
          style: TextStyle(
            fontFamily: _primaryFontFamily,
            fontWeight: FontWeight.bold,
            color: appBarContentColor,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 1.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 10), // Reduced top space
            Container(
              padding: const EdgeInsets.all(12), // Smaller padding for icon container
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.item.gradientColors.isNotEmpty
                      ? widget.item.gradientColors.last.withOpacity(0.15) // Softer background
                      : colorScheme.primaryContainer.withOpacity(0.4),
                  boxShadow: [
                    BoxShadow(
                        color: (widget.item.gradientColors.isNotEmpty ? widget.item.gradientColors.last : colorScheme.primary).withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: Offset(0,3)
                    )
                  ]
              ),
              child: Icon(
                widget.item.icon,
                size: 48, // Slightly smaller icon
                color: widget.item.gradientColors.isNotEmpty
                    ? (ThemeData.estimateBrightnessForColor(widget.item.gradientColors.last) == Brightness.dark
                    ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.7))
                    : colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.item.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22, // Maintained size
                fontWeight: FontWeight.bold,
                fontFamily: _primaryFontFamily,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.item.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, // Slightly smaller subtitle
                fontFamily: _primaryFontFamily,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 25),
            Divider(color: theme.dividerColor.withOpacity(0.5), thickness: 0.8),
            const SizedBox(height: 20),

            // Dynamic Content Area
            _buildContentArea(theme, colorScheme),

            const SizedBox(height: 30), // Bottom padding
          ],
        ),
      ),
    );
  }
}
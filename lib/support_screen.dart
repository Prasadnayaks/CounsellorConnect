// lib/support_screen.dart
import 'package:counsellorconnect/support%20screens/chatbot_overview_screen.dart';
import 'package:counsellorconnect/support%20screens/user_chat_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/theme_provider.dart';
import 'support screens/appointment_screen.dart';
//import 'support screens/chatbot_screen.dart';
import 'profile_screen.dart'; // For profile navigation
import 'widgets/bouncing_widget.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _cardElevation = 0.0; // Shadow will be handled by a BoxDecoration
const double _cardCornerRadius = 24.0; // Increased for more curve
const double _conceptualOverlap = 20.0; // For title overlap effect
const double _iconContainerSize = 48.0; // For squarish icon container
const double _iconContainerRadius = 12.0; // Radius for icon container
// --- End Constants ---

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  // Updated shadow to be more like home_screen's enhanced shadow
  List<BoxShadow> _getCardShadow(BuildContext context, {Color? shadowColorHint}) {
    final theme = Theme.of(context);
    // Use a slightly darker shadow for more pop, or hint from theme accent
    Color baseShadowColor = shadowColorHint?.withOpacity(0.35) ?? Colors.black.withOpacity(0.18);
    if (theme.brightness == Brightness.dark) {
      baseShadowColor = shadowColorHint?.withOpacity(0.6) ?? Colors.black.withOpacity(0.35);
    }
    return [
      BoxShadow(
        color: baseShadowColor,
        blurRadius: 20, // Increased blur for 3D effect
        spreadRadius: 1,  // Slight spread
        offset: const Offset(0, 8), // Increased Y offset
      ),
      BoxShadow( // Softer ambient shadow
        color: baseShadowColor.withOpacity(0.1),
        blurRadius: 10.0,
        offset: const Offset(0, 4.0),
      ),
    ];
  }

  Widget _buildProfileButton(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.8);
    final profileButtonBg = theme.brightness == Brightness.light
        ? Colors.grey.shade200
        : theme.colorScheme.surfaceContainerHighest;

    return BouncingWidget(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
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
          child: Icon(Icons.person_outline_rounded, color: iconColor, size: 26),
        ),
      ),
    );
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

    // Define gradients for cards - using theme colors for consistency
    final List<Gradient> cardGradients = [
      LinearGradient( // Appointments
        colors: [colorScheme.primary.withOpacity(0.85), colorScheme.primary.withOpacity(0.65)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      LinearGradient( // Live Chats
        colors: [colorScheme.secondary.withOpacity(0.85), colorScheme.secondary.withOpacity(0.65)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      LinearGradient( // Chatbots
        colors: [colorScheme.tertiary.withOpacity(0.85), colorScheme.tertiary.withOpacity(0.65)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
    ];


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
                  const SizedBox(width: 44),
                  const Spacer(),
                  const Spacer(),
                  _buildProfileButton(context),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0, bottom: _conceptualOverlap + 15),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    "SUPPORT",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.displayLarge?.color?.withOpacity(0.05),
                      height: 0.8,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -2),
                    child: Text(
                      "Live Support",
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

          SliverPadding(
            // Adjusted padding to make cards slightly less wide
            padding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  _buildSupportCard(
                    context: context,
                    title: 'Appointments',
                    icon: Icons.calendar_today_rounded,
                    gradient: cardGradients[0],
                    contentColor: getOnCardColor(cardGradients[0].colors.first),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AppointmentScreen()),
                      );
                    },
                    description: 'Book or manage your sessions with counselors.',
                  ),
                  const SizedBox(height: 28), // Increased spacing
                  _buildSupportCard(
                    context: context,
                    title: 'Live Chats',
                    icon: Icons.chat_bubble_rounded,
                    gradient: cardGradients[1],
                    contentColor: getOnCardColor(cardGradients[1].colors.first),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserChatOverviewScreen()),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Find a counselor to chat with from the appointments screen.")),
                      );
                    },
                    description: 'Connect with counselors via direct messages.',
                  ),
                  const SizedBox(height: 28), // Increased spacing
                  _buildSupportCard(
                    context: context,
                    title: 'Self-Care',
                    icon: Icons.self_improvement,
                    gradient: cardGradients[2],
                    contentColor: getOnCardColor(cardGradients[2].colors.first),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChatbotOverviewScreen()),
                      );
                    },
                    description: 'Get instant help from our Self-care bots and Exercises.',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Gradient gradient,
    required Color contentColor,
    required VoidCallback onTap,
    required String description,
  }) {
    return BouncingWidget(
      onPressed: onTap,
      child: Container(
        height: 175, // Slightly reduced height
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(_cardCornerRadius), // Increased radius
          boxShadow: _getCardShadow(context, shadowColorHint: gradient.colors.last.withOpacity(0.6)), // Enhanced shadow
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_cardCornerRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_cardCornerRadius),
            child: Padding(
              padding: const EdgeInsets.all(20.0), // Adjusted padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container( // Squarish icon container
                        width: _iconContainerSize,
                        height: _iconContainerSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20), // Slightly more opaque
                          borderRadius: BorderRadius.circular(_iconContainerRadius), // Rounded square
                        ),
                        child: Icon(icon, size: 26, color: contentColor), // Adjusted icon size
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 20, color: contentColor.withOpacity(0.8)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20, // Reduced title font size
                          fontWeight: FontWeight.bold,
                          fontFamily: _primaryFontFamily,
                          color: contentColor,
                        ),
                      ),
                      const SizedBox(height: 5), // Adjusted spacing
                      Text(
                        description,
                        style: TextStyle(
                            fontSize: 13, // Reduced description font size
                            fontFamily: _primaryFontFamily,
                            color: contentColor.withOpacity(0.9),
                            height: 1.3
                        ),
                        maxLines: 2,
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

  Color getOnCardColor(Color cardBackgroundColor) {
    return ThemeData.estimateBrightnessForColor(cardBackgroundColor) == Brightness.dark
        ? Colors.white.withOpacity(0.95)
        : Colors.black.withOpacity(0.85);
  }
}

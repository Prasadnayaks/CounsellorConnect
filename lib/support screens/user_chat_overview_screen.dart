// lib/user_chat_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Only for ChatRoomModel, not direct queries here
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/theme_provider.dart';
import 'chat_screen.dart'; // To navigate to individual chat
import '../profile_screen.dart'; // For profile navigation
import '../models/chat_room_model.dart'; // Your ChatRoomModel
import '../services/chat_service.dart'; // Your ChatService
import '../widgets/bouncing_widget.dart'; // For tap animation

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _cardCornerRadius = 24.0; // Increased for more curve
const double _conceptualOverlap = 20.0;
const double _avatarContainerSize = 52.0; // For squarish avatar container
const double _avatarContainerRadius = 14.0; // Radius for avatar container
// --- End Constants ---

class UserChatOverviewScreen extends StatefulWidget {
  const UserChatOverviewScreen({Key? key}) : super(key: key);

  @override
  State<UserChatOverviewScreen> createState() => _UserChatOverviewScreenState();
}

class _UserChatOverviewScreenState extends State<UserChatOverviewScreen> {
  final ChatService _chatService = ChatService();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser == null) {
      // Handle case where user is not logged in, though ideally this screen
      // wouldn't be accessible if not logged in.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Authentication error. Please re-login.")),
          );
          // Potentially navigate away or show a login prompt
        }
      });
    }
  }

  // Helper for card shadows, similar to home_screen or support_screen
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
        Navigator.pop(
          context,
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
          child: Icon(Icons.arrow_back_ios_new, color: iconColor, size: 20),
        ),
      ),
    );
  }

  void _navigateToChat(BuildContext context, ChatRoomModel chatRoom) {
    if (_currentUser == null || !mounted) return;

    // Determine the other participant's ID, name, and photo URL
    // This logic assumes a 1-to-1 chat.
    String otherParticipantId = '';
    if (chatRoom.participantIds.length == 2) {
      otherParticipantId = chatRoom.participantIds.firstWhere(
            (id) => id != _currentUser!.uid,
        orElse: () => '', // Should not happen in a valid 1-to-1 chat room
      );
    }

    if (otherParticipantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not identify the other participant.")),
      );
      return;
    }

    // Use methods from ChatRoomModel to get counselor's details
    String counselorName = chatRoom.getOtherParticipantName(_currentUser!.uid);
    String? counselorPhotoUrl = chatRoom.getOtherParticipantPhotoUrl(_currentUser!.uid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          // For a user chatting with a counselor, the 'counselorId' is the otherParticipantId
          counselorId: otherParticipantId,
          counselorName: counselorName,
          counselorPhotoUrl: counselorPhotoUrl,
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

    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: Text("Please log in to view your chats.", style: TextStyle(fontFamily: _primaryFontFamily))),
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
                  //const SizedBox(width: 44), // Spacer for balance
                  //const Spacer(),
                  //const Spacer(),
                  _buildBackButton(context),
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
                    "MESSAGES", // Large Faded Text
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
                      "Your Chats", // Prominent Title
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
          StreamBuilder<List<ChatRoomModel>>(
            // IMPORTANT: Replace with your actual stream for fetching USER's chat rooms
            // stream: _chatService.getUserChatRoomsStream(), // Example
            stream: _chatService.getCounselorChatRoomsStream(), // Placeholder, assuming it can be adapted or you create a new one
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                print("Error fetching user chats: ${snapshot.error}");
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "Could not load chats.\nPlease try again later.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: _primaryFontFamily, color: theme.hintColor),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 60, color: theme.hintColor.withOpacity(0.45)),
                          const SizedBox(height: 20),
                          Text(
                            'No Conversations Yet',
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontFamily: _primaryFontFamily,
                                color: theme.textTheme.titleMedium?.color?.withOpacity(0.75)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "When you start a chat with a counselor, it will appear here.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: _primaryFontFamily,
                                fontSize: 15,
                                color: theme.hintColor,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final chatRooms = snapshot.data!;
              // Sort chats: unread first, then by last message timestamp
              chatRooms.sort((a, b) {
                bool aHasUnread = a.getUnreadCountForUser(_currentUser!.uid) > 0 && a.status == 'active';
                bool bHasUnread = b.getUnreadCountForUser(_currentUser!.uid) > 0 && b.status == 'active';
                if (aHasUnread && !bHasUnread) return -1; // a comes first
                if (!aHasUnread && bHasUnread) return 1;  // b comes first
                // If both have same unread status, sort by latest message
                return (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt);
              });


              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final chatRoom = chatRooms[index];
                      // Skip chat rooms that are not 'active' or 'pending_user_request' from user's perspective
                      // (e.g. if counselor declined and user hasn't re-initiated)
                      if (chatRoom.status != 'active' && chatRoom.status != 'pending_user_request' && chatRoom.status != 'declined_by_counselor') {
                        // 'declined_by_counselor' is shown so user knows the status
                        if (chatRoom.lastMessageSenderId == _currentUser!.uid && chatRoom.status == 'pending_user_request') {
                          // This is a request the user sent, show it
                        } else if (chatRoom.status == 'declined_by_counselor') {
                          // Show declined chats
                        }
                        else {
                          return const SizedBox.shrink(); // Don't show other non-active states unless user initiated
                        }
                      }

                      return _buildChatListItem(context, chatRoom, theme, colorScheme);
                    },
                    childCount: chatRooms.length,
                  ),
                ),
              );
            },
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 30)), // For bottom nav bar
        ],
      ),
    );
  }

  Widget _buildChatListItem(
      BuildContext context,
      ChatRoomModel chatRoom,
      ThemeData theme,
      ColorScheme colorScheme) {
    if (_currentUser == null) return const SizedBox.shrink();

    final String counselorName = chatRoom.getOtherParticipantName(_currentUser!.uid);
    final String? counselorPhotoUrl = chatRoom.getOtherParticipantPhotoUrl(_currentUser!.uid);
    final int unreadCount = chatRoom.getUnreadCountForUser(_currentUser!.uid);
    final bool hasUnread = unreadCount > 0 && chatRoom.status == 'active';

    String subtitleText = chatRoom.lastMessageText ?? "No messages yet.";
    if (chatRoom.status == 'pending_user_request' && chatRoom.lastMessageSenderId == _currentUser!.uid) {
      subtitleText = "You sent a request...";
    } else if (chatRoom.status == 'declined_by_counselor') {
      subtitleText = "Request declined by counselor.";
    } else if (chatRoom.lastMessageSenderId == _currentUser!.uid && chatRoom.status == 'active') {
      subtitleText = "You: $subtitleText";
    }
    // Trim subtitle if too long
    if (subtitleText.length > 35) subtitleText = "${subtitleText.substring(0, 32)}...";


    Color cardBackgroundColor = theme.cardColor;
    Color contentColor = theme.colorScheme.onSurface;
    List<BoxShadow> boxShadow = _getCardShadow(context);

    // Highlight card if there are unread messages
    if (hasUnread) {
      cardBackgroundColor = colorScheme.primaryContainer.withOpacity(0.7);
      contentColor = colorScheme.onPrimaryContainer;
      boxShadow = _getCardShadow(context, shadowColorHint: colorScheme.primary);
    }


    return BouncingWidget(
      onPressed: () => _navigateToChat(context, chatRoom),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0), // Spacing between cards
        height: 100, // Adjusted height for chat items
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(_cardCornerRadius),
          boxShadow: boxShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_cardCornerRadius),
          child: InkWell(
            onTap: () => _navigateToChat(context, chatRoom),
            borderRadius: BorderRadius.circular(_cardCornerRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container( // Squarish avatar container
                    width: _avatarContainerSize,
                    height: _avatarContainerSize,
                    decoration: BoxDecoration(
                      color: hasUnread ? Colors.white.withOpacity(0.2) : contentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(_avatarContainerRadius),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_avatarContainerRadius),
                      child: counselorPhotoUrl != null && counselorPhotoUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: counselorPhotoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Icon(Icons.person_outline_rounded, size: 28, color: contentColor.withOpacity(0.5)),
                        errorWidget: (context, url, error) => Icon(Icons.person_outline_rounded, size: 28, color: contentColor.withOpacity(0.5)),
                      )
                          : Center(
                        child: Text(
                          counselorName.isNotEmpty ? counselorName[0].toUpperCase() : "?",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: _primaryFontFamily,
                            color: hasUnread ? contentColor : colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          counselorName,
                          style: TextStyle(
                            fontFamily: _primaryFontFamily,
                            fontSize: 16.5, // Slightly larger name
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                            color: contentColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitleText,
                          style: TextStyle(
                            fontFamily: _primaryFontFamily,
                            fontSize: 13.5, // Slightly larger subtitle
                            color: hasUnread ? contentColor.withOpacity(0.95) : contentColor.withOpacity(0.7),
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (chatRoom.lastMessageTimestamp != null)
                        Text(
                          DateFormat('hh:mm a').format(chatRoom.lastMessageTimestamp!.toDate()),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: contentColor.withOpacity(0.6),
                            fontFamily: _primaryFontFamily,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: colorScheme.primary, // Use primary for unread badge
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: _primaryFontFamily,
                            ),
                          ),
                        )
                      else if (chatRoom.status == 'pending_user_request')
                        Icon(Icons.hourglass_empty_rounded, size: 18, color: contentColor.withOpacity(0.5))
                      else if (chatRoom.status == 'declined_by_counselor')
                          Icon(Icons.do_not_disturb_alt_rounded, size: 18, color: theme.colorScheme.error.withOpacity(0.7))
                        else
                          const SizedBox(height: 22), // Placeholder to maintain alignment
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

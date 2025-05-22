// lib/counselor/counselor_chat_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/theme_provider.dart';
import '../models/chat_room_model.dart';
import '../services/chat_service.dart';
import 'counselor_chat_screen.dart'; // Navigates to counselor's chat view
import 'counselor_profile_screen.dart'; // For counselor's profile
import '../widgets/bouncing_widget.dart'; // For tap animation

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _cardCornerRadius = 24.0; // Consistent with other modern cards
const double _conceptualOverlap = 20.0; // For title overlap effect
const double _avatarContainerSize = 52.0; // For squarish avatar container
const double _avatarContainerRadius = 14.0; // Radius for avatar container
// --- End Constants ---

class CounselorChatOverviewScreen extends StatefulWidget {
  const CounselorChatOverviewScreen({Key? key}) : super(key: key);

  @override
  State<CounselorChatOverviewScreen> createState() =>
      _CounselorChatOverviewScreenState();
}

class _CounselorChatOverviewScreenState
    extends State<CounselorChatOverviewScreen> {
  final ChatService _chatService = ChatService();
  User? _currentCounselor;

  @override
  void initState() {
    super.initState();
    _currentCounselor = FirebaseAuth.instance.currentUser;
    if (_currentCounselor == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Authentication error. Please re-login.")),
          );
          // Potentially navigate to login screen or handle appropriately
        }
      });
    }
  }

  // Helper for card shadows
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
          MaterialPageRoute(builder: (context) => const CounselorProfileScreen()),
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

  void _navigateToChat(BuildContext context, ChatRoomModel chatRoom) {
    if (_currentCounselor == null || !mounted) return;

    // For counselor, the other participant is always the student/user
    String studentId = '';
    if (chatRoom.participantIds.length == 2) {
      studentId = chatRoom.participantIds.firstWhere(
            (id) => id != _currentCounselor!.uid,
        orElse: () => '',
      );
    }

    if (studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not identify the student for this chat.")),
      );
      return;
    }

    String studentName = chatRoom.getOtherParticipantName(_currentCounselor!.uid);
    String? studentPhotoUrl = chatRoom.getOtherParticipantPhotoUrl(_currentCounselor!.uid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CounselorChatScreen( // Navigate to Counselor's chat screen
          studentUserId: studentId,
          studentName: studentName,
          chatRoomId: chatRoom.id,
          initialChatRoomStatus: chatRoom.status,
          studentPhotoUrl: studentPhotoUrl,
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

    if (_currentCounselor == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: Text("Not authenticated. Please log in again.", style: TextStyle(fontFamily: _primaryFontFamily))),
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
                    "CHATS", // Large Faded Text
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 72, // Larger for more impact
                      fontWeight: FontWeight.w900,
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.displayLarge?.color?.withOpacity(0.05),
                      height: 0.8,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -2),
                    child: Text(
                      "Conversations", // Prominent Title
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
            stream: _chatService.getCounselorChatRoomsStream(), // Fetches chats for the counselor
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                print("Error fetching counselor chats: ${snapshot.error}");
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      "Could not load conversations.\nPlease try again later.",
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
                          Icon(Icons.forum_outlined, size: 60, color: theme.hintColor.withOpacity(0.45)),
                          const SizedBox(height: 20),
                          Text(
                            'No Conversations Yet',
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontFamily: _primaryFontFamily,
                                color: theme.textTheme.titleMedium?.color?.withOpacity(0.75)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "When users initiate a chat or you have ongoing conversations, they will appear here.",
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

              final allChatRooms = snapshot.data!;
              // Separate pending requests from other chats
              final pendingRequests = allChatRooms.where((cr) => cr.status == 'pending_user_request').toList();
              final otherChats = allChatRooms.where((cr) => cr.status != 'pending_user_request').toList();

              // Sort other chats: active ones with unread messages first, then by last update
              otherChats.sort((a, b) {
                bool aHasUnread = a.getUnreadCountForUser(_currentCounselor!.uid) > 0 && a.status == 'active';
                bool bHasUnread = b.getUnreadCountForUser(_currentCounselor!.uid) > 0 && b.status == 'active';
                if (aHasUnread && !bHasUnread) return -1;
                if (!aHasUnread && bHasUnread) return 1;
                return (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt);
              });

              List<Widget> listItems = [];

              // Add "NEW REQUESTS" section if there are any
              if (pendingRequests.isNotEmpty) {
                listItems.add(
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 15.0, top: 5.0),
                    child: Text(
                      "NEW REQUESTS (${pendingRequests.length})",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: _primaryFontFamily,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary, // Use primary color for emphasis
                        letterSpacing: 0.7,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                );
                listItems.addAll(pendingRequests.map((chatRoom) =>
                    _buildChatListItem(context, chatRoom, theme, colorScheme, isNewRequest: true)));
              }

              // Add "YOUR CONVERSATIONS" section if there are other chats
              if (otherChats.isNotEmpty) {
                if (pendingRequests.isNotEmpty) { // Add a divider if both sections are present
                  listItems.add(const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 5.0),
                    child: Divider(thickness: 0.8),
                  ));
                }
                listItems.add(
                  Padding(
                    padding: EdgeInsets.only(left: 4.0, bottom: 15.0, top: pendingRequests.isEmpty ? 5.0 : 0.0),
                    child: Text(
                      "YOUR CONVERSATIONS",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: _primaryFontFamily,
                        fontWeight: FontWeight.w600, // Slightly less bold than new requests
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
                        letterSpacing: 0.6,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
                listItems.addAll(otherChats.map((chatRoom) =>
                    _buildChatListItem(context, chatRoom, theme, colorScheme)));
              }
              // Add bottom padding for FAB or navigation bar
              listItems.add(const SizedBox(height: 90));


              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(listItems),
                ),
              );
            },
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 30)),
        ],
      ),
    );
  }

  Widget _buildChatListItem(
      BuildContext context,
      ChatRoomModel chatRoom,
      ThemeData theme,
      ColorScheme colorScheme,
      {bool isNewRequest = false} // To style new requests differently
      ) {
    if (_currentCounselor == null) return const SizedBox.shrink();

    // For counselor, the "other" participant is the student/user
    final String studentName = chatRoom.getOtherParticipantName(_currentCounselor!.uid);
    final String? studentPhotoUrl = chatRoom.getOtherParticipantPhotoUrl(_currentCounselor!.uid);
    final int unreadCount = chatRoom.getUnreadCountForUser(_currentCounselor!.uid);
    final bool hasUnread = unreadCount > 0 && chatRoom.status == 'active';

    String subtitleText = chatRoom.lastMessageText ?? "No messages yet.";
    if (isNewRequest) {
      subtitleText = "$studentName wants to chat with you...";
    } else if (chatRoom.lastMessageSenderId == _currentCounselor!.uid && chatRoom.status == 'active') {
      subtitleText = "You: $subtitleText";
    } else if (chatRoom.status == 'declined_by_counselor'){
      subtitleText = "You declined this request.";
    }
    if (subtitleText.length > 35) subtitleText = "${subtitleText.substring(0, 32)}...";

    Color cardBackgroundColor = theme.cardColor;
    Color contentColor = theme.colorScheme.onSurface;
    List<BoxShadow> boxShadow = _getCardShadow(context);

    if (isNewRequest || hasUnread) {
      cardBackgroundColor = colorScheme.primaryContainer.withOpacity(isNewRequest ? 0.85 : 0.7);
      contentColor = colorScheme.onPrimaryContainer;
      boxShadow = _getCardShadow(context, shadowColorHint: colorScheme.primary);
    }

    return BouncingWidget(
      onPressed: () => _navigateToChat(context, chatRoom),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        height: 100,
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
                  Container(
                    width: _avatarContainerSize,
                    height: _avatarContainerSize,
                    decoration: BoxDecoration(
                      color: (isNewRequest || hasUnread) ? Colors.white.withOpacity(0.2) : contentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(_avatarContainerRadius),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_avatarContainerRadius),
                      child: studentPhotoUrl != null && studentPhotoUrl.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: studentPhotoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Icon(Icons.person_outline_rounded, size: 28, color: contentColor.withOpacity(0.5)),
                        errorWidget: (context, url, error) => Icon(Icons.person_outline_rounded, size: 28, color: contentColor.withOpacity(0.5)),
                      )
                          : Center(
                        child: Text(
                          studentName.isNotEmpty ? studentName[0].toUpperCase() : "?",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: _primaryFontFamily,
                            color: (isNewRequest || hasUnread) ? contentColor : colorScheme.primary,
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
                          studentName,
                          style: TextStyle(
                            fontFamily: _primaryFontFamily,
                            fontSize: 16.5,
                            fontWeight: (isNewRequest || hasUnread) ? FontWeight.bold : FontWeight.w600,
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
                            fontSize: 13.5,
                            color: (isNewRequest || hasUnread) ? contentColor.withOpacity(0.95) : contentColor.withOpacity(0.7),
                            fontWeight: (isNewRequest || hasUnread) ? FontWeight.w500 : FontWeight.normal,
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
                      if (chatRoom.lastMessageTimestamp != null && !isNewRequest)
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
                            color: colorScheme.primary,
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
                      else if (isNewRequest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer.withOpacity(0.8), // A distinct color for "NEW"
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "NEW",
                            style: TextStyle(
                                color: colorScheme.onTertiaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: _primaryFontFamily,
                                letterSpacing: 0.5
                            ),
                          ),
                        )
                      else if (chatRoom.status == 'declined_by_counselor')
                          Icon(Icons.do_not_disturb_alt_rounded, size: 18, color: theme.colorScheme.error.withOpacity(0.7))
                        else
                          const SizedBox(height: 22), // Placeholder
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

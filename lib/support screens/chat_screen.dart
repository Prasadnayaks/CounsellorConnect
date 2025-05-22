// lib/chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For counselor avatar

import '../theme/theme_provider.dart';
// import 'models/chat_message_model.dart'; // If you strongly type messages

const String _primaryFontFamily = 'Nunito';
const double _messageBubbleRadius = 16.0;
const double _inputAreaRadius = 24.0;

// --- Helper for Themed SnackBar ---
void _showComingSoonSnackBar(BuildContext context, String featureName) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$featureName feature is coming soon!',
        style: TextStyle(
            color: colorScheme.onInverseSurface, // Text color on SnackBar
            fontFamily: _primaryFontFamily),
      ),
      backgroundColor: colorScheme.inverseSurface, // SnackBar background
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      margin: const EdgeInsets.all(10.0),
      elevation: 4.0,
    ),
  );
}
// --- End SnackBar Helper ---

class ChatScreen extends StatefulWidget {
  final String counselorId;
  final String counselorName;
  final String? counselorPhotoUrl; // Optional: Pass counselor's photo URL

  const ChatScreen({
    Key? key,
    required this.counselorId,
    required this.counselorName,
    this.counselorPhotoUrl, // Add to constructor
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  String? _currentUserName;

  late String _chatRoomId;
  String _chatRoomStatus = 'loading';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  Stream<QuerySnapshot>? _messagesStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _chatRoomStatusSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Error: You must be logged in to chat.")),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }
    _chatRoomId = _generateChatRoomId(_currentUser!.uid, widget.counselorId);
    _fetchCurrentUserNameAndInitializeChat();
  }

  @override
  void dispose() {
    _chatRoomStatusSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserNameAndInitializeChat() async {
    if (_currentUser == null || !mounted) return;
    try {
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        _currentUserName = (userDoc.data() as Map<String, dynamic>?)?['name']
        as String? ??
            _currentUser?.displayName ??
            "You";
        _initializeChat();
      }
    } catch (e) {
      print("Error fetching current user name: $e");
      if (mounted) {
        _currentUserName = _currentUser?.displayName ?? "You";
        _initializeChat();
      }
    }
  }

  String _generateChatRoomId(String userId1, String userId2) {
    return userId1.hashCode <= userId2.hashCode
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';
  }

  Future<void> _initializeChat() async {
    if (!mounted || _currentUser == null) return;
    setState(() => _chatRoomStatus = 'loading');
    final chatRoomRef = _firestore.collection('chatRooms').doc(_chatRoomId);
    await _chatRoomStatusSubscription?.cancel();
    _chatRoomStatusSubscription = chatRoomRef.snapshots().listen(
          (docSnapshot) async {
        if (!mounted) return;
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          final newStatus = data['status'] as String? ?? 'error';
          bool needsUiUpdate = false;
          if (newStatus != _chatRoomStatus) {
            _chatRoomStatus = newStatus;
            needsUiUpdate = true;
          }
          if (_chatRoomStatus == 'active') {
            if (_messagesStream == null) {
              _messagesStream = chatRoomRef
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots();
              needsUiUpdate = true;
            }
            await _markChatRoomAsReadForUser();
          } else {
            if (_messagesStream != null) {
              _messagesStream = null;
              needsUiUpdate = true;
            }
          }
          if (needsUiUpdate && mounted) setState(() {});
        } else {
          try {
            if (_currentUserName == null || _currentUserName!.isEmpty) {
              DocumentSnapshot userDoc = await _firestore
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .get();
              if (mounted) {
                _currentUserName =
                    (userDoc.data() as Map<String, dynamic>?)?['name']
                    as String? ??
                        _currentUser?.displayName ??
                        "User";
              } else {
                return;
              }
            }
            await chatRoomRef.set({
              'participantIds': [_currentUser!.uid, widget.counselorId],
              'participantNames': {
                _currentUser!.uid: _currentUserName ?? 'User',
                widget.counselorId: widget.counselorName,
              },
              'participantPhotoUrls': { // Store counselor photo if available
                if (widget.counselorPhotoUrl != null && widget.counselorPhotoUrl!.isNotEmpty)
                  widget.counselorId: widget.counselorPhotoUrl,
                // You might want to store user's photo URL too if available
                // _currentUser!.uid: _currentUser?.photoURL,
              },
              'status': 'pending_user_request',
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'lastMessageText':
              '${_currentUserName ?? "User"} would like to chat.',
              'lastMessageSenderId': _currentUser!.uid,
              'lastMessageTimestamp': FieldValue.serverTimestamp(),
              'unreadCounts': {
                widget.counselorId: 1,
                _currentUser!.uid: 0,
              },
            });
          } catch (e) {
            print("Error creating chat request in User's ChatScreen: $e");
            if (mounted) {
              setState(() => _chatRoomStatus = 'error');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                    Text("Could not send chat request: ${e.toString()}")),
              );
            }
          }
        }
      },
      onError: (error) {
        print(
            "Error listening to chat room document in User's ChatScreen: $error");
        if (mounted) setState(() => _chatRoomStatus = 'error');
      },
    );
  }

  Future<void> _markChatRoomAsReadForUser() async {
    if (_currentUser == null || _chatRoomId.isEmpty || !mounted) return;
    final chatRoomRef = _firestore.collection('chatRooms').doc(_chatRoomId);
    try {
      await chatRoomRef.update({
        'unreadCounts.${_currentUser!.uid}': 0,
      });
    } catch (e) {
      print(
          "[ChatScreen User] Error marking chat room $_chatRoomId as read: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _currentUser == null ||
        _isSending) {
      return;
    }
    if (_chatRoomStatus != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Chat not active. Cannot send message.")),
      );
      return;
    }
    setState(() => _isSending = true);
    String messageText = _messageController.text.trim();
    _messageController.clear();
    try {
      final chatRoomRef = _firestore.collection('chatRooms').doc(_chatRoomId);
      await chatRoomRef.collection('messages').add({
        'senderId': _currentUser!.uid,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'receiverId': widget.counselorId,
        'messageType': 'text',
      });
      await chatRoomRef.update({
        'lastMessageText': messageText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': _currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.counselorId}': FieldValue.increment(1),
      });
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send message: ${e.toString()}")),
        );
        _messageController.text = messageText;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    // Use scaffold background for chat area, AppBar will have gradient
    final Color chatAreaBackgroundColor = currentTheme.scaffoldBackgroundColor;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Keep transparent for gradient
      statusBarIconBrightness:
      ThemeData.estimateBrightnessForColor(themeProvider
          .currentAccentGradient.first) ==
          Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: chatAreaBackgroundColor, // Match chat area
      systemNavigationBarIconBrightness:
      currentTheme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));

    return Scaffold(
      // AppBar is now a standard AppBar for better structure
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: themeProvider.currentAccentGradient,
                begin: Alignment.topLeft, // Or Alignment.centerLeft
                end: Alignment.bottomRight // Or Alignment.centerRight
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: ThemeData.estimateBrightnessForColor(
                  themeProvider.currentAccentGradient.first) ==
                  Brightness.dark
                  ? Colors.white
                  : Colors.black87, // Dynamic icon color
              size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: "Back",
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.counselorPhotoUrl != null &&
                widget.counselorPhotoUrl!.isNotEmpty)
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.3),
                backgroundImage:
                CachedNetworkImageProvider(widget.counselorPhotoUrl!),
              )
            else
              CircleAvatar( // Fallback with initials or generic icon
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  widget.counselorName.isNotEmpty ? widget.counselorName[0].toUpperCase() : "?",
                  style: TextStyle(
                      color: ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.counselorName,
                style: TextStyle(
                  fontFamily: _primaryFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeData.estimateBrightnessForColor(
                      themeProvider.currentAccentGradient.first) ==
                      Brightness.dark
                      ? Colors.white
                      : Colors.black87, // Dynamic text color
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call_outlined,
                color: ThemeData.estimateBrightnessForColor(
                    themeProvider.currentAccentGradient.first) ==
                    Brightness.dark
                    ? Colors.white70
                    : Colors.black.withOpacity(0.6), // Dynamic icon color
                size: 24),
            onPressed: () => _showComingSoonSnackBar(context, "Audio Call"),
            tooltip: "Audio Call",
          ),
          IconButton(
            icon: Icon(Icons.videocam_outlined,
                color: ThemeData.estimateBrightnessForColor(
                    themeProvider.currentAccentGradient.first) ==
                    Brightness.dark
                    ? Colors.white70
                    : Colors.black.withOpacity(0.6), // Dynamic icon color
                size: 26),
            onPressed: () => _showComingSoonSnackBar(context, "Video Call"),
            tooltip: "Video Call",
          ),
          const SizedBox(width: 8),
        ],
        elevation: 1.0, // Subtle elevation for AppBar
        backgroundColor: Colors.transparent, // AppBar itself is transparent
      ),
      body: Container(
        // Chat body area with its own background
        color: chatAreaBackgroundColor,
        child: Column(
          children: [
            Expanded(
              child: _buildChatBody(currentTheme, colorScheme),
            ),
            // Message input is part of the chat body's column
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(ThemeData currentTheme, ColorScheme colorScheme) {
    if (_chatRoomStatus == 'loading' && _messagesStream == null) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }
    // ... (rest of the _buildChatBody method remains mostly the same as your corrected version)
    // It will handle 'error', 'pending_user_request', 'declined_by_counselor' states
    // and then the active chat view with messages and input.

    if (_chatRoomStatus == 'error') { /* ... error UI ... */
      return Center(child: Padding( padding: const EdgeInsets.all(20.0),
        child: Text( "Error loading chat. Please try again later.", textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, color: currentTheme.hintColor),),),);
    }
    if (_chatRoomStatus == 'pending_user_request') { /* ... pending UI ... */
      return Center( child: Padding( padding: const EdgeInsets.all(20.0),
        child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.hourglass_top_rounded, size: 48, color: colorScheme.primary.withOpacity(0.7)), const SizedBox(height: 16),
          Text( "Chat request sent to ${widget.counselorName}.", textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, color: currentTheme.textTheme.bodyMedium?.color),),
          const SizedBox(height: 8), Text( "You'll be able to chat once they approve.", textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 14, color: currentTheme.hintColor),),
        ],),),);
    }
    if (_chatRoomStatus == 'declined_by_counselor') { /* ... declined UI ... */
      return Center( child: Padding( padding: const EdgeInsets.all(20.0),
        child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: colorScheme.error.withOpacity(0.7)), const SizedBox(height: 16),
          Text( "Your chat request was declined by ${widget.counselorName}.", textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, color: currentTheme.textTheme.bodyMedium?.color),),
        ],),),);
    }


    // Active chat UI
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: colorScheme.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error loading messages.", style: TextStyle(fontFamily: _primaryFontFamily, color:currentTheme.hintColor)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                if (_chatRoomStatus == 'active') {
                  return Center( child: Padding( padding: const EdgeInsets.all(20.0),
                    child: Text( "Chat approved! Send a message to start the conversation with ${widget.counselorName}.", textAlign: TextAlign.center, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 15, color: currentTheme.hintColor),),
                  ),);
                } else {
                  return Center(child: Text("No messages yet.", style: TextStyle(fontFamily: _primaryFontFamily, color: currentTheme.hintColor)));
                }
              }
              final messages = snapshot.data!.docs;
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final messageData = messages[index].data() as Map<String, dynamic>;
                  final bool isMe = messageData['senderId'] == _currentUser!.uid;
                  return _buildMessageBubble(messageData, isMe, currentTheme, colorScheme);
                },
              );
            },
          ),
        ),
        if (_chatRoomStatus == 'active') _buildMessageInput(currentTheme, colorScheme),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData, bool isMe,
      ThemeData currentTheme, ColorScheme colorScheme) {
    final String text = messageData['text'] as String? ?? '[empty message]';
    final Timestamp? timestamp = messageData['timestamp'] as Timestamp?;
    final String timeString =
    timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : '';

    // Define bubble colors based on theme and sender
    final Color sentBubbleColor = colorScheme.primary;
    final Color receivedBubbleColor = currentTheme.brightness == Brightness.light
        ? Colors.grey.shade200 // Lighter grey for received in light mode
        : currentTheme.cardColor; // Default card color for received in dark mode

    final Color sentTextColor = colorScheme.onPrimary;
    final Color receivedTextColor = currentTheme.textTheme.bodyLarge!.color!;


    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
            color: isMe ? sentBubbleColor : receivedBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_messageBubbleRadius),
              topRight: Radius.circular(_messageBubbleRadius),
              bottomLeft: isMe
                  ? Radius.circular(_messageBubbleRadius)
                  : const Radius.circular(6), // Tail for received
              bottomRight: isMe
                  ? const Radius.circular(6) // Tail for sent
                  : Radius.circular(_messageBubbleRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: currentTheme.shadowColor.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]),
        child: Column(
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: _primaryFontFamily,
                fontSize: 15.5,
                color: isMe ? sentTextColor : receivedTextColor,
                height: 1.35,
              ),
            ),
            if (timeString.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                timeString,
                style: TextStyle(
                  fontFamily: _primaryFontFamily,
                  fontSize: 10.5,
                  color: (isMe ? sentTextColor : receivedTextColor)
                      .withOpacity(0.7),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(
      ThemeData currentTheme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 10.0, // Adjusted padding
        right: 8.0,
        top: 8.0,
        bottom: MediaQuery.of(context).padding.bottom + 8.0, // Safe area padding
      ),
      decoration: BoxDecoration(
        color: currentTheme.cardColor, // Input area background
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: currentTheme.shadowColor.withOpacity(0.05),
          ),
        ],
        // Optional: add a top border
        // border: Border(top: BorderSide(color: currentTheme.dividerColor, width: 0.5))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.attach_file_rounded,
                color: currentTheme.iconTheme.color?.withOpacity(0.7),
                size: 24),
            onPressed: () => _showComingSoonSnackBar(context, "Attachments"),
            tooltip: "Attach file",
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              decoration: BoxDecoration(
                color: currentTheme.brightness == Brightness.light
                    ? Colors.grey.shade100
                    : currentTheme.scaffoldBackgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(_inputAreaRadius),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontFamily: _primaryFontFamily,
                    fontSize: 16,
                    color: currentTheme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(
                      color: currentTheme.hintColor.withOpacity(0.8),
                      fontFamily: _primaryFontFamily,
                      fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 18.0), // Adjusted padding
                ),
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => _isSending ? null : _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.send_rounded,
                color: colorScheme.primary, size: 28),
            onPressed:
            _isSending || _chatRoomStatus != 'active' ? null : _sendMessage,
            tooltip: "Send",
          ),
        ],
      ),
    );
  }
}
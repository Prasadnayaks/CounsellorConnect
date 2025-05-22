// lib/counselor/counselor_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // For student avatar

import '../theme/theme_provider.dart';
import '../services/chat_service.dart';
import '../models/chat_message_model.dart';
import '../models/chat_room_model.dart'; // For fetching student photo from chatRoom

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _messageBubbleRadius = 16.0;
const double _inputAreaRadius = 24.0;
// --- End Constants ---

// --- Helper for Themed SnackBar (can be moved to a shared utils file) ---
void _showComingSoonSnackBar(BuildContext context, String featureName) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$featureName feature is coming soon!',
        style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontFamily: _primaryFontFamily),
      ),
      backgroundColor: colorScheme.inverseSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      margin: const EdgeInsets.all(10.0),
      elevation: 4.0,
    ),
  );
}
// --- End SnackBar Helper ---

class CounselorChatScreen extends StatefulWidget {
  final String studentUserId;
  final String studentName;
  final String chatRoomId;
  final String initialChatRoomStatus;
  final String? studentPhotoUrl; // Optional: Pass student's photo URL

  const CounselorChatScreen({
    Key? key,
    required this.studentUserId,
    required this.studentName,
    required this.chatRoomId,
    required this.initialChatRoomStatus,
    this.studentPhotoUrl, // Add to constructor
  }) : super(key: key);

  @override
  State<CounselorChatScreen> createState() => _CounselorChatScreenState();
}

class _CounselorChatScreenState extends State<CounselorChatScreen> {
  final ChatService _chatService = ChatService();
  User? _currentCounselor;
  String? _counselorName;
  String? _fetchedStudentPhotoUrl; // To store photo URL fetched from chatRoom if not passed

  late String _chatRoomStatusCurrent;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _chatRoomStatusSubscription;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _messagesStream;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _currentCounselor = _chatService.currentUser;
    _chatRoomStatusCurrent = widget.initialChatRoomStatus;
    _fetchedStudentPhotoUrl = widget.studentPhotoUrl; // Initialize with passed URL

    if (_currentCounselor == null) {
      _handleAuthError("Counselor not authenticated.");
      return;
    }
    _fetchCounselorNameAndSetupListeners();
  }

  void _handleAuthError(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _fetchCounselorNameAndSetupListeners() async {
    if (_currentCounselor == null || !mounted) return;
    try {
      DocumentSnapshot counselorUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentCounselor!.uid)
          .get();
      if (mounted) {
        _counselorName =
            (counselorUserDoc.data() as Map<String, dynamic>?)?['name']
            as String? ??
                _currentCounselor?.displayName ??
                "Counselor";
        _setupListeners(); // Call this after counselor name is fetched
      }
    } catch (e) {
      print("Error fetching counselor name: $e");
      if (mounted) {
        _counselorName = _currentCounselor?.displayName ?? "Counselor";
        _setupListeners(); // Proceed even if name fetch fails
      }
    }
  }

  void _setupListeners() {
    if (!mounted || widget.chatRoomId.isEmpty || _currentCounselor == null) return;

    _chatRoomStatusSubscription?.cancel();
    _chatRoomStatusSubscription =
        _chatService.getChatRoomDocumentStream(widget.chatRoomId).listen(
              (snapshot) {
            if (mounted && snapshot.exists) {
              final data = snapshot.data()!;
              final newStatus = data['status'] as String? ?? 'error';
              bool needsSetState = false;

              // Attempt to get student photo URL from chatRoom if not already available
              if (_fetchedStudentPhotoUrl == null || _fetchedStudentPhotoUrl!.isEmpty) {
                final ChatRoomModel chatRoom = ChatRoomModel.fromFirestore(snapshot);
                final fetchedUrl = chatRoom.getOtherParticipantPhotoUrl(_currentCounselor!.uid);
                if (fetchedUrl != null && fetchedUrl.isNotEmpty && fetchedUrl != _fetchedStudentPhotoUrl) {
                  _fetchedStudentPhotoUrl = fetchedUrl;
                  needsSetState = true;
                }
              }


              if (newStatus != _chatRoomStatusCurrent) {
                _chatRoomStatusCurrent = newStatus;
                needsSetState = true;
              }

              if (_chatRoomStatusCurrent == 'active') {
                if (_messagesStream == null) {
                  _messagesStream =
                      _chatService.getMessagesStream(widget.chatRoomId);
                  needsSetState = true;
                }
                _chatService.markChatRoomAsRead(
                    widget.chatRoomId, _currentCounselor!.uid);
              } else {
                if (_messagesStream != null) {
                  _messagesStream = null;
                  needsSetState = true;
                }
              }
              if (needsSetState && mounted) setState(() {});
            } else if (mounted && !snapshot.exists) {
              if (mounted) setState(() => _chatRoomStatusCurrent = 'not_found_or_error');
            }
          },
          onError: (error) {
            print("Error listening to chat room status: $error");
            if (mounted) setState(() => _chatRoomStatusCurrent = 'error');
          },
        );

    if (_chatRoomStatusCurrent == 'active' && _messagesStream == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _messagesStream =
                _chatService.getMessagesStream(widget.chatRoomId);
          });
          _chatService.markChatRoomAsRead(
              widget.chatRoomId, _currentCounselor!.uid);
        }
      });
    }
  }

  @override
  void dispose() {
    _chatRoomStatusSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleApproveRequest() async {
    if (_isUpdatingStatus || _counselorName == null || !mounted) return;
    setState(() => _isUpdatingStatus = true);
    try {
      await _chatService.approveChatRequest(
          widget.chatRoomId, widget.studentUserId, _counselorName!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Chat request approved!"),
            duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error approving request: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _handleDeclineRequest() async {
    if (_isUpdatingStatus || !mounted) return;
    setState(() => _isUpdatingStatus = true);
    try {
      await _chatService.declineChatRequest(
          widget.chatRoomId, widget.studentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Chat request declined."),
            duration: Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error declining request: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _currentCounselor == null ||
        _isSending || !mounted) return;
    if (_chatRoomStatusCurrent != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Cannot send message. Chat is not active.")));
      return;
    }
    setState(() => _isSending = true);
    String messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      await _chatService.sendMessage(
        chatRoomId: widget.chatRoomId,
        text: messageText,
        currentUserId: _currentCounselor!.uid,
        partnerId: widget.studentUserId,
      );
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to send message: ${e.toString()}")));
        _messageController.text = messageText;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final Color chatAreaBackgroundColor = currentTheme.scaffoldBackgroundColor;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
      ThemeData.estimateBrightnessForColor(themeProvider
          .currentAccentGradient.first) ==
          Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: chatAreaBackgroundColor,
      systemNavigationBarIconBrightness:
      currentTheme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));

    // Determine icon and text color for AppBar based on gradient brightness
    final Color appBarContentColor = ThemeData.estimateBrightnessForColor(
        themeProvider.currentAccentGradient.first) == Brightness.dark
        ? Colors.white
        : Colors.black87;


    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: themeProvider.currentAccentGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: appBarContentColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: "Back",
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_fetchedStudentPhotoUrl != null && _fetchedStudentPhotoUrl!.isNotEmpty)
              CircleAvatar(
                radius: 18,
                backgroundColor: appBarContentColor.withOpacity(0.3),
                backgroundImage:
                CachedNetworkImageProvider(_fetchedStudentPhotoUrl!),
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: appBarContentColor.withOpacity(0.3),
                child: Text(
                  widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : "?",
                  style: TextStyle(
                      color: appBarContentColor.withOpacity(0.9), // Ensure good contrast for initial
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.studentName,
                style: TextStyle(
                  fontFamily: _primaryFontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: appBarContentColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call_outlined, color: appBarContentColor.withOpacity(0.85), size: 24),
            onPressed: () => _showComingSoonSnackBar(context, "Audio Call"),
            tooltip: "Audio Call",
          ),
          IconButton(
            icon: Icon(Icons.videocam_outlined, color: appBarContentColor.withOpacity(0.85), size: 26),
            onPressed: () => _showComingSoonSnackBar(context, "Video Call"),
            tooltip: "Video Call",
          ),
          const SizedBox(width: 8),
        ],
        elevation: 1.0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        color: chatAreaBackgroundColor,
        child: Column(
          children: [
            Expanded(
              child: _buildChatBody(currentTheme, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBody(ThemeData currentTheme, ColorScheme colorScheme) {
    if (_chatRoomStatusCurrent == 'loading') {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }
    if (_chatRoomStatusCurrent == 'error' || _chatRoomStatusCurrent == 'not_found_or_error') {
      return Center(child: Text("Error loading chat. Please try again.", style: TextStyle(fontFamily: _primaryFontFamily, color: currentTheme.hintColor)));
    }

    if (_chatRoomStatusCurrent == 'pending_user_request') {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_read_outlined, size: 54, color: colorScheme.primary.withOpacity(0.8)),
            const SizedBox(height: 20),
            Text(
              "${widget.studentName} has requested to chat.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 18, fontWeight: FontWeight.w600, color: currentTheme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 10),
            Text(
              "Review their profile or previous interactions if needed before responding.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 14, color: currentTheme.hintColor, height: 1.4),
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: _isUpdatingStatus // Simpler loader check
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Decline"),
                  onPressed: _isUpdatingStatus ? null : _handleDeclineRequest,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error.withOpacity(0.7)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: _isUpdatingStatus
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Approve Chat"),
                  onPressed: _isUpdatingStatus ? null : _handleApproveRequest,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      textStyle: const TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Active chat UI
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (_messagesStream == null && _chatRoomStatusCurrent == 'active') {
                return Center(child: CircularProgressIndicator(color: colorScheme.primary));
              }
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) { // Improved loading check
                return Center(child: CircularProgressIndicator(color: colorScheme.primary));
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error loading messages.", style: TextStyle(fontFamily: _primaryFontFamily, color: currentTheme.hintColor)));
              }
              if ((!snapshot.hasData || snapshot.data!.docs.isEmpty) && _chatRoomStatusCurrent == 'active') {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Chat approved! You can now send a message to ${widget.studentName}.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 15, color: currentTheme.hintColor),
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                String message = "This chat has been ${_chatRoomStatusCurrent.replaceAll('_', ' ')}.";
                if (_chatRoomStatusCurrent == 'declined_by_counselor') message = "You have declined this chat request.";
                if (_chatRoomStatusCurrent.startsWith('closed')) message = "This chat has been closed.";
                return Center(child: Text(message, style: TextStyle(fontFamily: _primaryFontFamily, color: currentTheme.hintColor)));
              }

              final messages = snapshot.data!.docs;
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final messageDoc = messages[index];
                  final ChatMessageModel message = ChatMessageModel.fromFirestore(messageDoc);
                  final bool isMe = message.senderId == _currentCounselor!.uid;
                  return _buildMessageBubble(message, isMe, currentTheme, colorScheme);
                },
              );
            },
          ),
        ),
        if (_chatRoomStatusCurrent == 'active') _buildMessageInput(currentTheme, colorScheme),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe, ThemeData currentTheme, ColorScheme colorScheme) {
    final String timeString = DateFormat('hh:mm a').format(message.timestamp.toDate());

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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
            color: isMe ? sentBubbleColor : receivedBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_messageBubbleRadius),
              topRight: Radius.circular(_messageBubbleRadius),
              bottomLeft: isMe ? Radius.circular(_messageBubbleRadius) : const Radius.circular(6),
              bottomRight: isMe ? const Radius.circular(6) : Radius.circular(_messageBubbleRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: currentTheme.shadowColor.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
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
                  color: (isMe ? sentTextColor : receivedTextColor).withOpacity(0.7),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeData currentTheme, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 10.0,
        right: 8.0,
        top: 8.0,
        bottom: MediaQuery.of(context).padding.bottom + 8.0,
      ),
      decoration: BoxDecoration(
        color: currentTheme.cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: currentTheme.shadowColor.withOpacity(0.05),
          ),
        ],
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
                style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, color: currentTheme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: currentTheme.hintColor.withOpacity(0.8), fontFamily: _primaryFontFamily, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 18.0),
                ),
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => _isSending ? null : _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.send_rounded, color: colorScheme.primary, size: 28),
            onPressed: _isSending || _chatRoomStatusCurrent != 'active' ? null : _sendMessage,
            tooltip: "Send",
          ),
        ],
      ),
    );
  }
}
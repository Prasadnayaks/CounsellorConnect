// lib/self_care/screens/general_chatbot_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For formatting timestamps

// Existing project imports
import '../../theme/theme_provider.dart';
import '../../support screens/models/chatbot_info.dart'; // Contains SelfCareItem
import '../../widgets/bouncing_widget.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _messageBubbleRadiusLarge = 18.0;
const double _messageBubbleRadiusSmall = 6.0;
const double _inputAreaRadius = 28.0;
const double _inputFieldVerticalPadding = 14.0;

// --- ChatMessage Model ---
enum MessageSender { user, bot, error }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });
}
// --- End ChatMessage Model ---

// --- EnhancedDelayedAnimation (Include if not already in a shared utils file) ---
// If this widget is already defined in your project (e.g., in home_screen.dart or a utils file),
// you can remove this definition and import it instead.
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
    this.offsetBegin = const Offset(0, 0.05), // Default: slight slide from bottom
    this.offsetEnd = Offset.zero,
    this.duration = const Duration(milliseconds: 400), // Default duration
    this.curve = Curves.easeOutCubic,
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


class GeneralChatbotScreen extends StatefulWidget {
  final SelfCareItem item;

  const GeneralChatbotScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<GeneralChatbotScreen> createState() => _GeneralChatbotScreenState();
}

class _GeneralChatbotScreenState extends State<GeneralChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isBotTyping = false;
  bool _isSendingMessage = false;
  final Uuid _uuid = const Uuid();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  @override
  void initState() {
    super.initState();
    _addInitialBotMessage(
        "Hello! I'm your ${widget.item.name}. How can I assist you today?");
    _messageController.addListener(() {
      if (mounted) {
        setState(() {}); // To update send button state
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addMessageToUI(String text, MessageSender sender, {String? id}) {
    if (!mounted) return;
    final message = ChatMessage(
      id: id ?? _uuid.v4(),
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, message);
    });
    _scrollToBottom(delayMilliseconds: 50);
  }


  void _addInitialBotMessage(String text) {
    _addMessageToUI(text, MessageSender.bot);
  }

  void _addErrorMessage(String text) {
    _addMessageToUI(text, MessageSender.error);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _addErrorMessage("Authentication error. Please log in and try again.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSendingMessage = true;
    });

    _addMessageToUI(text, MessageSender.user);
    _messageController.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && _isSendingMessage) {
      setState(() {
        _isBotTyping = true;
      });
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable('generalChatbot');
      final HttpsCallableResult result = await callable.call(<String, dynamic>{
        'prompt': text,
      });

      final String? botResponse = result.data['response'] as String?;
      if (!mounted) return;

      if (botResponse != null && botResponse.isNotEmpty) {
        _addMessageToUI(botResponse, MessageSender.bot);
      } else {
        _addErrorMessage("I'm having a bit of trouble understanding. Could you try rephrasing?");
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      print("Cloud Function Error: Code: ${e.code}, Message: ${e.message}");
      String userFriendlyError = "Sorry, I couldn't process that. Please try again.";
      if (e.code == 'unauthenticated') {
        userFriendlyError = "It seems you're not authenticated. Please log in.";
      } else if (e.message?.toLowerCase().contains("deadline exceeded") ?? false) {
        userFriendlyError = "The request timed out. Please try again.";
      } else if (e.message != null) {
        userFriendlyError = "An error occurred: ${e.message}";
      }
      _addErrorMessage(userFriendlyError);
    } catch (e) {
      if (!mounted) return;
      print("Error sending message: $e");
      _addErrorMessage("An unexpected error occurred. Please check your connection.");
    } finally {
      if (mounted) {
        setState(() {
          _isBotTyping = false;
          _isSendingMessage = false;
        });
      }
    }
  }

  void _scrollToBottom({int delayMilliseconds = 100}) {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: delayMilliseconds), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
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

    final Brightness appBarBrightness = ThemeData.estimateBrightnessForColor(
        widget.item.gradientColors.isNotEmpty
            ? widget.item.gradientColors.first
            : themeProvider.currentAccentGradient.first);
    final Color appBarContentColor =
    appBarBrightness == Brightness.dark ? Colors.white : Colors.black87;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: appBarBrightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: currentTheme.cardColor,
      systemNavigationBarIconBrightness:
      currentTheme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: chatAreaBackgroundColor,
      appBar: AppBar(
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
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: appBarContentColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: "Back",
        ),
        title: Row(
          children: [
            Icon(widget.item.icon, color: appBarContentColor.withOpacity(0.9), size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.item.name,
                style: TextStyle(
                  fontFamily: _primaryFontFamily,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: appBarContentColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(0.1),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 15.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return EnhancedDelayedAnimation(
                    delay: 50 + (index * 30),
                    offsetBegin: const Offset(0, 0.05),
                    duration: const Duration(milliseconds: 400),
                    child: _MessageBubble(message: message),
                  );
                },
              ),
            ),
          ),
          if (_isBotTyping)
            Padding(
              padding: const EdgeInsets.only(left: 18.0, bottom: 6.0, top: 4.0, right: 18.0),
              child: Row(
                children: [
                  _TypingIndicator(botName: widget.item.name),
                ],
              ),
            ),
          _MessageInputArea(
            controller: _messageController,
            onSend: _sendMessage,
            isSending: _isSendingMessage,
            botName: widget.item.name, // Pass botName here
          ),
        ],
      ),
    );
  }
}

// --- Message Bubble Widget ---
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final bool isUserMessage = message.sender == MessageSender.user;
    final bool isErrorMessage = message.sender == MessageSender.error;

    final Color bubbleColor = isUserMessage
        ? colorScheme.primary
        : (isErrorMessage
        ? colorScheme.errorContainer.withOpacity(0.7)
        : (currentTheme.brightness == Brightness.light
        ? Colors.white
        : currentTheme.colorScheme.surfaceContainerHighest));

    final Color textColor = isUserMessage
        ? colorScheme.onPrimary
        : (isErrorMessage
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface);

    final Alignment alignment =
    isUserMessage ? Alignment.centerRight : Alignment.centerLeft;

    final Radius largeRadius = Radius.circular(_messageBubbleRadiusLarge);
    final Radius smallRadius = Radius.circular(_messageBubbleRadiusSmall);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: largeRadius,
              topRight: largeRadius,
              bottomLeft: isUserMessage ? largeRadius : smallRadius,
              bottomRight: isUserMessage ? smallRadius : largeRadius,
            ),
            boxShadow: isUserMessage ? [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : [
              BoxShadow(
                color: currentTheme.shadowColor.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ]
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isErrorMessage)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.error_outline_rounded, color: textColor.withOpacity(0.8), size: 16),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontFamily: _primaryFontFamily,
                fontSize: 15.0,
                color: textColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(
                  fontFamily: _primaryFontFamily,
                  fontSize: 9.5,
                  color: textColor.withOpacity(0.65),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Message Input Area Widget ---
class _MessageInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final String botName; // Added botName parameter

  const _MessageInputArea({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.isSending,
    required this.botName, // Added to constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final bool canSend = controller.text.trim().isNotEmpty && !isSending;

    return Container(
      padding: EdgeInsets.only(
        left: 12.0,
        right: 8.0,
        top: 8.0,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 2.0
            : 10.0,
      ),
      decoration: BoxDecoration(
        color: currentTheme.cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 5,
            color: currentTheme.shadowColor.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              decoration: BoxDecoration(
                  color: currentTheme.brightness == Brightness.light
                      ? currentTheme.scaffoldBackgroundColor
                      : currentTheme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(_inputAreaRadius),
                  border: Border.all(color: currentTheme.dividerColor.withOpacity(0.5), width: 0.8)
              ),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                    fontFamily: _primaryFontFamily,
                    fontSize: 16,
                    color: currentTheme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Message $botName...", // Used botName here
                  hintStyle: TextStyle(
                      color: currentTheme.hintColor.withOpacity(0.7),
                      fontFamily: _primaryFontFamily,
                      fontSize: 15.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: _inputFieldVerticalPadding, horizontal: 12.0),
                ),
                minLines: 1,
                maxLines: 5,
                onSubmitted: canSend ? (_) => onSend() : null,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 6),
          BouncingWidget(
            onPressed: canSend ? onSend : null,
            child: CircleAvatar(
              radius: 23,
              backgroundColor: canSend
                  ? colorScheme.primary
                  : currentTheme.disabledColor.withOpacity(0.5),
              child: isSending
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Colors.white,
                ),
              )
                  : Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Typing Indicator Widget ---
class _TypingIndicator extends StatefulWidget {
  final String botName;
  const _TypingIndicator({Key? key, required this.botName}) : super(key: key);

  @override
  __TypingIndicatorState createState() => __TypingIndicatorState();
}

class __TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  final List<Animation<double>> _dotAnimations = [];

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    for (int i = 0; i < 3; i++) {
      _dotAnimations.add(
        Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: _dotController,
            curve: Interval(0.1 * i, 0.3 + 0.1 * i, curve: Curves.easeInOut),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "${widget.botName} is typing",
          style: TextStyle(
              color: currentTheme.hintColor,
              fontFamily: _primaryFontFamily,
              fontSize: 12.5),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _dotController,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Opacity(
                  opacity: _dotAnimations[index].value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: currentTheme.hintColor.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
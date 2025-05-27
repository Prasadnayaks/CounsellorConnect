// lib/self_care/screens/general_chatbot_screen.dart
import 'dart:async';
import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';

// Existing project imports
import '../../theme/theme_provider.dart';
import '../../support screens/models/chatbot_info.dart'; // Contains SelfCareItem
import '../../widgets/bouncing_widget.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _messageBubbleRadiusLarge = 18.0; // For main corners
const double _messageBubbleRadiusSmall = 5.0;  // For the "tail" corner
const double _inputAreaRadius = 28.0;
const double _inputFieldVerticalPadding = 14.0;
const double _timestampFontSize = 10.5;
const double _messageVerticalMargin = 8.0; // Increased spacing

// --- ChatMessage Model (Keep as is) ---
enum MessageSender { user, bot, error, info }

class ChatMessage {
  final String id;
  String text;
  final MessageSender sender;
  final DateTime timestamp;
  bool isStreaming;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isStreaming = false,
  });
}
// --- End ChatMessage Model ---

// --- EnhancedDelayedAnimation (Keep as is from your project) ---
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
    this.offsetBegin = const Offset(0, 0.05),
    this.offsetEnd = Offset.zero,
    this.duration = const Duration(milliseconds: 400),
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
  bool _isBotTypingIndicatorVisible = false;
  bool _isSendingMessage = false;
  final Uuid _uuid = const Uuid();

  WebSocketChannel? _channel;
  String? _currentStreamingBotMessageId;
  Timer? _typingIndicatorTimer;

  final String _webSocketUrl = "ws://192.168.1.108:8000/ws/v1/careconnect_chat";

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _typingIndicatorTimer?.cancel();
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_webSocketUrl));
      _addMessageToUI("Connecting to ${widget.item.name}...", MessageSender.info, isTemporary: true);

      _channel!.stream.listen(
            (message) => _handleServerMessage(message),
        onDone: () {
          if (mounted) {
            _hideTypingIndicator();
            _addMessageToUI("Chat ended. You've been disconnected.", MessageSender.info);
          }
          print("WebSocket onDone");
        },
        onError: (error) {
          if (mounted) {
            _hideTypingIndicator();
            _addErrorMessage("Connection error: ${error.toString()}. Please try again.");
          }
          print("WebSocket onError: $error");
        },
        cancelOnError: true,
      );

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _messages.isNotEmpty && _messages.first.sender == MessageSender.info && _messages.first.text.startsWith("Connecting")) {
          setState(() => _messages.removeAt(0));
        }
        _addInitialBotMessage("Hello! I'm your ${widget.item.name}. How can I assist you today?");
      });

    } catch (e) {
      if (mounted) {
        _hideTypingIndicator();
        _addErrorMessage("Failed to connect: $e. Ensure server is running.");
      }
      print("WebSocket connection error: $e");
    }
  }

  void _showTypingIndicator() {
    if (mounted && !_isBotTypingIndicatorVisible) {
      setState(() => _isBotTypingIndicatorVisible = true);
    }
    _typingIndicatorTimer?.cancel();
  }

  void _hideTypingIndicator() {
    _typingIndicatorTimer?.cancel();
    if (mounted && _isBotTypingIndicatorVisible) {
      setState(() => _isBotTypingIndicatorVisible = false);
    }
  }

  void _handleServerMessage(String message) {
    if (!mounted) return;
    _hideTypingIndicator();

    try {
      final decodedMessage = jsonDecode(message);
      final String type = decodedMessage['type'];
      final String data = decodedMessage['data'];

      if (type == "content") {
        if (_currentStreamingBotMessageId == null || _messages.isEmpty || _messages.first.id != _currentStreamingBotMessageId) {
          _currentStreamingBotMessageId = _uuid.v4();
          _addMessageToUI(data, MessageSender.bot, id: _currentStreamingBotMessageId, isStreaming: true);
        } else {
          setState(() {
            final existingMessageIndex = _messages.indexWhere((msg) => msg.id == _currentStreamingBotMessageId);
            if (existingMessageIndex != -1) {
              _messages[existingMessageIndex].text += data;
              _messages[existingMessageIndex].isStreaming = true;
            } else {
              _currentStreamingBotMessageId = _uuid.v4();
              _addMessageToUI(data, MessageSender.bot, id: _currentStreamingBotMessageId, isStreaming: true);
            }
          });
        }
      } else {
        if (_currentStreamingBotMessageId != null && _messages.isNotEmpty) {
          final lastBotMsgIndex = _messages.indexWhere((m) => m.id == _currentStreamingBotMessageId);
          if(lastBotMsgIndex != -1 && _messages[lastBotMsgIndex].isStreaming) {
            setState(() => _messages[lastBotMsgIndex].isStreaming = false);
          }
        }
        _currentStreamingBotMessageId = null;

        if (type == "error") _addErrorMessage(data);
        else if (type == "info") _addMessageToUI(data, MessageSender.info);
      }
      _scrollToBottom(delayMilliseconds: 50);
    } catch (e) {
      _addErrorMessage("Received an invalid server message.");
    }
  }

  void _addMessageToUI(String text, MessageSender sender, {String? id, bool isTemporary = false, bool isStreaming = false}) {
    if (!mounted) return;
    final message = ChatMessage(
      id: id ?? _uuid.v4(),
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
      isStreaming: isStreaming,
    );
    setState(() {
      if (isTemporary) {
        _messages.removeWhere((msg) => (msg.sender == MessageSender.info && (msg.text.startsWith("Connecting"))));
      }
      _messages.insert(0, message);
    });
    _scrollToBottom(delayMilliseconds: 50);
  }

  void _addInitialBotMessage(String text) => _addMessageToUI(text, MessageSender.bot);
  void _addErrorMessage(String text) => _addMessageToUI(text, MessageSender.error);

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSendingMessage || _channel == null) return;

    setState(() { _isSendingMessage = true; });
    _addMessageToUI(text, MessageSender.user);
    _messageController.clear();
    _showTypingIndicator(); // Show indicator

    // Start a timer to hide the indicator if the bot doesn't respond quickly
    _typingIndicatorTimer = Timer(const Duration(seconds: 10), () { // Adjust timeout as needed
      if (mounted && _isBotTypingIndicatorVisible) {
        _hideTypingIndicator();
      }
    });

    List<Map<String, String>> historyForLLM = _messages
        .where((msg) => msg.id != _messages.first.id && (msg.sender == MessageSender.user || (msg.sender == MessageSender.bot && !msg.isStreaming)))
        .map((msg) => {"role": msg.sender == MessageSender.user ? "user" : "model", "content": msg.text})
        .toList().reversed.toList(); // Reverse to get chronological for API

    final userInput = {"query": text, "history": historyForLLM};

    try {
      _channel!.sink.add(jsonEncode(userInput));
    } catch (e) {
      if (mounted) {
        _hideTypingIndicator();
        _addErrorMessage("Error sending: $e.");
      }
    } finally {
      if (mounted) setState(() { _isSendingMessage = false; });
    }
  }

  void _scrollToBottom({int delayMilliseconds = 100}) {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: delayMilliseconds), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
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
    final Brightness appBarBrightness = ThemeData.estimateBrightnessForColor(widget.item.gradientColors.isNotEmpty ? widget.item.gradientColors.first : themeProvider.currentAccentGradient.first);
    final Color appBarContentColor = appBarBrightness == Brightness.dark ? Colors.white : Colors.black87;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: appBarBrightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: currentTheme.cardColor,
      systemNavigationBarIconBrightness: currentTheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: chatAreaBackgroundColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: widget.item.gradientColors.isNotEmpty ? widget.item.gradientColors : themeProvider.currentAccentGradient,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: appBarContentColor, size: 20),
          onPressed: () => Navigator.of(context).pop(), tooltip: "Back",
        ),
        title: Row(children: [
          Icon(widget.item.icon, color: appBarContentColor.withOpacity(0.9), size: 26),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.item.name, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 19, fontWeight: FontWeight.bold, color: appBarContentColor), overflow: TextOverflow.ellipsis)),
        ]),
        elevation: 1.5, shadowColor: Colors.black.withOpacity(0.1), backgroundColor: Colors.transparent,
      ),
      body: Column(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15.0), // Increased horizontal padding
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                // Apply animation only to new messages for smoother feel
                bool shouldAnimate = index == 0 && (message.sender == MessageSender.user || message.isStreaming);
                return shouldAnimate
                    ? EnhancedDelayedAnimation(
                  delay: 0, // Animate immediately for new messages
                  offsetBegin: const Offset(0, 0.05),
                  duration: const Duration(milliseconds: 300),
                  child: _MessageBubble(message: message),
                )
                    : _MessageBubble(message: message);
              },
            ),
          ),
        ),
        if (_isBotTypingIndicatorVisible)
          Padding(
            padding: const EdgeInsets.only(left: 18.0, bottom: 8.0, top: 4.0, right: 18.0), // Adjusted padding
            child: Row(children: [_TypingIndicator(botName: widget.item.name)]),
          ),
        _MessageInputArea(
          controller: _messageController,
          onSend: _sendMessage,
          isSending: _isSendingMessage,
          botName: widget.item.name,
        ),
      ]),
    );
  }
}

// --- Updated _MessageBubble Widget ---
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final bool isUserMessage = message.sender == MessageSender.user;
    final bool isErrorMessage = message.sender == MessageSender.error;
    final bool isInfoMessage = message.sender == MessageSender.info;

    final Color bubbleColor = isUserMessage
        ? colorScheme.primary
        : (isErrorMessage
        ? colorScheme.errorContainer.withOpacity(0.7)
        : (isInfoMessage
        ? Colors.transparent
        : (currentTheme.brightness == Brightness.light
        ? const Color(0xFFF0F0F0) // Light grey for bot bubbles
        : currentTheme.colorScheme.surfaceContainer)));

    final Color textColor = isUserMessage
        ? colorScheme.onPrimary
        : (isErrorMessage
        ? colorScheme.onErrorContainer
        : (isInfoMessage
        ? currentTheme.hintColor.withOpacity(0.9)
        : colorScheme.onSurfaceVariant));

    final Radius largeRadius = Radius.circular(_messageBubbleRadiusLarge);
    final Radius smallRadius = Radius.circular(_messageBubbleRadiusSmall); // For the "tail"

    if (isInfoMessage) {
      return Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 12.0, fontStyle: FontStyle.italic, color: textColor),
        ),
      );
    }

    // Use a Row to align the bubble left or right and allow it to shrink-wrap.
    return Row(
      mainAxisAlignment: isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Max width for bubble
          margin: const EdgeInsets.symmetric(
            vertical: _messageVerticalMargin / 2, // Apply half margin top/bottom
            horizontal: 8.0,
          ),
          decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: isUserMessage ? largeRadius : smallRadius, // Tail effect
                topRight: isUserMessage ? smallRadius : largeRadius, // Tail effect
                bottomLeft: largeRadius,
                bottomRight: largeRadius,
              ),
              boxShadow: [
                BoxShadow(
                  color: currentTheme.shadowColor.withOpacity(0.07),
                  blurRadius: 5,
                  offset: const Offset(1, 2),
                )
              ]),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Let column shrink to content
            crossAxisAlignment: CrossAxisAlignment.start, // Text starts from left within bubble
            children: [
              if (isErrorMessage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.error_outline_rounded, color: textColor.withOpacity(0.8), size: 16),
                ),
              Text(
                message.text + (message.isStreaming ? "▍" : ""),
                style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 15.5, color: textColor, height: 1.45),
              ),
              if (!message.isStreaming) ...[
                const SizedBox(height: 5),
                Text( // Timestamp aligned to the end of the text line
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(fontFamily: _primaryFontFamily, fontSize: _timestampFontSize, color: textColor.withOpacity(0.7)),
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}

// --- Corrected _MessageInputArea Widget (hintText fix) ---
class _MessageInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final String botName; // Already passed

  const _MessageInputArea({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.isSending,
    required this.botName, // Use this
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;
    final bool canSend = controller.text.trim().isNotEmpty && !isSending;

    return Container(
      padding: EdgeInsets.only(
        left: 10.0, right: 8.0, top: 10.0,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 4.0
            : 12.0,
      ),
      decoration: BoxDecoration(
        color: currentTheme.cardColor,
        boxShadow: [ BoxShadow( offset: const Offset(0, -1), blurRadius: 3, color: currentTheme.shadowColor.withOpacity(0.05),),],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: currentTheme.brightness == Brightness.light
                    ? Colors.grey.shade100
                    : currentTheme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(_inputAreaRadius),
              ),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, color: currentTheme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: "Message $botName...", // Use the botName parameter
                  hintStyle: TextStyle(color: currentTheme.hintColor.withOpacity(0.7), fontFamily: _primaryFontFamily, fontSize: 15.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: _inputFieldVerticalPadding, horizontal: 18.0),
                ),
                minLines: 1, maxLines: 5,
                onSubmitted: canSend ? (_) => onSend() : null,
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 8),
          BouncingWidget(
            onPressed: canSend ? onSend : null,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: canSend ? colorScheme.primary : currentTheme.disabledColor.withOpacity(0.4),
              child: isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Icon(Icons.send_rounded, color: Colors.white, size: 23),
            ),
          ),
        ],
      ),
    );
  }
}


class _TypingIndicator extends StatefulWidget {
  // ... (Keep this widget as is for the three animated dots)
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
      duration: const Duration(milliseconds: 1200), // Slightly slower for smoother feel
    )..repeat();

    for (int i = 0; i < 3; i++) {
      _dotAnimations.add(
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.8).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
          TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.2).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
          TweenSequenceItem(tween: ConstantTween(0.2), weight: 30),
        ]).animate(CurvedAnimation(
            parent: _dotController,
            curve: Interval(0.1 * i, 0.6 + 0.1 * i, // Adjusted interval for overlap
                curve: Curves.linear))),
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
    return Padding( // Add padding around the indicator row
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Optional: Add a small bot avatar/icon here
          // CircleAvatar(radius: 10, child: Icon(Icons.android, size: 12)),
          // SizedBox(width: 8),
          AnimatedBuilder(
            animation: _dotController,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Opacity(
                    opacity: _dotAnimations[index].value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5), // Spacing between dots
                      child: Container(
                        width: 7, // Slightly larger dots
                        height: 7,
                        decoration: BoxDecoration(
                          color: currentTheme.hintColor.withOpacity(0.6), // More subtle dots
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
      ),
    );
  }
}
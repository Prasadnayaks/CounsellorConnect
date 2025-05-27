// lib/models/websocket_chat_message_model.dart
import 'package:flutter/foundation.dart'; // For kDebugMode if used

enum WebSocketMessageRole { user, model } // Renamed enum

class WebSocketChatMessageModel { // Renamed class
  final String id;
  final WebSocketMessageRole role; // Uses renamed enum
  String content;
  final DateTime timestamp;

  WebSocketChatMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJsonForServer() {
    return {
      'role': role.name,
      'content': content,
    };
  }
}

class WebSocketServerResponseMessage { // Renamed class
  final String type;
  final String data;

  WebSocketServerResponseMessage({required this.type, required this.data});

  factory WebSocketServerResponseMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketServerResponseMessage(
      type: json['type'] as String,
      data: json['data'] as String,
    );
  }
}
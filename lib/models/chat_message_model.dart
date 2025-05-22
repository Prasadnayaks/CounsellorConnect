// lib/models/chat_message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id; // Document ID from Firestore
  final String senderId;
  final String receiverId; // Good to have for targeted notifications/queries
  final String text;
  final Timestamp timestamp;
  final String messageType; // e.g., 'text', 'image', 'file'
  // isRead might be more complex with multiple recipients,
  // but for 1-to-1, it can be a simple boolean on the message
  // or managed via unread counts in the ChatRoomModel.
  // For simplicity with unread counts in ChatRoomModel, we might not need it here.

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.messageType = 'text',
  });

  factory ChatMessageModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data()!; // Assuming data is always present
    return ChatMessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(), // Fallback, though timestamp should always exist
      messageType: data['messageType'] as String? ?? 'text',
    );
  }

  Map<String, dynamic> toJsonForSend() {
    // Used when creating a new message to send
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(), // Firestore handles server-side timestamp
      'messageType': messageType,
    };
  }
}
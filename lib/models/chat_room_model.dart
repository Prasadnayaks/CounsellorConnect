// lib/models/chat_room_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participantIds;
  final Map<String, String?> participantNames; // { "userId": "User Name", "counselorId": "Counselor Name" }
  final Map<String, String?> participantPhotoUrls; // Optional

  String? lastMessageText;
  Timestamp? lastMessageTimestamp;
  String? lastMessageSenderId;
  String status; // 'pending_user_request', 'active', 'declined_by_counselor', 'closed'

  // Store unread count *for* a specific user ID as the key
  // e.g., { "userId_of_recipient1": 2, "userId_of_recipient2": 0 }
  Map<String, int> unreadCounts;

  final Timestamp createdAt;
  Timestamp? updatedAt;

  ChatRoomModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    this.participantPhotoUrls = const {},
    this.lastMessageText,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
    required this.status,
    this.unreadCounts = const {},
    required this.createdAt,
    this.updatedAt,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Map<String, String?> parseStringMap(dynamic mapData) {
      if (mapData is Map) {
        return Map<String, String?>.from(mapData.map((key, value) => MapEntry(key.toString(), value as String?)));
      }
      return {};
    }
    Map<String, int> parseIntMap(dynamic mapData) {
      if (mapData is Map) {
        return Map<String, int>.from(mapData.map((key, value) => MapEntry(key.toString(), value as int? ?? 0)));
      }
      return {};
    }

    return ChatRoomModel(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] as List? ?? []),
      participantNames: parseStringMap(data['participantNames']),
      participantPhotoUrls: parseStringMap(data['participantPhotoUrls']),
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageTimestamp: data['lastMessageTimestamp'] as Timestamp?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      status: data['status'] as String? ?? 'unknown',
      unreadCounts: parseIntMap(data['unreadCounts']),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toJsonForCreate(String currentUserName, String counselorName, String currentUserId, String counselorId) {
    // When a user initiates a request
    return {
      'participantIds': [currentUserId, counselorId],
      'participantNames': {
        currentUserId: currentUserName,
        counselorId: counselorName,
      },
      // 'participantPhotoUrls': { ... } // Populate if available
      'status': 'pending_user_request',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageText': '$currentUserName requested to chat.',
      'lastMessageSenderId': currentUserId,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCounts': {
        counselorId: 1, // Counselor has 1 unread request
        currentUserId: 0,
      },
    };
  }

  String getOtherParticipantName(String currentUserId) {
    final otherId = participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    return participantNames[otherId] ?? 'Participant';
  }

  String? getOtherParticipantPhotoUrl(String currentUserId) {
    final otherId = participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    return participantPhotoUrls?[otherId];
  }

  int getUnreadCountForUser(String targetUserId) {
    return unreadCounts[targetUserId] ?? 0;
  }
}
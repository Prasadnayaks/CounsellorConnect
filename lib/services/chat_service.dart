// lib/services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_room_model.dart';
// ChatMessageModel might be used internally or by the ChatScreen directly

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  String generateChatRoomId(String userId1, String userId2) {
    if (userId1.hashCode <= userId2.hashCode) {
      return '${userId1}_$userId2';
    } else {
      return '${userId2}_$userId1';
    }
  }



  // --- FOR COUNSELOR CHAT OVERVIEW ---
  Stream<List<ChatRoomModel>> getCounselorChatRoomsStream() {
    // ... (this method was correctly defined before)
    final counselor = currentUser;
    if (counselor == null) {
      print("[ChatService] No counselor logged in, returning empty chat room stream.");
      return Stream.value([]);
    }
    print("[ChatService] Fetching chat rooms for counselor: ${counselor.uid}");
    return _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: counselor.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        print("[ChatService] No chat rooms found for counselor: ${counselor.uid}");
      }
      return snapshot.docs.map((doc) {
        try {
          return ChatRoomModel.fromFirestore(doc);
        } catch (e) {
          print("[ChatService] Error parsing ChatRoomModel from doc ${doc.id}: $e. Data: ${doc.data()}");
          return null;
        }
      }).whereType<ChatRoomModel>().toList();
    }).handleError((error) {
      print("[ChatService] Error in getCounselorChatRoomsStream: $error");
      return <ChatRoomModel>[];
    });
  }

  // --- THIS IS THE METHOD THAT WAS MISSING OR MISNAMED ---
  // Stream for a specific chat room's document (to listen for status changes, last message etc.)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatRoomDocumentStream(String chatRoomId) {
    return _firestore.collection('chatRooms').doc(chatRoomId).snapshots();
  }
  // --- END OF FIX ---


  // --- FOR USER-INITIATED CHAT REQUEST ---
  Future<String?> requestChat({
    // ... (this method was correctly defined before)
    required String currentUserId,
    required String currentUserName,
    String? currentUserPhotoUrl,
    required String counselorId,
    required String counselorName,
    String? counselorPhotoUrl,
    String? initialMessage,
  }) async {
    // ... (implementation as previously provided)
    if (this.currentUser == null || currentUserId != this.currentUser?.uid) {
      print("[ChatService] User not authenticated or ID mismatch for chat request.");
      throw Exception("User not authenticated or ID mismatch.");
    }

    final chatRoomId = generateChatRoomId(currentUserId, counselorId);
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final docSnapshot = await chatRoomRef.get();

    String messageText = initialMessage?.trim().isNotEmpty ?? false
        ? initialMessage!
        : "$currentUserName would like to chat.";

    Map<String, dynamic> participantNames = {
      currentUserId: currentUserName,
      counselorId: counselorName,
    };
    Map<String, dynamic> participantPhotoUrls = {};
    if (currentUserPhotoUrl != null) participantPhotoUrls[currentUserId] = currentUserPhotoUrl;
    if (counselorPhotoUrl != null) participantPhotoUrls[counselorId] = counselorPhotoUrl;


    if (!docSnapshot.exists) {
      Map<String, dynamic> newChatRoomData = {
        'participantIds': [currentUserId, counselorId],
        'participantNames': participantNames,
        if(participantPhotoUrls.isNotEmpty) 'participantPhotoUrls': participantPhotoUrls,
        'status': 'pending_user_request',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': messageText,
        'lastMessageSenderId': currentUserId,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCounts': {
          counselorId: 1,
          currentUserId: 0,
        },
      };
      await chatRoomRef.set(newChatRoomData);
      print("[ChatService] Chat request created: $chatRoomId by $currentUserName for $counselorName");
      // TODO: Send FCM to counselorId
      return chatRoomId;
    } else {
      final existingData = docSnapshot.data() as Map<String, dynamic>;
      final existingStatus = existingData['status'] as String?;
      print("[ChatService] Chat room $chatRoomId already exists with status: $existingStatus");

      if (existingStatus == 'declined_by_counselor' || existingStatus == 'closed_by_counselor' || existingStatus == 'closed_by_user') {
        await chatRoomRef.update({
          'status': 'pending_user_request',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessageText': messageText,
          'lastMessageSenderId': currentUserId,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'unreadCounts.${counselorId}': FieldValue.increment(1),
          'unreadCounts.${currentUserId}': 0,
        });
        print("[ChatService] Re-requested chat for $chatRoomId");
        // TODO: Send FCM to counselorId
      } else if (existingStatus == 'pending_user_request') {
        if (initialMessage?.trim().isNotEmpty ?? false) {
          await chatRoomRef.update({
            'lastMessageText': messageText,
            'lastMessageSenderId': currentUserId,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        print("[ChatService] Chat $chatRoomId is already pending. Last message updated if new initial message provided.");
      }
      return chatRoomId;
    }
  }


  // --- METHODS FOR COUNSELOR CHAT SCREEN ---
  Future<void> approveChatRequest(String chatRoomId, String studentUserIdToNotify, String counselorNameForMessage) async {
    // ... (implementation as previously provided)
    if (currentUser == null) throw Exception("Counselor not authenticated.");
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    try {
      await chatRoomRef.update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': '$counselorNameForMessage approved the chat request.',
        'lastMessageSenderId': currentUser!.uid,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCounts.${studentUserIdToNotify}': FieldValue.increment(1),
        'unreadCounts.${currentUser!.uid}': 0,
      });
      print("[ChatService] Chat request $chatRoomId approved by ${currentUser!.uid}");
      // TODO: Send FCM notification to studentUserIdToNotify
    } catch (e) {
      print("[ChatService] Error approving chat request $chatRoomId: $e");
      rethrow;
    }
  }

  Future<void> declineChatRequest(String chatRoomId, String studentUserIdToNotify) async {
    // ... (implementation as previously provided)
    if (currentUser == null) throw Exception("Counselor not authenticated.");
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    try {
      await chatRoomRef.update({
        'status': 'declined_by_counselor',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': 'Chat request declined by counselor.',
        'lastMessageSenderId': currentUser!.uid,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCounts.${studentUserIdToNotify}': FieldValue.increment(1),
        'unreadCounts.${currentUser!.uid}': 0,
      });
      print("[ChatService] Chat request $chatRoomId declined by ${currentUser!.uid}");
      // TODO: Send FCM notification to studentUserIdToNotify
    } catch (e) {
      print("[ChatService] Error declining chat request $chatRoomId: $e");
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(String chatRoomId) {
    // ... (implementation as previously provided)
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String currentUserId,
    required String partnerId,
  }) async {
    // ... (implementation as previously provided)
    if (text.trim().isEmpty || this.currentUser == null || currentUserId != this.currentUser?.uid) {
      print("[ChatService] Cannot send message: Empty text, no user, or ID mismatch.");
      return;
    }

    final messageData = {
      'senderId': currentUserId,
      'receiverId': partnerId,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': 'text',
    };

    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    final messageRef = chatRoomRef.collection('messages');

    try {
      await messageRef.add(messageData);

      await chatRoomRef.update({
        'lastMessageText': text.trim(),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.$partnerId': FieldValue.increment(1),
      });
      print("[ChatService] Message sent in $chatRoomId by $currentUserId to $partnerId");
      // TODO: Send FCM notification to partnerId
    } catch (e) {
      print("[ChatService] Error sending message in $chatRoomId: $e");
      rethrow;
    }
  }

  Future<void> markChatRoomAsRead(String chatRoomId, String currentUserIdInChat) async {
    // ... (implementation as previously provided)
    if (currentUser == null || currentUserIdInChat != currentUser!.uid) return;
    final chatRoomRef = _firestore.collection('chatRooms').doc(chatRoomId);
    try {
      await chatRoomRef.update({
        // Construct the field path dynamically
        'unreadCounts.$currentUserIdInChat': 0,
      });
      print("[ChatService] Chat room $chatRoomId marked as read for $currentUserIdInChat");
    } catch (e) {
      print("[ChatService] Error marking chat room $chatRoomId as read: $e");
    }
  }
}
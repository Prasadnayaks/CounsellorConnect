import 'package:cloud_firestore/cloud_firestore.dart';

class DailyChallengeCompletionEntry {
  final String? id; // Firestore document ID (YYYY-MM-DD)
  final String userId;
  final String challengeId;
  final String challengeDescription;
  final String assignedDate; // YYYY-MM-DD string
  final String status; // Should be 'completed'
  final DateTime expiresAt;
  final DateTime? startedAt;
  final DateTime completedAt;
  final String photoUrl;
  final DateTime createdAt;

  DailyChallengeCompletionEntry({
    this.id,
    required this.userId,
    required this.challengeId,
    required this.challengeDescription,
    required this.assignedDate,
    required this.status,
    required this.expiresAt,
    this.startedAt,
    required this.completedAt,
    required this.photoUrl,
    required this.createdAt,
  });

  factory DailyChallengeCompletionEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DailyChallengeCompletionEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      challengeId: data['challengeId'] as String? ?? '',
      challengeDescription: data['challengeDescription'] as String? ?? 'Challenge completed.',
      assignedDate: data['assignedDate'] as String? ?? '',
      status: data['status'] as String? ?? 'completed',
      expiresAt: (data['expiresAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      photoUrl: data['photoUrl'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}
// lib/models/general_photo_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GeneralPhotoEntry {
  final String? id; // Firestore document ID
  final String imageUrl;
  final DateTime uploadedAt;
  final String userId;
  // final String? caption; // Optional for future

  GeneralPhotoEntry({
    this.id,
    required this.imageUrl,
    required this.uploadedAt,
    required this.userId,
    // this.caption,
  });

  factory GeneralPhotoEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GeneralPhotoEntry(
      id: doc.id,
      imageUrl: data['imageUrl'] as String? ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      userId: data['userId'] as String? ?? '',
      // caption: data['caption'] as String?,
    );
  }
}
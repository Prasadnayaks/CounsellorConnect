import 'package:cloud_firestore/cloud_firestore.dart';

class TruthReflectionEntry {
  final String? id;
  final String userId;
  final String dayTheme;
  final String prompt;
  final String reflectionText;
  final String? imageUrl;
  final DateTime entryDateTime;
  final DateTime createdAt;

  TruthReflectionEntry({
    this.id,
    required this.userId,
    required this.dayTheme,
    required this.prompt,
    required this.reflectionText,
    this.imageUrl,
    required this.entryDateTime,
    required this.createdAt,
  });

  factory TruthReflectionEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TruthReflectionEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      dayTheme: data['dayTheme'] as String? ?? 'Reflection',
      prompt: data['prompt'] as String? ?? '',
      reflectionText: data['reflectionText'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      entryDateTime: (data['entryDateTime'] as Timestamp? ?? Timestamp.now()).toDate(),
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}
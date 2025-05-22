import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceNoteEntry {
  final String title;
  final String text;
  final DateTime entryDateTime;

  VoiceNoteEntry({
    required this.title,
    required this.text,
    required this.entryDateTime,
  });

  factory VoiceNoteEntry.fromJson(Map<String, dynamic>? json) {
    json ??= {}; // Add this line to handle null json

    return VoiceNoteEntry(
      title: json['title'] as String? ?? "",
      text: json['text'] as String? ?? "",
      entryDateTime: (json['entryDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(), // Handle null Timestamp
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'text': text,
      'entryDateTime': entryDateTime,
    };
  }
}
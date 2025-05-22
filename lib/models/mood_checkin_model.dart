// lib/models/mood_checkin_model.dart (Example - Adjust as needed)
import 'package:cloud_firestore/cloud_firestore.dart';

class MoodCheckinEntry {
  final String moodLabel;
  final int moodIndex;
  final DateTime entryDateTime;
  final List<String> selectedActivities;
  final List<String> selectedFeelings;
  final String? title;
  final String? notes;

  MoodCheckinEntry({
    required this.moodLabel,
    required this.moodIndex,
    required this.entryDateTime,
    required this.selectedActivities,
    required this.selectedFeelings,
    this.title,
    this.notes,
  });

  factory MoodCheckinEntry.fromJson(Map<String, dynamic>? json) {
    json ??= {}; // Add this line to handle null json

    return MoodCheckinEntry(
      moodLabel: json['moodLabel'] as String? ?? "",
      moodIndex: json['moodIndex'] as int? ?? 0,
      entryDateTime: (json['entryDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(), // Handle null Timestamp
      selectedActivities: List<String>.from(json['selectedActivities'] as List? ?? []),
      selectedFeelings: List<String>.from(json['selectedFeelings'] as List? ?? []),
      title: json['title'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moodLabel': moodLabel,
      'moodIndex': moodIndex,
      'entryDateTime': entryDateTime,
      'selectedActivities': selectedActivities,
      'selectedFeelings': selectedFeelings,
      'title': title,
      'notes': notes,
    };
  }
}
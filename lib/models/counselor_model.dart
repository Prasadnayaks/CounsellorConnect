// lib/models/counselor_model.dart
// import 'package:cloud_firestore/cloud_firestore.dart';

class Counselor {
  final String id;
  final String name;
  final String specialization;
  final String description;
  final String photoUrl;

  Counselor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.description,
    required this.photoUrl,
  });

  factory Counselor.fromMap(Map<String, dynamic> data, String documentId) {
    try {
      return Counselor(
        id: documentId,
        name: data['name'] as String, // Expect non-null String
        specialization: data['specialization'] as String, // Expect non-null String
        // For description, a default if missing might still be acceptable:
        description: data['description'] as String? ?? 'No description provided.',
        photoUrl: data['photoUrl'] as String? ?? '', // Default to empty string is fine
      );
    } catch (e) {
      print('Error parsing Counselor from map for document ID $documentId: $e');
      print('Data was: $data');
      // This allows _fetchCounselors to catch the error for the specific document
      rethrow;
    }
  }
}
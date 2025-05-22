// lib/models/appointment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatting helper

class Appointment {
  final String id;
  final String userId;
  final String? userName; // User's name saved for convenience
  final String counselorId;
  final String counselorName; // Counselor's name saved for convenience
  final Timestamp requestedDateTime; // User's originally requested time
  final Timestamp? confirmedDateTime; // Time confirmed by counselor (nullable)
  final String status; // e.g., "pending", "confirmed", "declined", "done", "cancelled_by_user"
  final String? meetingLink; // Added this field
  final Timestamp createdAt; // When the request was made

  Appointment({
    required this.id,
    required this.userId,
    this.userName,
    required this.counselorId,
    required this.counselorName,
    required this.requestedDateTime,
    this.confirmedDateTime,
    required this.status,
    this.meetingLink, // Added to constructor
    required this.createdAt,
  });

  // Helper to get the relevant display date/time
  DateTime get displayDateTime => (confirmedDateTime ?? requestedDateTime).toDate();

  // Helper for formatted display string
  String get formattedDisplayDateTime => DateFormat('EEE, MMM d, yyyy  hh:mm a').format(displayDateTime); // Corrected year format
  String get formattedDisplayDate => DateFormat('EEE, MMM d, yyyy').format(displayDateTime); // Corrected year format
  String get formattedDisplayTime => DateFormat('hh:mm a').format(displayDateTime);

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>; // Assume data is not null if doc exists

    // For required fields, if they are null in Firestore, this will now cause an error during parsing,
    // which is better than creating an object with invalid default data.
    // This helps identify issues with the data in Firestore itself.
    try {
      return Appointment(
        id: doc.id,
        userId: data['userId'] as String, // Expect non-null
        userName: data['userName'] as String?, // Can be null
        counselorId: data['counselorId'] as String, // Expect non-null
        counselorName: data['counselorName'] as String, // Expect non-null
        requestedDateTime: data['requestedDateTime'] as Timestamp, // Expect non-null
        confirmedDateTime: data['confirmedDateTime'] as Timestamp?, // Can be null
        status: data['status'] as String, // Expect non-null
        meetingLink: data['meetingLink'] as String?, // Can be null
        createdAt: data['createdAt'] as Timestamp, // Expect non-null
      );
    } catch (e) {
      print('Error parsing Appointment from Firestore for doc ID ${doc.id}: $e');
      print('Data was: $data');
      // Re-throwing the error will allow the caller (_fetchUserAppointments)
      // to catch it and handle it (e.g., by logging and skipping this item).
      rethrow;
    }
  }
}
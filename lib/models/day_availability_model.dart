import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:intl/intl.dart';         // For DateFormat

// Helper class to hold availability for a single day
class DayAvailability {
  final bool isWorking;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  DayAvailability({
    this.isWorking = false,
    this.startTime,
    this.endTime,
  });

  // Helper to format TimeOfDay to "HH:mm" for Firestore
  static String? formatTimeOfDay(TimeOfDay? tod) {
    if (tod == null) return null;
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat.Hm().format(dt); // HH:mm (24-hour format)
  }

  // Helper to parse "HH:mm" string from Firestore to TimeOfDay
  static TimeOfDay? parseTimeOfDay(String? formattedString) {
    if (formattedString == null || formattedString.isEmpty) return null;
    try {
      final parts = formattedString.split(':');
      if (parts.length == 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        // Basic validation for TimeOfDay arguments
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return TimeOfDay(hour: hour, minute: minute);
        } else {
          print("Error parsing time string '$formattedString': Invalid hour or minute values.");
          return null;
        }
      }
    } catch (e) {
      print("Error parsing time string '$formattedString': $e");
    }
    return null;
  }

  // For saving to Firestore
  Map<String, dynamic> toJson() => {
    'isWorking': isWorking,
    'startTime': formatTimeOfDay(startTime),
    'endTime': formatTimeOfDay(endTime),
  };

  // For creating from Firestore data
  factory DayAvailability.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DayAvailability(isWorking: false); // Default if no data
    }
    return DayAvailability(
      isWorking: json['isWorking'] as bool? ?? false,
      startTime: parseTimeOfDay(json['startTime'] as String?),
      endTime: parseTimeOfDay(json['endTime'] as String?),
    );
  }

  DayAvailability copyWith({ // For easily creating modified copies
    bool? isWorking,
    ValueGetter<TimeOfDay?>? startTime, // Use ValueGetter for nullable properties
    ValueGetter<TimeOfDay?>? endTime,
  }) {
    return DayAvailability(
      isWorking: isWorking ?? this.isWorking,
      startTime: startTime != null ? startTime() : this.startTime,
      endTime: endTime != null ? endTime() : this.endTime,
    );
  }
}
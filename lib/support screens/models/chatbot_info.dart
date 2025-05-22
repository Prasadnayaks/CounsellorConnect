// lib/support screens/models/chatbot_info.dart
// Will be conceptually treated as self_care_item_model.dart
import 'package:flutter/material.dart';

class SelfCareItem { // Renamed from ChatbotInfo
  final String id;
  final String name;
  final String subtitle; // Changed from description to subtitle (e.g., "9 EXERCISES")
  final IconData icon;
  final List<Color> gradientColors;

  SelfCareItem({ // Updated constructor
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
  });
}
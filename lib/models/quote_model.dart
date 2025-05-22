// lib/models/quote_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:convert'; // Not needed for this constructor if ID is in JSON
// import 'package:crypto/crypto.dart'; // Not needed if ID is in JSON

class QuoteModel {
  final String id;
  final String text;
  final String author;
  final String imageUrl; // This will be assigned when loading
  final String? category;

  QuoteModel({
    required this.id,
    required this.text,
    required this.author,
    required this.imageUrl,
    this.category = "General",
  });

  // Factory constructor for ZenQuotes API response (keep if still needed for fallback)
  // factory QuoteModel.fromZenQuotesJson(Map<String, dynamic> json, String assignedBgImageUrl) {
  //   String quoteText = json['q'] ?? '...';
  //   String authorName = json['a'] ?? 'Unknown';
  //   var bytes = utf8.encode(quoteText + authorName);
  //   var digest = sha1.convert(bytes);
  //   String generatedId = digest.toString();
  //   return QuoteModel(
  //     id: generatedId,
  //     text: quoteText,
  //     author: authorName,
  //     imageUrl: assignedBgImageUrl,
  //     category: "General", // ZenQuotes basic endpoint doesn't give categories
  //   );
  // }

  // NEW Factory constructor for your local JSON data
  factory QuoteModel.fromLocalJson(Map<String, dynamic> json, String assignedBgImageUrl) {
    return QuoteModel(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback ID
      text: json['text'] as String? ?? '...',
      author: json['author'] as String? ?? 'Unknown',
      imageUrl: assignedBgImageUrl, // Image URL is assigned during loading
      category: json['category'] as String? ?? "General",
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'author': author,
    'imageUrl': imageUrl, // When saving to Firestore (e.g., liked quotes)
    'category': category,
  };

  factory QuoteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return QuoteModel(
      id: doc.id,
      text: data['text'] ?? 'Unknown Text',
      author: data['author'] ?? 'Unknown Author',
      imageUrl: data['imageUrl'] ?? '',
      category: data['category'] as String?,
    );
  }
}
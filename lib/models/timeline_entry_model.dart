enum EntryType { mood, voice, truth, challenge }

class TimelineEntry implements Comparable<TimelineEntry> {
  final DateTime date; // Common date for sorting (use createdAt or entryDateTime)
  final EntryType type;
  final dynamic data; // Actual specific entry object
  final String? id; // Firestore document ID for potential actions (delete, edit)

  TimelineEntry({required this.date, required this.type, required this.data, this.id});

  @override
  int compareTo(TimelineEntry other) {
    // Sort by date descending (newest first)
    return other.date.compareTo(date);
  }
}
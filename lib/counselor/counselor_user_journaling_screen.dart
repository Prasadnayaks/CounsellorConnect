// lib/counselor/counselor_user_journaling_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../theme/theme_provider.dart';
import 'counselor_profile_screen.dart';

// --- Private Journal Entry Model ---
class _JournalEntry {
  final String id;
  final String? title;
  final String content;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  _JournalEntry({
    required this.id,
    this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _JournalEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return _JournalEntry(
      id: doc.id,
      title: data['title'] as String?,
      content: data['content'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
// --- End Model ---

// --- Helper for Themed SnackBar ---
void _showComingSoonSnackBar(BuildContext context, String featureName) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '$featureName feature is coming soon!',
        style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontFamily: CounselorUserJournalingScreenState._primaryFontFamily), // Access static from state
      ),
      backgroundColor: colorScheme.inverseSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      margin: const EdgeInsets.all(12.0), // Adjusted margin
      elevation: 4.0,
    ),
  );
}
// --- End SnackBar Helper ---


class CounselorUserJournalingScreen extends StatefulWidget {
  const CounselorUserJournalingScreen({Key? key}) : super(key: key);

  @override
  State<CounselorUserJournalingScreen> createState() =>
      CounselorUserJournalingScreenState(); // Made state public for SnackBar helper
}

class CounselorUserJournalingScreenState
    extends State<CounselorUserJournalingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentCounselor;

  static const String _primaryFontFamily = 'Nunito'; // Made static for SnackBar
  static const double _cardRadius = 18.0; // More consistent with other screens

  @override
  void initState() {
    super.initState();
    _currentCounselor = _auth.currentUser;
  }

  CollectionReference<Map<String, dynamic>>? _getEntriesCollectionRef() {
    if (_currentCounselor == null) return null;
    return _firestore
        .collection('counselorJournals')
        .doc(_currentCounselor!.uid)
        .collection('entries');
  }

  Future<void> _deleteJournalEntry(String entryId) async {
    final collectionRef = _getEntriesCollectionRef();
    if (collectionRef == null || !mounted) return;

    bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) {
          final dialogTheme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
            title: Text('Delete Entry?', style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold)),
            content: Text('Are you sure you want to delete this journal entry? This action cannot be undone.', style: TextStyle(fontFamily: _primaryFontFamily)),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel', style: TextStyle(fontFamily: _primaryFontFamily, color: dialogTheme.hintColor)),
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              TextButton(
                child: Text('Delete', style: TextStyle(fontFamily: _primaryFontFamily, color: dialogTheme.colorScheme.error, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        }
    );

    if (confirmDelete == true) {
      try {
        await collectionRef.doc(entryId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Journal entry deleted.")));
        }
      } catch (e) {
        print("Error deleting journal entry: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Failed to delete entry: ${e.toString()}")));
        }
      }
    }
  }

  void _navigateToEditScreen(_JournalEntry? entry) {
    if (_currentCounselor == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AddEditJournalPage(
          entry: entry,
          counselorId: _currentCounselor!.uid,
        ),
      ),
    );
  }

  List<BoxShadow> _getJournalCardShadow(BuildContext context) {
    final theme = Theme.of(context);
    // A more pronounced shadow as requested
    return [
      BoxShadow(
        color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.20 : 0.10),
        blurRadius: 18.0,
        spreadRadius: 0.5, // Keep spread minimal for definition
        offset: const Offset(0, 8.0), // Push shadow downwards
      ),
      BoxShadow(
        color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.10 : 0.06),
        blurRadius: 8.0,
        offset: const Offset(0, 3.0),
      ),
    ];
  }

  Widget _buildProfileButton(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.8);
    final profileButtonBg = theme.brightness == Brightness.light ? Colors.grey.shade200 : theme.colorScheme.surfaceContainerHighest;

    return SizedBox(
      width: 44, height: 44,
      child: Material(
        color: profileButtonBg,
        borderRadius: BorderRadius.circular(12.0),
        clipBehavior: Clip.antiAlias,
        elevation: 0.5, // Subtle elevation for the button itself
        shadowColor: theme.shadowColor.withOpacity(0.1),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CounselorProfileScreen()),
            );
          },
          borderRadius: BorderRadius.circular(12.0),
          child: Icon(Icons.person_outline_rounded, color: iconColor, size: 26),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    const double conceptualOverlap = 20.0; // For title overlap effect

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // For custom header
      statusBarIconBrightness: theme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: theme.brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 10, // Space for status bar
                left: 16,
                right: 16,
                bottom: 5, // Reduced bottom padding before titles
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Flexible spacer to help center title if no leading widget
                  const SizedBox(width: 44), // Match profile button width for balance
                  const Spacer(), // Pushes title to center if needed
                  // Title now handled by the Stack below for overlap effect
                  const Spacer(),
                  _buildProfileButton(context),
                ],
              ),
            ),
          ),

          // --- Title Section (Reflectly/EntriesScreen style) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0, bottom: conceptualOverlap + 5),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    "JOURNAL", // Large Faded Text
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 64, // Larger, more impactful
                      fontWeight: FontWeight.w900,
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.displayLarge?.color?.withOpacity(0.05), // Even more subtle
                      height: 0.8,
                    ),
                  ),
                  Transform.translate( // Prominent title overlaid
                    offset: const Offset(0, -12), // The desired overlap
                    child: Text(
                      "My Journal",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: _primaryFontFamily,
                        fontWeight: FontWeight.bold, // Bolder prominent title
                        color: theme.textTheme.titleLarge?.color?.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- End Title Section ---

          SliverPadding(
            padding:
            const EdgeInsets.fromLTRB(16, 10, 16, 100), // Bottom padding for FAB
            sliver: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getEntriesCollectionRef()
                  ?.orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (_currentCounselor == null) {
                  return const SliverFillRemaining(child: Center(child: Text("Please log in.")));
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(child: Center(child: Text("Error: ${snapshot.error}")));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_stories_outlined, // Changed icon
                                size: 70,
                                color: theme.hintColor.withOpacity(0.45)),
                            const SizedBox(height: 20),
                            Text('Your Journal is Awaiting Stories',
                                style: theme.textTheme.titleLarge?.copyWith(
                                    fontFamily: _primaryFontFamily,
                                    color: theme.textTheme.titleMedium?.color?.withOpacity(0.75))),
                            const SizedBox(height: 10),
                            Text(
                                'Tap the "+" button below to pen down your thoughts and reflections.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: _primaryFontFamily,
                                    fontSize: 15,
                                    color: theme.hintColor,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final entries = snapshot.data!.docs
                    .map((doc) => _JournalEntry.fromFirestore(doc))
                    .toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final entry = entries[index];
                      // Apply Transform.translate for the first card for overlap
                      return Transform.translate(
                        offset: Offset(0, index == 0 ? -conceptualOverlap : 0),
                        child: _buildJournalEntryCard(entry, theme, colorScheme),
                      );
                    },
                    childCount: entries.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(null),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add_rounded, size: 28), // Just icon, slightly larger
        elevation: 6.0, // Standard FAB elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Consistent shape
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildJournalEntryCard(
      _JournalEntry entry, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0, // Shadow is now handled by the Container wrapper
      margin: const EdgeInsets.only(bottom: 20.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      clipBehavior: Clip.antiAlias, // Important for InkWell ripple
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: _getJournalCardShadow(context), // Apply higher shadow
        ),
        child: InkWell(
          onTap: () => _navigateToEditScreen(entry),
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(20.0), // Slightly increased padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.title != null && entry.title!.isNotEmpty)
                            Text(
                              entry.title!,
                              style: theme.textTheme.titleLarge?.copyWith( // Larger title
                                  fontWeight: FontWeight.w600, // Bold but not too heavy
                                  fontFamily: _primaryFontFamily,
                                  color: theme.textTheme.headlineSmall?.color, // More prominent title color
                                  height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (entry.title != null && entry.title!.isNotEmpty)
                            const SizedBox(height: 6), // More space if title exists
                          Text(
                            // Format: "Mon, May 13 ・ 10:30 AM"
                            "${DateFormat('EEE, MMM d').format(entry.createdAt.toDate())}  ·  ${DateFormat('hh:mm a').format(entry.createdAt.toDate())}",
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                                fontFamily: _primaryFontFamily,
                                fontSize: 12, // Consistent small font size
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert_rounded,
                          color: theme.hintColor.withOpacity(0.8), size: 24),
                      onPressed: () => _showDeleteActionSheet(entry.id), // Pass full context
                      tooltip: 'Options',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  entry.content,
                  style: theme.textTheme.bodyLarge?.copyWith( // Slightly larger body text
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
                      fontSize: 15.5,
                      height: 1.55),
                  maxLines: 4, // Show a bit more content
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteActionSheet(String entryId) { // Removed context from params, will use widget's context
    final theme = Theme.of(this.context); // Use this.context or just context
    showModalBottomSheet(
        context: this.context, // Explicitly use screen's context
        backgroundColor: theme.cardColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
        builder: (BuildContext bottomSheetContext) { // Use a different context name
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.edit_outlined, color: theme.iconTheme.color),
                    title: Text('Edit Entry', style: TextStyle(fontFamily: _primaryFontFamily, color: theme.textTheme.bodyLarge?.color)),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _getEntriesCollectionRef()?.doc(entryId).get().then((doc) {
                        if (doc.exists) {
                          _navigateToEditScreen(_JournalEntry.fromFirestore(doc as DocumentSnapshot<Map<String,dynamic>>));
                        }
                      });
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    title: Text('Delete Entry', style: TextStyle(fontFamily: _primaryFontFamily, color: theme.colorScheme.error)),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _deleteJournalEntry(entryId); // Pass just entryId
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel', style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.w600, color: theme.hintColor)),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }
}

// --- Add/Edit Page (Private Widget within the same file) ---
class _AddEditJournalPage extends StatefulWidget {
  final _JournalEntry? entry;
  final String counselorId;

  const _AddEditJournalPage({Key? key, this.entry, required this.counselorId})
      : super(key: key);

  @override
  _AddEditJournalPageState createState() => _AddEditJournalPageState();
}

class _AddEditJournalPageState extends State<_AddEditJournalPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  DateTime _selectedDate = DateTime.now();

  static const String _primaryFontFamily = 'Nunito';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title);
    _contentController = TextEditingController(text: widget.entry?.content);
    _selectedDate = widget.entry?.createdAt.toDate() ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final collectionRef = FirebaseFirestore.instance
        .collection('counselorJournals')
        .doc(widget.counselorId)
        .collection('entries');

    final data = {
      'title': _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Adjust timestamp for consistency: use selectedDate for both createdAt (new) and potentially to override createdAt (existing)
    // For simplicity, we'll always use _selectedDate combined with current time for createdAt if new,
    // or if editing, one might choose to not update createdAt.
    // Let's make createdAt reflect the actual user-picked date of the event.

    DateTime entryTimestamp = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        DateTime.now().hour, DateTime.now().minute, DateTime.now().second // Keep current time part
    );


    try {
      if (widget.entry != null) {
        // If editing, update the 'createdAt' if the date was changed to reflect the journal entry's perceived date.
        // 'updatedAt' is always new.
        data['createdAt'] = Timestamp.fromDate(entryTimestamp);
        await collectionRef.doc(widget.entry!.id).update(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Journal entry updated.")));
        }
      } else {
        data['createdAt'] = Timestamp.fromDate(entryTimestamp);
        await collectionRef.add(data);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Journal entry saved.")));
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("Error saving journal entry: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to save entry: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 365)), // Allow future dates slightly
        builder: (context, child) {
          final theme = Theme.of(context);
          return Theme(
            data: theme.copyWith(
                colorScheme: theme.colorScheme.copyWith(
                  primary: theme.colorScheme.primary,
                  onPrimary: theme.colorScheme.onPrimary,
                  surface: theme.cardColor,
                  onSurface: theme.textTheme.bodyLarge?.color,
                ),
                dialogBackgroundColor: theme.dialogBackgroundColor,
                datePickerTheme: theme.datePickerTheme.copyWith(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                )
            ),
            child: child!,
          );
        }
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        // Preserve time part from original _selectedDate or current time
        final originalTime = TimeOfDay.fromDateTime(_selectedDate);
        _selectedDate = DateTime(picked.year, picked.month, picked.day, originalTime.hour, originalTime.minute);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0, // Flat AppBar
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.iconTheme.color, size: 24), // Standard back
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        title: InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('d').format(_selectedDate),
                  style: TextStyle(
                      fontSize: 22, // Prominent day
                      fontWeight: FontWeight.bold,
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.titleLarge?.color),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMM').format(_selectedDate).toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: _primaryFontFamily,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.9)),
                    ),
                    Text(
                      DateFormat('yyyy').format(_selectedDate),
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: _primaryFontFamily,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down_rounded, color: theme.iconTheme.color?.withOpacity(0.7), size: 22),
              ],
            ),
          ),
        ),
        actions: [
          // "..." menu for future options if needed
          // IconButton(
          //   icon: Icon(Icons.more_horiz_rounded, color: theme.iconTheme.color, size: 26),
          //   onPressed: () {},
          // ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                padding: const EdgeInsets.symmetric(horizontal: 24), // Wider save button
                elevation: 2,
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white,))
                  : Text('SAVE', style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
      body: GestureDetector( // To dismiss keyboard when tapping outside text fields
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0), // Adjust top padding
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(
                      fontFamily: _primaryFontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color),
                  decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: TextStyle(
                          fontFamily: _primaryFontFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor.withOpacity(0.4)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8)
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contentController,
                  style: TextStyle(
                      fontFamily: _primaryFontFamily,
                      fontSize: 17,
                      height: 1.65,
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9)),
                  decoration: InputDecoration(
                      hintText: 'Write more here...',
                      hintStyle: TextStyle(
                          fontFamily: _primaryFontFamily,
                          fontSize: 17,
                          color: theme.hintColor.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8)
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please write your thoughts.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      // --- Bottom Toolbar (Placeholder Icons) ---
      bottomNavigationBar: Container(
        height: 60 + MediaQuery.of(context).padding.bottom, // Standard height + safe area
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom - 8 : 8, // Adjust for gesture nav
            left: 16, right: 16, top: 8
        ),
        decoration: BoxDecoration(
          color: theme.cardColor, // Or theme.bottomAppBarTheme.color
          border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
          // boxShadow: [
          //   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0,-1))
          // ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildToolbarIcon(context, Icons.image_outlined, "Add Image", theme),
            _buildToolbarIcon(context, Icons.emoji_emotions_outlined, "Set Mood", theme),
            _buildToolbarIcon(context, Icons.text_format, "Format Text", theme),
            _buildToolbarIcon(context, Icons.label_outline_rounded, "Add Tags", theme),
            _buildToolbarIcon(context, Icons.mic_none_outlined, "Voice Input", theme),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarIcon(BuildContext context, IconData icon, String tooltip, ThemeData theme){
    return IconButton(
      icon: Icon(icon, color: theme.iconTheme.color?.withOpacity(0.65), size: 24),
      tooltip: tooltip,
      onPressed: (){
        _showComingSoonSnackBar(context, tooltip);
      },
    );
  }
}
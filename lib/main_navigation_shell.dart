// lib/main_navigation_shell.dart
import 'dart:io'; // Required for File type
import 'package:counsellorconnect/support%20screens/appointment_screen.dart';
import 'package:counsellorconnect/entries_screen.dart';
import 'package:counsellorconnect/support_screen.dart';
import 'package:counsellorconnect/voicenotes/voice_note_start_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';

// Firebase and Image Picker
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// Import your screen widgets
import 'home_screen.dart';
import 'mood_checkin/mood_checkin_screen.dart';
import 'thoughts_screen.dart';
import 'theme/theme_provider.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Text('$title Screen (Placeholder)',
            style: Theme.of(context).textTheme.headlineSmall));
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({Key? key}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isMenuOpen = false;
  late AnimationController _animationController;
  late Animation<double> _rotateAnimation;

  // Firebase and Image Picker instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;


  final List<Widget> _screens = [
    const HomeScreen(),
    const ThoughtsScreen(),
    const SupportScreen(), // Your existing SupportScreen
    const EntriesScreen(),
  ];

  final double _fabBottomMargin = 20.0;
  final double _bottomNavBarHeight = 65.0;
  final double _fabSize = 56.0;
  final double _topCornerRadius = 40.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.375).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (!mounted) return;
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  // --- New method for picking and uploading a general photo ---
  Future<void> _pickAndUploadGeneralPhoto() async {
    if (_isUploadingPhoto) return; // Prevent multiple uploads

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to add photos.")),
      );
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1920);
      if (pickedFile == null) {
        if (mounted) setState(() => _isUploadingPhoto = false);
        return;
      }

      File imageFile = File(pickedFile.path);
      String fileName = 'user_general_photos/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      Reference storageRef = _storage.ref().child(fileName);

      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Save photo metadata to Firestore
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('userPhotos') // New collection for general photos
          .add({
        'imageUrl': downloadUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'userId': currentUser.uid,
        'storagePath': fileName, // Optional: to help with deletion later
        // You could add a caption field here in the future
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo added successfully!")),
        );
      }
    } catch (e) {
      print("Error adding photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to add photo: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final finalBottomPadding = bottomPadding >= 0 ? bottomPadding : 0.0;
    final double menuBottomPosition = finalBottomPadding +
        _bottomNavBarHeight -
        (_fabSize / 4) +
        _fabBottomMargin;

    return Scaffold(
      backgroundColor: currentTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          if (_isMenuOpen) _buildDismissLayer(),
          Positioned(
            bottom: menuBottomPosition,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildPopupMenuWithAnimatedBuilder(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        left: false,
        right: false,
        child: Container(
          decoration: BoxDecoration(
            color: currentTheme.bottomAppBarTheme.color ?? currentTheme.cardColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_topCornerRadius),
              topRight: Radius.circular(_topCornerRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: currentTheme.shadowColor.withOpacity(0.1),
                blurRadius: 8.0,
                spreadRadius: 0.0,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: _buildBottomAppBar(context),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildDismissLayer() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleMenu,
        behavior: HitTestBehavior.opaque,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildPopupMenuWithAnimatedBuilder(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double verticalShift = 30.0 * (1.0 - _animationController.value);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (_animationController.value == 0.0 && !_isMenuOpen) {
          return const SizedBox.shrink();
        }
        return Transform.translate(
          offset: Offset(0, verticalShift),
          child: Transform.scale(
            scale: _animationController.value,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: _animationController.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.50, // Slightly wider for 3 items
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0), // Adjusted padding
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column( // Using Column for vertical arrangement
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPopupMenuItem(context,
                icon: Icons.sentiment_satisfied_outlined,
                text: 'Mood check-in', onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const MoodCheckinScreen()));
                }),
            Divider(color: colorScheme.onPrimary.withOpacity(0.3), height: 8, indent: 10, endIndent: 10), // shorter divider
            _buildPopupMenuItem(context,
                icon: Icons.graphic_eq, text: 'Voice note', onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const VoiceNoteStartScreen()));
                }),
            Divider(color: colorScheme.onPrimary.withOpacity(0.3), height: 8, indent: 10, endIndent: 10),
            // --- New "Add Photo" Menu Item ---
            _buildPopupMenuItem(context,
              icon: Icons.photo_camera_back_outlined, // Or Icons.add_a_photo_outlined
              text: 'Add Photo',
              onTap: _pickAndUploadGeneralPhoto, // Calls the new method
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenuItem(BuildContext context,
      {required IconData icon,
        required String text,
        required VoidCallback onTap}) {
    final Color itemColor = Theme.of(context).colorScheme.onPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _toggleMenu(); // Close menu first
          onTap();     // Then perform action
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), // Consistent padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Keep spaceBetween for icon on right
            children: [
              Text(text, style: TextStyle(color: itemColor, fontSize: 15, fontWeight: FontWeight.w500)), // Slightly smaller font
              Icon(icon, color: itemColor, size: 20), // Slightly smaller icon
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAppBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RoundedRectangleBorder hostShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(_topCornerRadius),
        topRight: Radius.circular(_topCornerRadius),
      ),
    );

    return BottomAppBar(
      shape: AutomaticNotchedShape(hostShape),
      notchMargin: 8.0,
      color: theme.bottomAppBarTheme.color,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _bottomNavBarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
                context: context, index: 0, icon: Icons.wb_sunny_outlined, label: 'Sun'),
            _buildBottomNavItem(
                context: context, index: 1, icon: Icons.format_quote_outlined, label: 'Quote'),
            const SizedBox(width: 40), // Notch Space
            _buildBottomNavItem(
                context: context, index: 2, icon: Icons.support_agent_outlined, label: 'Support'), // Changed icon for Support
            _buildBottomNavItem(
                context: context, index: 3, icon: Icons.wysiwyg_outlined, label: 'Entries'),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    bool isSelected = _currentIndex == index;
    Color iconColor = isSelected ? theme.colorScheme.primary : theme.unselectedWidgetColor;
    return IconButton(
      tooltip: label,
      icon: Icon(icon, color: iconColor, size: 28),
      onPressed: () {
        if (_currentIndex != index && mounted) {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      splashColor: theme.colorScheme.primary.withOpacity(0.1),
      highlightColor: theme.colorScheme.primary.withOpacity(0.1),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: _toggleMenu,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      elevation: _isMenuOpen ? 0 : Theme.of(context).floatingActionButtonTheme.elevation ?? 6.0, // Hide shadow if menu is open
      child: RotationTransition(
        turns: _rotateAnimation,
        child: Icon(
          _isMenuOpen ? Icons.close : Icons.add,
          size: 32,
        ),
      ),
    );
  }
}
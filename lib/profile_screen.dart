import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; // Import Provider

// Import theme files
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart'; // For AppThemeType if needed directly

// Import the settings screen for navigation
import 'settings_screen.dart';

// --- Constants ---
// Most color constants are removed, rely on Theme and Provider
const double _profileCardRadius = 16.0;
const double _gridCardRadius = 20.0;
final Color _dangerColor = Colors.red.shade600; // Keep for Sign Out consistency
// --- REMOVED Specific Gradient Constants ---
// const Color _profileGradientStart = ...
// const Color _profileGradientEnd = ...
// const Gradient _profilePlaceholderGradient = ...
// --- End Constants ---


// Placeholder for Edit Profile Screen
class EditProfileScreen extends StatelessWidget { /* ... Placeholder ... */ final String currentName; const EditProfileScreen({Key? key, required this.currentName}) : super(key: key); @override Widget build(BuildContext context) { return Scaffold( appBar: AppBar(title: const Text("Edit Profile")), body: Center( child: Text("Edit screen for: $currentName \n(Implement saving logic here)"), ), ); } }


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State Variables (Keep all)
  String? _userName;
  String? _photoUrl;
  bool _isLoadingUserInfo = true;
  bool _isUploading = false;
  File? _imageFile;
  String _errorMessage = '';
  bool _isEditingName = false;
  late TextEditingController _nameEditingController;
  bool _isSavingName = false;

  // Firebase & Picker Instances (Keep all)
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); _nameEditingController = TextEditingController(); _fetchUserData(); }
  @override
  void dispose() { _nameEditingController.dispose(); super.dispose(); }

  // --- Data Fetching and Updating Logic (Keep as before) ---
  Future<void> _fetchUserData() async { /* ... Same ... */ if (!mounted) return; setState(() { _isLoadingUserInfo = true; _errorMessage = ''; _photoUrl = null; _imageFile = null; }); final user = _auth.currentUser; if (user == null) { if (mounted) setState(() { _userName = "Guest"; _isLoadingUserInfo = false; }); return; } try { final DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get(); if (userDoc.exists) { final data = userDoc.data() as Map<String, dynamic>?; if (data != null) { _userName = data['name'] as String?; _photoUrl = data['photoUrl'] as String?; _nameEditingController.text = _userName ?? ''; } else { _userName = null; _photoUrl = null; } } else { _userName = null; _photoUrl = null; } } catch (e, s) { print("[ProfileScreen] Error fetching: $e\n$s"); _errorMessage = "Could not load profile."; _userName=null; _photoUrl=null; } if (mounted) { setState(() { _isLoadingUserInfo = false; }); } }
  Future<void> _pickAndUploadImage() async { /* ... Same ... */ final user = _auth.currentUser; if (user == null) { return; } try { final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800); if (pickedFile == null) return; _imageFile = File(pickedFile.path); if (!mounted) return; setState(() { _isUploading = true; _errorMessage = ''; }); final String filePath = 'profile_pictures/${user.uid}.jpg'; final storageRef = _storage.ref().child(filePath); final uploadTask = storageRef.putFile(_imageFile!); final snapshot = await uploadTask.whenComplete(() => {}); final String downloadUrl = await snapshot.ref.getDownloadURL(); await _updateProfilePhotoUrl(downloadUrl); } catch (e, s) { print("[ProfileScreen] Error picking/uploading: $e\n$s"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image upload failed: ${e.toString()}"))); } finally { if (mounted) setState(() { _isUploading = false; _imageFile = null; }); } }
  Future<void> _updateProfilePhotoUrl(String? url) async { /* ... Same ... */ final user = _auth.currentUser; if (user == null) return; try { await _firestore.collection('users').doc(user.uid).set( {'photoUrl': url}, SetOptions(merge: true) ); if (mounted) { setState(() { _photoUrl = url; }); } } catch (e, s) { print("[ProfileScreen] Error updating Firestore photoUrl: $e\n$s"); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save photo reference."))); } }
  Future<void> _deleteProfilePhoto() async { /* ... Same ... */ final user = _auth.currentUser; if (user == null || (_photoUrl == null || _photoUrl!.isEmpty)) { if (_imageFile != null && mounted) setState(() => _imageFile = null); return; } if (_isUploading) return; if (!mounted) return; setState(() { _isLoadingUserInfo = true; _errorMessage = ''; }); try { final String filePath = 'profile_pictures/${user.uid}.jpg'; final storageRef = _storage.ref().child(filePath); try { await storageRef.delete(); } on FirebaseException catch (e) { if (e.code != 'object-not-found') { rethrow; } } await _updateProfilePhotoUrl(null); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("Profile photo removed.")) ); } } catch (e, s) { print("[ProfileScreen] Error deleting photo: $e\n$s"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Could not remove photo: ${e.toString()}")) ); } } finally { if (mounted) { setState(() { _isLoadingUserInfo = false; _imageFile = null; }); } } }
  Future<void> _updateUserName(String newName) async { /* ... Same ... */ if (newName.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name cannot be empty."))); return; } final user = _auth.currentUser; if (user == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You must be logged in."))); return; } if (!mounted) return; setState(() { _isSavingName = true; }); try { await _firestore.collection('users').doc(user.uid).set( {'name': newName}, SetOptions(merge: true) ); if (mounted) { setState(() { _userName = newName; _isEditingName = false; }); } } catch (e, s) { print("[ProfileScreen] Error updating name: $e\n$s"); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update name."))); } } finally { if (mounted) { setState(() { _isSavingName = false; }); } } }
  // --- End Data Logic ---


  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context); // Get theme data

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Use theme background
      body: Stack(
        children: [
          // Main Scrollable Content
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildProfilePhotoCard(context), // Uses theme gradient placeholder
              _buildUsername(context),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty) Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0), child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)), ),
              _buildProfileInfoCard(context),
              const SizedBox(height: 20),
              _buildInfoLinksCard(context),
              const SizedBox(height: 20),
              _buildBottomGrid(context), // Uses theme gradient for rate card
              const SizedBox(height: 40),
            ],
          ),
          // Positioned Top Icons Card
          _buildTopIconsCard(context, topPadding),
        ],
      ),
    );
  }

  // --- Build Helpers (Using Theme) ---

  Widget _buildTopIconsCard(BuildContext context, double topPadding) { /* ... Same (uses theme) ... */ final theme = Theme.of(context); return Positioned( top: topPadding + 10, right: 16, child: Card( elevation: 2.0, color: theme.cardColor.withOpacity(0.85), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: Row( children: [ IconButton( icon: Icon(Icons.tune, color: theme.colorScheme.onSurface.withOpacity(0.8), size: 20), tooltip: "Settings", onPressed: () { Navigator.push( context, MaterialPageRoute(builder: (context) => const SettingsScreen()), ); }, constraints: const BoxConstraints(), padding: const EdgeInsets.all(6), ), const SizedBox(width: 4), IconButton( icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.8), size: 20), tooltip: "Close", onPressed: () { if (Navigator.canPop(context)) { Navigator.pop(context); } }, constraints: const BoxConstraints(), padding: const EdgeInsets.all(6), ), ], ), ), ), ); }

  // --- UPDATED: Profile Photo Card uses Theme Gradient for Placeholder ---
  Widget _buildProfilePhotoCard(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardSize = screenWidth * 0.45;
    bool hasPhotoUrl = (_photoUrl != null && _photoUrl!.isNotEmpty);
    bool displayPhoto = (_imageFile != null || hasPhotoUrl);
    ImageProvider? imageProvider;
    if (_imageFile != null) { imageProvider = FileImage(_imageFile!); }
    else if (hasPhotoUrl) { imageProvider = CachedNetworkImageProvider(_photoUrl!); }

    // Get current gradient from ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false); // Use listen:false if only needed once
    final Gradient currentPlaceholderGradient = LinearGradient(
        colors: themeProvider.currentAccentGradient, // Use gradient from provider
        begin: Alignment.topLeft, end: Alignment.bottomRight // Match gradient style
    );

    return Container( padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60), alignment: Alignment.center,
      child: SizedBox( width: cardSize, height: cardSize, child: Material(
        elevation: 4.0, borderRadius: BorderRadius.circular(_profileCardRadius),
        shadowColor: Theme.of(context).shadowColor,
        child: ClipRRect( borderRadius: BorderRadius.circular(_profileCardRadius),
          child: GestureDetector( onTap: _isUploading ? null : _pickAndUploadImage,
            child: Stack( fit: StackFit.expand, children: [
              // Layer 1: Background (Theme Gradient Placeholder OR Image)
              if (imageProvider != null)
                Image( image: imageProvider, fit: BoxFit.cover, /* ... loading/error ... */ )
              else
                Container( // Use current theme's gradient as placeholder BG
                  decoration: BoxDecoration( gradient: currentPlaceholderGradient, ),
                  child: Icon( Icons.add_a_photo_outlined, color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7), size: cardSize * 0.4), ), // Use theme contrast color for icon
              // Layer 2: Uploading Indicator
              if (_isUploading) Container( color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator(color: Colors.white)), ),
              // Layer 3: Delete Button
              if (displayPhoto && !_isUploading)
                Positioned( top: 4, right: 4, child: Material( color: Colors.black.withOpacity(0.4), shape: const CircleBorder(), child: InkWell( onTap: _deleteProfilePhoto, borderRadius: BorderRadius.circular(15), child: const Padding( padding: EdgeInsets.all(5.0), child: Icon(Icons.delete_outline, color: Colors.white70, size: 18), ), ), ) ),
            ], ), ), ), ), ), );
  }
  // --- End Update ---

  Widget _buildUsername(BuildContext context) { /* ... Same (uses theme) ... */ return Padding( padding: const EdgeInsets.only(left: 25.0, top: 25.0, right: 25.0), child: AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child), child: _isLoadingUserInfo ? Align( key: const ValueKey('loading_name_display'), alignment: Alignment.centerLeft, child: SizedBox( width: 100, height: 24, child: LinearProgressIndicator(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), backgroundColor: Theme.of(context).hoverColor)) ) : Align( key: ValueKey(_userName ?? 'default_user_display'), alignment: Alignment.centerLeft, child: Text( _userName ?? "User", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), ), ); }

  // Editable Profile Info Card (Uses theme)
  Widget _buildProfileInfoCard(BuildContext context) { /* ... Same (uses theme) ... */ final theme = Theme.of(context); final colorScheme = theme.colorScheme; return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Padding( padding: const EdgeInsets.only(left: 20.0, right: 10.0, top: 10.0, bottom: 10.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [ Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text( "Nickname", style: TextStyle( fontSize: 10, fontWeight: FontWeight.w500,  letterSpacing: 0.5, ), ), const SizedBox(height: 4), _isEditingName ? SizedBox( height: 35, child: TextField( controller: _nameEditingController, autofocus: true, style: theme.textTheme.titleMedium, decoration: InputDecoration( isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 4), border: const UnderlineInputBorder(), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)), ), textCapitalization: TextCapitalization.words, onSubmitted: (newName) => _updateUserName(newName), ), ) : (_isLoadingUserInfo && _userName == null) ? SizedBox(key: const ValueKey("name_loading_edit"), height: 18, width: 80, child: LinearProgressIndicator(color: colorScheme.primary.withOpacity(0.5), backgroundColor: theme.hoverColor)) : Text( key: ValueKey(_userName ?? "name_display_edit"), _userName ?? "Not Set", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, ), ], ), ), _isEditingName ? Row( mainAxisSize: MainAxisSize.min, children: [ IconButton( icon: Icon(Icons.cancel_outlined, color: theme.unselectedWidgetColor, size: 22), tooltip: "Cancel", onPressed: () { if(mounted) setState(() { _isEditingName = false; _nameEditingController.text = _userName ?? ''; }); }, ), IconButton( icon: _isSavingName ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)) : Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 22), tooltip: "Save", onPressed: _isSavingName ? null : () => _updateUserName(_nameEditingController.text), ), ] ) : IconButton( icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 22), tooltip: "Edit Name", onPressed: () { if(mounted) setState(() { _isEditingName = true; _nameEditingController.text = _userName ?? ''; }); }, ), ], ), ), ), ); }

  // Info Links Card (Uses Theme)
  Widget _buildInfoLinksCard(BuildContext context) { /* ... Same (uses theme) ... */ final theme = Theme.of(context); return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Card( child: Column( children: [ _buildInfoLinkRow( context, icon: Icons.badge_outlined, text: "Copy purchase ID", onTap: () { print("Copy ID tapped"); }, ), Divider(height: 1, thickness: 1, indent: 20, endIndent: 20, color: theme.dividerColor), _buildInfoLinkRow( context, icon: Icons.history, text: "Restore purchases", onTap: () { print("Restore tapped"); }, ), ], ), ), ); }
  Widget _buildInfoLinkRow(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) { /* ... Same (uses theme) ... */ final theme = Theme.of(context); final Color iconColor = theme.colorScheme.onSurface.withOpacity(0.6); return InkWell( onTap: onTap, child: Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0), child: Row( children: [ Icon(icon, color: iconColor, size: 22), const SizedBox(width: 15), Expanded( child: Text( text, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface) ) ), Icon(Icons.arrow_forward_ios, color: iconColor, size: 16), ], ), ), ); }

  // --- UPDATED: Bottom Grid uses Theme Gradient for "Rate" card ---
  Widget _buildBottomGrid(BuildContext context) {
    final theme = Theme.of(context);
    // Get current gradient from ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Gradient currentAccentGradient = LinearGradient( // Use provider gradient
        colors: themeProvider.currentAccentGradient,
        begin: Alignment.topLeft, end: Alignment.bottomRight );
    final Color currentAccent = themeProvider.currentAccentColor; // Get accent color

    return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Row( children: [
      Expanded( child: Card( clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_gridCardRadius)), elevation: 3,
        child: Container( height: 150, padding: const EdgeInsets.all(15),
          decoration: BoxDecoration( gradient: currentAccentGradient, ), // Use current theme's gradient
          child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(Icons.star_border, color: theme.colorScheme.onPrimary, size: 28), // Use theme contrast color
            Text("Rate App 5-stars", style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 15, fontWeight: FontWeight.w500)) // Use theme contrast color
          ] ), ), ), ),
      const SizedBox(width: 15),
      Expanded( child: Card( clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_gridCardRadius)), elevation: 3,
        child: Container( height: 150, padding: const EdgeInsets.all(15), color: theme.cardColor,
          child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(Icons.chat_bubble_outline, color: currentAccent, size: 28), // Use theme accent color
            Text("Contact support", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w500))
          ] ), ), ), ),
    ], ), );
  }
// --- End Update ---

// --- REMOVED Sign Out Card Builder ---

} // End _ProfileScreenState
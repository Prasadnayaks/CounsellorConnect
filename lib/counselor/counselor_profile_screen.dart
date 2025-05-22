import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

// Import theme files
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart'; // For AppThemeType

// Import other relevant screens
import '../settings_screen.dart';
import './manage_availability_screen.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _profileCardRadius = 16.0;
const double _infoCardRadius = 12.0;
const double _gridCardRadius = 20.0;
const double _sectionCardRadius = 12.0;
final Color _dangerColor = Colors.red.shade600;
// --- End Constants ---

class CounselorProfileScreen extends StatefulWidget {
  const CounselorProfileScreen({Key? key}) : super(key: key);
  @override
  _CounselorProfileScreenState createState() => _CounselorProfileScreenState();
}

class _CounselorProfileScreenState extends State<CounselorProfileScreen> {
  String? _displayName;
  String? _displayPhotoUrl;
  bool _isLoadingData = true;
  bool _isUploadingPhoto = false;
  File? _imageFile;
  String _errorMessage = '';

  bool _isEditingName = false;
  late TextEditingController _nameEditingController;
  bool _isSavingName = false;

  String? _specialization;
  String? _description;
  bool _isEditingSpecialization = false;
  late TextEditingController _specializationController;
  bool _isSavingSpecialization = false;
  bool _isEditingDescription = false;
  late TextEditingController _descriptionController;
  bool _isSavingDescription = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? get _currentUser => _auth.currentUser; // Helper getter

  @override
  void initState() {
    super.initState();
    _nameEditingController = TextEditingController();
    _specializationController = TextEditingController();
    _descriptionController = TextEditingController();
    _fetchCounselorAndUserData();
  }

  @override
  void dispose() {
    _nameEditingController.dispose();
    _specializationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCounselorAndUserData() async {
    if (!mounted) return;
    setState(() { _isLoadingData = true; _errorMessage = ''; _displayPhotoUrl = null; _imageFile = null;});

    final user = _currentUser; // Use the getter
    if (user == null) {
      if (mounted) setState(() { _displayName = "Guest"; _isLoadingData = false; });
      return;
    }
    final String currentUserId = user.uid; // Define uid once from user object

    String? fetchedName;
    String? fetchedPhotoUrl;
    String? fetchedSpecialization;
    String? fetchedDescription;

    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUserId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          fetchedName = data['name'] as String?;
          fetchedPhotoUrl = data['photoUrl'] as String?;
        }
      }

      DocumentSnapshot counselorDoc = await _firestore.collection('counselors').doc(currentUserId).get();
      if (counselorDoc.exists) {
        final data = counselorDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          fetchedName = data['name'] as String? ?? fetchedName; // Prioritize counselor name
          fetchedPhotoUrl = data['photoUrl'] as String? ?? fetchedPhotoUrl; // Prioritize counselor photo
          fetchedSpecialization = data['specialization'] as String?;
          fetchedDescription = data['description'] as String?;
        }
      }

      if (mounted) {
        setState(() {
          _displayName = fetchedName;
          _displayPhotoUrl = fetchedPhotoUrl;
          _specialization = fetchedSpecialization;
          _description = fetchedDescription;
          _nameEditingController.text = _displayName ?? '';
          _specializationController.text = _specialization ?? '';
          _descriptionController.text = _description ?? '';
        });
      }
    } catch (e, s) {
      print("[CounselorProfile] Error fetching data: $e\n$s");
      _errorMessage = "Could not load profile details.";
    }
    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Authentication error.")));
      return;
    }
    final String currentUserId = user.uid;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
      if (pickedFile == null) return;
      _imageFile = File(pickedFile.path);
      if (!mounted) return;
      setState(() { _isUploadingPhoto = true; _errorMessage = ''; });

      final String filePath = 'counselor_profile_pictures/$currentUserId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child(filePath);
      final uploadTask = storageRef.putFile(_imageFile!);
      final snapshot = await uploadTask.whenComplete(() => {});
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _updateProfilePhotoUrlInFirestore(downloadUrl, currentUserId); // Pass currentUserId

    } catch (e, s) {
      print("[CounselorProfile] Error picking/uploading: $e\n$s");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image upload failed: ${e.toString()}")));
    } finally {
      if (mounted) setState(() { _isUploadingPhoto = false; _imageFile = null; });
    }
  }

  Future<void> _updateProfilePhotoUrlInFirestore(String? url, String userIdToUpdate) async { // Takes userIdToUpdate
    try {
      await _firestore.collection('counselors').doc(userIdToUpdate).set(
          {'photoUrl': url, 'lastUpdated': FieldValue.serverTimestamp()},
          SetOptions(merge: true)
      );
      await _firestore.collection('users').doc(userIdToUpdate).set(
          {'photoUrl': url}, // Also update the general user profile photo
          SetOptions(merge: true)
      );
      if (mounted) {
        setState(() { _displayPhotoUrl = url; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile photo updated.")));
      }
    } catch (e, s) {
      print("[CounselorProfile] Error updating Firestore photoUrl: $e\n$s");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save photo reference.")));
    }
  }

  Future<void> _deleteProfilePhoto() async {
    final user = _currentUser;
    if (user == null || (_displayPhotoUrl == null || _displayPhotoUrl!.isEmpty)) {
      if (_imageFile != null && mounted) setState(() => _imageFile = null);
      return;
    }
    if (_isUploadingPhoto) return;
    if (!mounted) return;
    setState(() { _isLoadingData = true; _errorMessage = ''; }); // Use _isLoadingData for general loading
    final String currentUserId = user.uid;

    try {
      // Note: Deleting from Firebase Storage requires knowing the exact file path.
      // If you only store the download URL, you can't easily reconstruct the storage path
      // unless you have a consistent naming convention AND you didn't add unique IDs (like timestamp) to the path.
      // For simplicity, this example focuses on clearing the URL in Firestore.
      // To delete from storage, you'd need to store 'filePath' in Firestore when uploading.
      // Example: final String oldFilePath = 'counselor_profile_pictures/$currentUserId/your_stored_file_name.jpg';
      // try { await _storage.ref().child(oldFilePath).delete(); } catch (e) { print("Error deleting old file from storage: $e"); }

      await _updateProfilePhotoUrlInFirestore(null, currentUserId); // Sets photoUrl to null in Firestore
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile photo removed.")));
      }
    } catch (e, s) {
      print("[CounselorProfile] Error deleting photo: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not remove photo: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() { _isLoadingData = false; _imageFile = null; });
      }
    }
  }

  Future<void> _updateUserName(String newName) async {
    if (newName.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name cannot be empty."))); return; }
    final user = _currentUser;
    if (user == null) { return; }
    final String currentUserId = user.uid;

    if (!mounted) return; setState(() { _isSavingName = true; });
    try {
      await _firestore.collection('counselors').doc(currentUserId).set(
          {'name': newName.trim(), 'lastUpdated': FieldValue.serverTimestamp()},
          SetOptions(merge: true)
      );
      await _firestore.collection('users').doc(currentUserId).set(
          {'name': newName.trim()},
          SetOptions(merge: true)
      );
      if (mounted) { setState(() { _displayName = newName.trim(); _isEditingName = false; }); }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name updated successfully.")));
    } catch (e, s) {
      print("[CounselorProfile] Error updating name: $e\n$s");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update name."))); }
    } finally {
      if (mounted) { setState(() { _isSavingName = false; }); }
    }
  }

  Future<void> _updateCounselorProfessionalField(
      String fieldKey, String newValue,
      TextEditingController controller, // Pass controller to reset if needed
      Function(bool) setSavingFlag,
      Function(String?) updateLocalState,
      Function(bool) setEditingFlag
      ) async {
    if (newValue.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${fieldKey[0].toUpperCase()}${fieldKey.substring(1)} cannot be empty.")));
      return;
    }
    final user = _currentUser;
    if (user == null) return;
    final String currentUserId = user.uid;

    if (!mounted) return; setSavingFlag(true);

    try {
      await _firestore.collection('counselors').doc(currentUserId).set(
          {fieldKey: newValue.trim(), 'lastUpdated': FieldValue.serverTimestamp()},
          SetOptions(merge: true)
      );
      if (mounted) {
        updateLocalState(newValue.trim());
        setEditingFlag(false); // This will turn off the editing mode for the specific field
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${fieldKey[0].toUpperCase()}${fieldKey.substring(1)} updated.")));
      }
    } catch (e,s) {
      print("[CounselorProfile] Error updating $fieldKey: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update $fieldKey.")));
      }
    } finally {
      if (mounted) setSavingFlag(false);
    }
  }

  Future<void> _logoutUser(BuildContext context) async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
    } catch (e) {
      print("[CounselorProfile] Error logging out: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error logging out.")));
      }
    }
  }

  Widget _buildInfoLinkRow(BuildContext context, {required IconData icon, required String text, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final Color iconColor = theme.colorScheme.onSurface.withOpacity(0.6);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 15),
            Expanded(
                child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontFamily: _primaryFontFamily
                    )
                )
            ),
            Icon(Icons.arrow_forward_ios, color: iconColor, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: theme.brightness == Brightness.light ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: theme.brightness == Brightness.light ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildProfilePhotoCard(context),
              _buildUsername(context),

              _buildEditableCardRow(context, label: "Nickname",
                  currentValue: _displayName,
                  isEditing: _isEditingName,
                  isLoading: _isLoadingData && _displayName == null,
                  controller: _nameEditingController,
                  onEdit: () => setState(() {
                    _isEditingName = true;
                    _nameEditingController.text = _displayName ?? '';
                    // Turn off other edit modes
                    _isEditingSpecialization = false;
                    _isEditingDescription = false;
                  }),
                  onSave: () => _updateUserName(_nameEditingController.text),
                  onCancel: () => setState(() {
                    _isEditingName = false;
                    _nameEditingController.text = _displayName ?? '';
                  }),
                  isSaving: _isSavingName,
                  hintText: "Your display name"
              ),

              _buildEditableCardRow(context, label: "Specialization",
                  currentValue: _specialization,
                  isEditing: _isEditingSpecialization,
                  isLoading: _isLoadingData && _specialization == null,
                  controller: _specializationController,
                  onEdit: () => setState(() {
                    _isEditingSpecialization = true;
                    _specializationController.text = _specialization ?? '';
                    _isEditingName = false;
                    _isEditingDescription = false;
                  }),
                  onSave: () => _updateCounselorProfessionalField('specialization', _specializationController.text, _specializationController, (val) => setState(()=>_isSavingSpecialization=val), (val) => setState(()=>_specialization=val), (val) => setState(()=>_isEditingSpecialization=val)),
                  onCancel: () => setState(() {
                    _isEditingSpecialization = false;
                    _specializationController.text = _specialization ?? '';
                  }),
                  isSaving: _isSavingSpecialization,
                  hintText: "e.g., Child Psychology, CBT"
              ),
              _buildEditableCardRow(context, label: "About Me / Description",
                  currentValue: _description,
                  isEditing: _isEditingDescription,
                  isLoading: _isLoadingData && _description == null,
                  controller: _descriptionController,
                  onEdit: () => setState(() {
                    _isEditingDescription = true;
                    _descriptionController.text = _description ?? '';
                    _isEditingName = false;
                    _isEditingSpecialization = false;
                  }),
                  onSave: () => _updateCounselorProfessionalField('description', _descriptionController.text, _descriptionController, (val) => setState(()=>_isSavingDescription=val), (val) => setState(()=>_description=val), (val) => setState(()=>_isEditingDescription=val)),
                  onCancel: () => setState(() {
                    _isEditingDescription = false;
                    _descriptionController.text = _description ?? '';
                  }),
                  isSaving: _isSavingDescription,
                  maxLines: 5,
                  hintText: "Share your experience and approach..."
              ),

              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                ),

              _buildCounselorSpecificLinksCard(context),
              _buildInfoLinksCard(context),
              const SizedBox(height: 20),
              _buildBottomGrid(context),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: Icon(Icons.logout_rounded, color: _dangerColor),
                    label: Text("Sign Out", style: TextStyle(color: _dangerColor, fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () => _logoutUser(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_infoCardRadius)),
                      backgroundColor: theme.cardColor,
                      elevation: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
          _buildTopIconsCard(context, topPadding),
        ],
      ),
    );
  }

  Widget _buildEditableCardRow(BuildContext context, {
    required String label,
    required String? currentValue,
    required bool isEditing,
    required bool isLoading,
    required TextEditingController controller,
    required VoidCallback onEdit,
    required Future<void> Function() onSave,
    required VoidCallback onCancel,
    required bool isSaving,
    int maxLines = 1,
    String hintText = "Not Set"
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Card(
        elevation: 1.0,
        shadowColor: theme.shadowColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_infoCardRadius)),
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 10.0, top: 10.0, bottom: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        fontFamily: _primaryFontFamily,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    isEditing
                        ? SizedBox(
                      // height: maxLines > 1 ? null : 35, // Commented out fixed height for TextField
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        style: theme.textTheme.titleMedium?.copyWith(fontFamily: _primaryFontFamily),
                        maxLines: maxLines,
                        textCapitalization: label == "Nickname" || label == "Display Name" ? TextCapitalization.words : TextCapitalization.sentences,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          border: const UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                          hintText: controller.text.isEmpty ? hintText : null,
                        ),
                        onSubmitted: maxLines == 1 ? (_) => onSave() : null,
                      ),
                    )
                        : (isLoading)
                        ? SizedBox(key: ValueKey("${label.replaceAll(" ", "")}_loading_edit"), height: 18, width: 80, child: LinearProgressIndicator(color: colorScheme.primary.withOpacity(0.5), backgroundColor: theme.hoverColor))
                        : Text(
                      key: ValueKey(currentValue ?? "${label.replaceAll(" ", "")}_display_edit"),
                      currentValue ?? hintText,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              isEditing
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.cancel_outlined, color: theme.unselectedWidgetColor, size: 22),
                    tooltip: "Cancel",
                    onPressed: onCancel,
                  ),
                  IconButton(
                    icon: isSaving
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                        : Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 22),
                    tooltip: "Save",
                    onPressed: isSaving ? null : onSave,
                  ),
                ],
              )
                  : IconButton(
                icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 22),
                tooltip: "Edit $label",
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsername(BuildContext context) { return Padding( padding: const EdgeInsets.only(left: 25.0, top: 25.0, right: 25.0, bottom: 0), child: AnimatedSwitcher( duration: const Duration(milliseconds: 300), transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child), child: _isLoadingData ? Align( key: const ValueKey('loading_name_display'), alignment: Alignment.centerLeft, child: SizedBox( width: 100, height: 24, child: LinearProgressIndicator(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), backgroundColor: Theme.of(context).hoverColor)) ) : Align( key: ValueKey(_displayName ?? 'default_user_display'), alignment: Alignment.centerLeft, child: Text( _displayName ?? "Counselor", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily), maxLines: 1, overflow: TextOverflow.ellipsis, ), ), ), ); }
  Widget _buildTopIconsCard(BuildContext context, double topPadding) { final theme = Theme.of(context); return Positioned( top: topPadding + 10, right: 16, child: Card( elevation: 2.0, color: theme.cardColor.withOpacity(0.85), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: Row( children: [ IconButton( icon: Icon(Icons.tune, color: theme.colorScheme.onSurface.withOpacity(0.8), size: 20), tooltip: "Settings", onPressed: () { Navigator.push( context, MaterialPageRoute(builder: (context) => const SettingsScreen()), ); }, constraints: const BoxConstraints(), padding: const EdgeInsets.all(6), ), const SizedBox(width: 4), IconButton( icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.8), size: 20), tooltip: "Close Profile", onPressed: () { if (Navigator.canPop(context)) { Navigator.pop(context); } }, constraints: const BoxConstraints(), padding: const EdgeInsets.all(6), ), ], ), ), ), ); }
  Widget _buildProfilePhotoCard(BuildContext context) { final screenWidth = MediaQuery.of(context).size.width; final cardSize = screenWidth * 0.45; bool hasPhotoUrl = (_displayPhotoUrl != null && _displayPhotoUrl!.isNotEmpty); bool displayPhoto = (_imageFile != null || hasPhotoUrl); ImageProvider? imageProvider; if (_imageFile != null) { imageProvider = FileImage(_imageFile!); } else if (hasPhotoUrl) { imageProvider = CachedNetworkImageProvider(_displayPhotoUrl!); } final themeProvider = Provider.of<ThemeProvider>(context, listen: false); final Gradient currentPlaceholderGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight ); final Brightness currentBrightness = Theme.of(context).brightness; final Color onGradientColor = currentBrightness == Brightness.light ? Colors.black54 : Colors.white70; return Container( padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60, bottom:10), alignment: Alignment.center, child: SizedBox( width: cardSize, height: cardSize, child: Material( elevation: 4.0, borderRadius: BorderRadius.circular(_profileCardRadius), shadowColor: Theme.of(context).shadowColor, child: ClipRRect( borderRadius: BorderRadius.circular(_profileCardRadius), child: GestureDetector( onTap: _isUploadingPhoto ? null : _pickAndUploadImage, child: Stack( fit: StackFit.expand, children: [ if (imageProvider != null) Image( image: imageProvider, fit: BoxFit.cover, loadingBuilder:(context, child, loadingProgress) { if (loadingProgress == null) return child; return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null ));}, errorBuilder: (context, error, stackTrace) => Container(decoration: BoxDecoration(gradient: currentPlaceholderGradient), child: Icon(Icons.broken_image_outlined, color: onGradientColor, size: cardSize * 0.4)),) else Container( decoration: BoxDecoration( gradient: currentPlaceholderGradient, ), child: Icon( Icons.add_a_photo_outlined, color: onGradientColor, size: cardSize * 0.4), ), if (_isUploadingPhoto) Container( color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator(color: Colors.white)), ), if (displayPhoto && !_isUploadingPhoto) Positioned( top: 4, right: 4, child: Material( color: Colors.black.withOpacity(0.4), shape: const CircleBorder(), child: InkWell( onTap: _deleteProfilePhoto, borderRadius: BorderRadius.circular(15), child: const Padding( padding: EdgeInsets.all(5.0), child: Icon(Icons.delete_outline, color: Colors.white70, size: 18), ), ), ) ), ], ), ), ), ), ), );}

  Widget _buildCounselorSpecificLinksCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Card(
        elevation: 1.0,
        shadowColor: theme.shadowColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_infoCardRadius)),
        child: Column(
          children: [
            _buildInfoLinkRow(
              context,
              icon: Icons.event_note_outlined,
              text: "Manage Weekly Availability",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAvailabilityScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLinksCard(BuildContext context) { final theme = Theme.of(context); return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0), child: Card( elevation: 1.0, shadowColor: theme.shadowColor.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_infoCardRadius)), child: Column( children: [ _buildInfoLinkRow( context, icon: Icons.badge_outlined, text: "Copy purchase ID", onTap: () { print("Copy ID tapped"); }, ), Divider(height: 1, thickness: 1, indent: 20, endIndent: 20, color: theme.dividerColor), _buildInfoLinkRow( context, icon: Icons.history, text: "Restore purchases", onTap: () { print("Restore tapped"); }, ), ], ), ), ); }
  Widget _buildBottomGrid(BuildContext context) { final theme = Theme.of(context); final themeProvider = Provider.of<ThemeProvider>(context, listen: false); final Gradient currentAccentGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight ); final Color currentAccent = themeProvider.currentAccentColor; return Padding( padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0), child: Row( children: [ Expanded( child: Card( clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_gridCardRadius)), elevation: 3, child: Container( height: 150, padding: const EdgeInsets.all(15), decoration: BoxDecoration( gradient: currentAccentGradient, ), child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Icon(Icons.star_border_rounded, color: theme.colorScheme.onPrimary, size: 28), Text("Rate App 5-stars", style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 15, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily)) ] ), ), ), ), const SizedBox(width: 15), Expanded( child: Card( clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_gridCardRadius)), elevation: 3, child: Container( height: 150, padding: const EdgeInsets.all(15), color: theme.cardColor, child: Column( crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Icon(Icons.chat_bubble_outline_rounded, color: currentAccent, size: 28), Text("Contact Support", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w500, fontFamily: _primaryFontFamily)) ] ), ), ), ), ], ), ); }

}
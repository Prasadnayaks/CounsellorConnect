// lib/truth_screen.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Make sure intl is imported
import 'package:provider/provider.dart';

import 'theme/theme_provider.dart';
import 'widgets/bouncing_widget.dart';

const String _fontFamily = 'Nunito';

class DailyThemePrompt {
  final String theme;
  final String promptPrefix;
  final String promptSuffix;

  DailyThemePrompt(
      {required this.theme,
        required this.promptPrefix,
        this.promptSuffix = ""});
}

class TruthScreen extends StatefulWidget {
  const TruthScreen({Key? key}) : super(key: key);

  @override
  State<TruthScreen> createState() => _TruthScreenState();
}

class _TruthScreenState extends State<TruthScreen> {
  final TextEditingController _reflectionController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  String? _uploadedImageUrl;
  bool _isButtonEnabled = false;

  late DailyThemePrompt _currentThemePrompt;
  late DateTime _currentDate;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final FocusNode _reflectionFocusNode = FocusNode();
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _currentThemePrompt = _getDailyThemePrompt(_currentDate);
    _reflectionController.addListener(_updateButtonState);
    _reflectionFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isKeyboardVisible = _reflectionFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _reflectionController.removeListener(_updateButtonState);
    _reflectionController.dispose();
    _reflectionFocusNode.removeListener(_onFocusChange);
    _reflectionFocusNode.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    if (mounted) {
      setState(() {
        _isButtonEnabled =
            _reflectionController.text.trim().isNotEmpty || _imageFile != null;
      });
    }
  }

  DailyThemePrompt _getDailyThemePrompt(DateTime date) {
    int weekday = date.weekday;
    switch (weekday) {
      case DateTime.monday:
        return DailyThemePrompt(
            theme: "Mindfulness",
            promptPrefix:
            "Today, I found a moment of peace when I noticed _________",
            promptSuffix: ".");
      case DateTime.tuesday:
        return DailyThemePrompt(
            theme: "Truth",
            promptPrefix:
            "A truth about myself I'm embracing is that I am _________",
            promptSuffix: ".");
      case DateTime.wednesday:
        return DailyThemePrompt(
            theme: "Wisdom",
            promptPrefix:
            "If I could tell my younger self one thing, it would be to _________",
            promptSuffix: ".");
      case DateTime.thursday:
        return DailyThemePrompt(
            theme: "Identity",
            promptPrefix:
            "I express my unique identity most clearly when I _________",
            promptSuffix: ".");
      case DateTime.friday:
        return DailyThemePrompt(
            theme: "Favorites",
            promptPrefix: "My favorite small joy this week has been _________",
            promptSuffix: ".");
      case DateTime.saturday:
        return DailyThemePrompt(
            theme: "Celebration",
            promptPrefix: "I celebrate my progress in _________",
            promptSuffix: ", no matter how small.");
      case DateTime.sunday:
        return DailyThemePrompt(
            theme: "Gratitude",
            promptPrefix:
            "I am deeply grateful for the simple gift of _________",
            promptSuffix: " today.");
      default:
        return DailyThemePrompt(
            theme: "Reflection",
            promptPrefix: "Today, I reflected on _________",
            promptSuffix: ".");
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70, maxWidth: 1024);
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _uploadedImageUrl = null;
        });
        _updateButtonState();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error picking image: ${e.toString()}")),
        );
      }
    }
  }

  void _removeImage() {
    if (mounted) {
      setState(() {
        _imageFile = null;
        _uploadedImageUrl = null;
      });
      _updateButtonState();
    }
  }

  Future<String?> _uploadImage(File image, String userId) async {
    setStateIfMounted(() => _isSaving = true); // Indicate loading for image upload
    try {
      String fileName =
          'truthReflections/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child(fileName);
      UploadTask uploadTask = storageRef.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image: ${e.toString()}")),
        );
      }
      return null;
    } finally {
      // Important: Don't set _isSaving to false here if _saveReflection will continue
      // setStateIfMounted(() => _isSaving = false); // This might be premature
    }
  }

  void setStateIfMounted(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _saveReflection() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You need to be logged in to save reflections.")),
      );
      return;
    }

    if (_reflectionController.text.trim().isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please write your reflection or add a photo.")),
      );
      return;
    }

    setStateIfMounted(() => _isSaving = true); // Set saving state for the whole operation

    String? finalImageUrl = _uploadedImageUrl; // Use already uploaded URL if available
    if (_imageFile != null && finalImageUrl == null) { // Only upload if new image and not yet uploaded
      finalImageUrl = await _uploadImage(_imageFile!, currentUser.uid);
      if (finalImageUrl == null && _imageFile != null) {
        // Error occurred during image upload
        setStateIfMounted(() => _isSaving = false); // Reset saving state
        return; // Stop the save process
      }
    }

    // Construct the specific document ID
    String formattedDate = DateFormat('yyyy-MM-dd').format(_currentDate);
    String truthDocId = '${_currentThemePrompt.theme.toLowerCase()}_$formattedDate';

    final reflectionData = {
      'userId': currentUser.uid,
      'dayTheme': _currentThemePrompt.theme,
      'prompt':
      "${_currentThemePrompt.promptPrefix} ____ ${_currentThemePrompt.promptSuffix}",
      'reflectionText': _reflectionController.text.trim(),
      'imageUrl': finalImageUrl, // This can be null if no image
      'entryDateTime': Timestamp.fromDate(_currentDate),
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };

    try {
      // Use .doc(truthDocId).set() to save with a specific ID
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('truthReflections')
          .doc(truthDocId) // Use the specific document ID
          .set(reflectionData, SetOptions(merge: true)); // Use .set() and merge

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reflection saved successfully!")),
        );
        Navigator.of(context).pop(); // Go back after saving
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save reflection: ${e.toString()}")),
        );
      }
    } finally {
      // This ensures _isSaving is set to false regardless of success or failure of Firestore operation
      setStateIfMounted(() => _isSaving = false);
    }
  }


  List<BoxShadow> _getCardBoxShadow(BuildContext context) {
    final theme = Theme.of(context);
    return [
      BoxShadow(
        color: theme.shadowColor
            .withOpacity(theme.brightness == Brightness.dark ? 0.15 : 0.08),
        blurRadius: 12.0,
        spreadRadius: 1.0,
        offset: const Offset(0, 4.0),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String formattedDate =
    DateFormat('EEEE, MMMM d').format(_currentDate).toUpperCase();

    final Color appBarContentColor =
    theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87;
    final Color subtitleColor =
    theme.brightness == Brightness.dark ? Colors.white60 : Colors.black54;
    final Color closeButtonBgColor = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.1)
        : const Color(0xFFF0F3F7);

    double bottomSheetHeightEstimate = 90.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: theme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        title: Column(
          children: [
            Text(
              _currentThemePrompt.theme,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: appBarContentColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              formattedDate,
              style: TextStyle(
                fontFamily: _fontFamily,
                color: subtitleColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: closeButtonBgColor,
                    shape: BoxShape.circle,
                  ),
                  child:
                  Icon(Icons.close, color: appBarContentColor, size: 22),
                )),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20.0, 0, 20.0, bottomSheetHeightEstimate + MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 20,
                          color: theme.textTheme.bodyLarge?.color,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                              text: _currentThemePrompt.promptPrefix + " "),
                        ],
                      ),
                    ),
                    if (_currentThemePrompt.promptSuffix.isNotEmpty)
                      Text(
                        _currentThemePrompt.promptSuffix,
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 20,
                          color: theme.textTheme.bodyLarge?.color,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: _getCardBoxShadow(context),
                      ),
                      child: TextField(
                        focusNode: _reflectionFocusNode,
                        controller: _reflectionController,
                        maxLines: 8,
                        minLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                            fontFamily: _fontFamily,
                            fontSize: 16,
                            color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: "Share your thoughts here...",
                          hintStyle: TextStyle(
                              color: theme.hintColor,
                              fontFamily: _fontFamily,
                              fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    if (_imageFile == null)
                      BouncingWidget(
                        onPressed: _pickImage,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.add_a_photo_outlined,
                              color: colorScheme.primary),
                          label: Text(
                            "Add Photo",
                            style: TextStyle(
                                fontFamily: _fontFamily,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                          onPressed: null, // Handled by BouncingWidget
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: colorScheme.primary.withOpacity(0.7)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0)),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Attached Photo:",
                              style: TextStyle(
                                  fontFamily: _fontFamily,
                                  fontSize: 14,
                                  color: theme.textTheme.bodySmall?.color,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12.0),
                                    boxShadow: _getCardBoxShadow(context),
                                    image: DecorationImage(
                                        image: FileImage(_imageFile!),
                                        fit: BoxFit.cover)),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: BouncingWidget(
                                  onPressed: _removeImage,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (_isKeyboardVisible) // "Done" button for keyboard
              Positioned(
                bottom: MediaQuery.of(context).viewInsets.bottom + 10, // Position above keyboard
                right: 20,
                child: FloatingActionButton.small(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                  },
                  backgroundColor: theme.cardColor,
                  foregroundColor: colorScheme.primary,
                  elevation: 4.0,
                  tooltip: 'Done Editing',
                  child: const Icon(Icons.check, size: 24),
                ),
              ),
          ],
        ),
      ),
      bottomSheet: Container(
        color: theme.scaffoldBackgroundColor,
        padding: EdgeInsets.only(
            left: 60,
            right: 60,
            top: 15,
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + 5
                : 20),
        child: BouncingWidget(
          onPressed: _isButtonEnabled && !_isSaving ? _saveReflection : null,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.cardColor,
              disabledBackgroundColor: theme.cardColor.withOpacity(0.7),
              foregroundColor: _isButtonEnabled ? colorScheme.primary : theme.disabledColor,
              disabledForegroundColor: theme.disabledColor.withOpacity(0.7),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22.0),
              ),
              textStyle: TextStyle(
                fontFamily: _fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              elevation: _isButtonEnabled ? 3 : 0,
              shadowColor: theme.shadowColor.withOpacity(0.8),
            ),
            child: _isSaving
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _isButtonEnabled ? colorScheme.primary : theme.disabledColor,
              ),
            )
                : Text(
                "SAVE REFLECTION",
                style: TextStyle( // Ensure text color is explicitly set here
                  fontFamily: _fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isButtonEnabled ? colorScheme.primary : theme.disabledColor.withOpacity(0.7),
                )
            ),
          ),
        ),
      ),
    );
  }
}
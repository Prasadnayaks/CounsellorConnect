// lib/thoughts_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show SystemChrome, SystemUiOverlayStyle, rootBundle; // Added rootBundle
import 'dart:math' as math;
import 'dart:convert'; // For jsonDecode
// import 'package:http/http.dart' as http; // No longer needed if only using local JSON
// import 'dart:io'; // No longer needed if only using local JSON

import 'models/quote_model.dart';
import 'categories_screen.dart'; // Import CategoriesScreen

// --- Constants ---
const Color _overlayTextColor = Colors.white;
const Color _overlayIconColor = Colors.white;
final Color _generalButtonBgColor = Colors.black.withOpacity(0.35); // Slightly more opaque
// --- End Constants ---

// --- Background Image URLs (Ensure this list is populated with your Firebase URLs) ---
const List<String> _backgroundImages = [
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F%23space%20%23galaxy%20%23universe%20%23nebula%20%23photography.jpeg?alt=media&token=fc72156f-01a6-4f81-9458-710f21c71bef",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F00fcd3fa-b862-48bd-b8a7-48f6f9f6e039.jpeg?alt=media&token=4df8ff0a-449b-4354-ace9-2e1294448c61",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F064d98d9-abdd-4ccc-95dd-6800114f4a1d.jpeg?alt=media&token=1a1e1a97-8221-4a4c-9b09-36378cf80371",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F100%2B%20Vibrant%20Summer%20Phone%20Wallpapers.jpeg?alt=media&token=33d65d80-ac66-424a-b862-aea43a32b646",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F1a170b3e-ac77-4d53-9e6f-d970869872d5.jpeg?alt=media&token=2428c204-16e7-43a0-83e7-0637433cc094",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F1c599884-c1ca-4e5c-b662-54044fb97ca3.jpeg?alt=media&token=a682da1d-352e-4e8e-b9d4-1580930ec9ac",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F2663aa5f-6a64-432e-992d-6d28c2d53574.jpeg?alt=media&token=2d5f0368-772a-42fb-9b86-221001e2e93e",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F29920f4c-ca0d-40e2-b623-114b4f9892d2.jpeg?alt=media&token=b60b70ce-367f-46c6-a441-eef7f81c4061",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F41%20Stunning%20Summer%20Phone%20Wallpapers%20%E2%80%93%20Everyday%E2%80%A6.jpeg?alt=media&token=00f97478-f7d9-4337-9331-7fa167d61635",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F49bce983-9f5d-4f59-959f-6fea3c01fb6f.jpeg?alt=media&token=dfcfc30c-951e-4616-83d6-a03acde922de",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F4c9528ad-8061-4ab9-9b35-3b146c508ffe.jpeg?alt=media&token=ab0b6f45-392b-47aa-90a1-a981c642083b",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F563c3bb3-51b7-467f-adf0-19fce581b846.jpeg?alt=media&token=36297e3f-6117-476f-8c3a-a39133cb8c0a",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F5ec2b316-b31e-4817-a180-806d4b6cf0cf.jpeg?alt=media&token=d0af522d-efaa-404f-8bad-f420b6701cd9",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F62d76b02-ffc1-45eb-a886-b8b9986ef8a4.jpeg?alt=media&token=85b52eeb-ae52-49c8-bb7c-ffb7dbe8ef86",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F680cd62f-dcaa-4725-b345-e20ccf5a6527.jpeg?alt=media&token=71a29023-0baa-4a4d-8920-dd9de3c27a4e",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F6f7c1bb2-a937-4a6b-b74f-65dac2235ac8.jpeg?alt=media&token=2d72aee3-ca94-4bef-9155-7cc385b5915c",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F713e2fb4-b843-4402-afb3-6bd248fdeecd.jpeg?alt=media&token=3b4e10fc-6be7-41fa-b5bd-7840486fa935",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F783096a8-a925-48fe-a50b-587151047c94.jpeg?alt=media&token=c61e6522-1c9f-44f3-8cff-c6e76fc30758",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F80fbb05b-7891-49a0-b5ae-34b59cc88522.jpeg?alt=media&token=587bb9df-f63a-48de-a0da-cb4ed4f30592",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F8acd3ee4-483b-455e-bb86-72dc66cb6e46.jpeg?alt=media&token=8fb620a0-5ba3-45d4-bb09-c9f01c5ddee2",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F8fb39158-a613-4a1e-92cc-b00f141e19af.jpeg?alt=media&token=e265a224-b962-4fff-9e68-e29276b09dc5",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2F9a034281-5677-4f8c-a226-0f3384a2edd0.jpeg?alt=media&token=c01f6486-d620-44de-814d-cbe42e943444",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2FAcrylic%20paint%20of%20butterfiles%20in%20garden%20outdoors%E2%80%A6.jpeg?alt=media&token=e76db230-e2ff-4d99-9a66-cf7fd67f4283",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2FCep%20Telefonunuzun%20%C3%87ehresini%20De%C4%9Fi%C5%9Ftirecek%E2%80%A6.jpeg?alt=media&token=da8eeb87-0436-4416-8b58-f09ff462d4c9",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2FDesign%20resource%20nature%20background%20green%20pasture%E2%80%A6.jpeg?alt=media&token=0f421ade-7e71-478a-b375-c4f7d8641376",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2FDigital%20Backdrop%20with%20blending%20png%20overlay.jpeg?alt=media&token=ca27ec31-19fa-4f4a-9f12-4592919ec44e",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2FPalm%20Trees%2C%20Nature%20Scene%2C%20Scenic%20View.jpeg?alt=media&token=a9d96537-95af-4476-9165-8c575b5a3e4c",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2FRain%20Sounds%20in%20a%20Forest___%20-%20_Gentle%20rain%20falling%E2%80%A6.jpeg?alt=media&token=684d5839-cee0-46a8-b10b-38365fd51462",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2FSummer%20wallpaper%20background%20lockscreen%20iPhone%E2%80%A6.jpeg?alt=media&token=b825194f-cd21-415c-a7a4-2ae5df8d9055",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fb01f3ac6-227d-4307-ba00-dd3a4a6eb96f.jpeg?alt=media&token=2c97453f-327c-4425-8fb0-26bb445eabfe",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fc2c97912-ed22-4361-a7cb-1f1b050a659c.jpeg?alt=media&token=b885825e-d4af-4d49-821b-5deca3c7a88f",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fc8320c43-247e-41f4-9d4f-cd78e8e9a6cf.jpeg?alt=media&token=d3bc3b5b-68b3-4c01-9370-0269ef89cf69",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fd4ebadd7-33de-4508-9f0f-def2e7fa3c54.jpeg?alt=media&token=40806d31-f5cc-4447-ad7c-aab73e43db61",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fd5119cce-2f65-43f6-9ea2-d678e691a8a5.jpeg?alt=media&token=e1435c18-9e9d-41e6-bde2-04bc173c85a8",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fdownload.jpeg?alt=media&token=86f6e7ba-f5dc-4af3-9621-dd0f7065fd59",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fe7ad6d34-d1c2-4c1a-babb-2ed0cd6d62f7.jpeg?alt=media&token=cfe8d79c-48ce-471c-8219-6fed4f6ab166",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fe7eefc2e-4dbc-4b2b-817c-64f353fb9bc6.jpeg?alt=media&token=3c7a371a-b458-411e-ac3e-f3535e3bad60",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fi%20also%20known%20as%20the%20Beaver%20State%2C%20has%20some%20of%20the%E2%80%A6.jpeg?alt=media&token=d9e63265-86bb-4d48-8968-756d5f6dddab",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fwonderful%20nature%20%F0%9F%91%8F%20(1).jpeg?alt=media&token=fb73ea31-3c25-4c62-bb60-09ac1727f536",
  "https://firebasestorage.googleapis.com/v0/b/counsellorconnect-4642a.firebasestorage.app/o/quote_backgrounds%2Fwonderful%20nature%20%F0%9F%91%8F.jpeg?alt=media&token=8a1fd847-c2ef-4423-9df6-579cacd08a86",
  // Add YOUR URLs here
];

class ThoughtsScreen extends StatefulWidget {
  const ThoughtsScreen({Key? key}) : super(key: key);

  @override
  _ThoughtsScreenState createState() => _ThoughtsScreenState();
}

class _ThoughtsScreenState extends State<ThoughtsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<QuoteModel> _allQuotes = []; // Holds all quotes loaded from JSON
  List<QuoteModel> _displayedQuotes = []; // Quotes currently being displayed after filtering
  Set<String> _likedQuoteIds = {};
  bool _isLoading = true;
  String _errorMessage = '';
  User? _currentUser;
  final PageController _quotePageController = PageController();
  int _currentQuoteIndex = 0;
  final math.Random _random = math.Random();

  String? _currentBackgroundImageUrl;

  // --- NEW: State variable for current category filter ---
  String _currentCategoryFilter = "All"; // Default to showing all quotes

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadData(); // This will now also apply the initial filter
  }

  @override
  void dispose() {
    _quotePageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await _fetchQuotesFromLocalJson(); // This populates _allQuotes
      _applyCategoryFilter(); // Apply the current filter to populate _displayedQuotes

      if (_displayedQuotes.isNotEmpty) {
        _updateBackgroundImage(0, initialLoad: true); // Use index 0 of _displayedQuotes
      } else if (_allQuotes.isNotEmpty && _currentCategoryFilter != "All") {
        // If filter results in empty, but we have quotes, show a message or first of all quotes
        _errorMessage = "No quotes found for '$_currentCategoryFilter'. Showing all quotes.";
        _currentCategoryFilter = "All"; // Fallback to all
        _applyCategoryFilter();
        if(_displayedQuotes.isNotEmpty) _updateBackgroundImage(0, initialLoad: true);
      }


      if (_currentUser != null) {
        await _fetchLikedQuotes();
      }
    } catch (e, s) {
      print("[ThoughtsScreen] Error loading data: $e\n$s");
      if (mounted) {
        setState(() {
          _errorMessage = "Could not load thoughts.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchQuotesFromLocalJson() async {
    if (_backgroundImages.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = "Background image list is not configured.";
          // _isLoading = false; // Already handled in _loadData
        });
      }
      return;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/thoughts.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);

      if (mounted) {
        final List<QuoteModel> fetchedQuotes = [];
        for (var quoteJson in jsonData) {
          if (quoteJson is Map<String, dynamic>) {
            try {
              final randomBgUrl = _backgroundImages[_random.nextInt(_backgroundImages.length)];
              fetchedQuotes.add(QuoteModel.fromLocalJson(quoteJson, randomBgUrl));
            } catch (e) {
              print("[ThoughtsScreen] Error parsing local quote: $e");
            }
          }
        }
        // Don't shuffle here if you want a consistent "Favorites" order later
        // fetchedQuotes.shuffle(_random);
        _allQuotes = fetchedQuotes; // Store all loaded quotes
      }
    } catch (e) {
      print("[ThoughtsScreen] Error loading or parsing local thoughts.json: $e");
      if (mounted) {
        // _errorMessage = "Could not load thoughts from local file."; // Error is handled in _loadData
        rethrow; // Rethrow to be caught by _loadData
      }
    }
  }

  // --- NEW: Method to apply the current category filter ---
  void _applyCategoryFilter() {
    if (!mounted) return;

    List<QuoteModel> filtered = [];
    if (_currentCategoryFilter == "All") {
      filtered = List.from(_allQuotes);
    } else if (_currentCategoryFilter == "Favorites") {
      // Favorites logic: filter _allQuotes based on _likedQuoteIds
      // Ensure likedQuoteIds are fetched before this runs or handle async
      filtered = _allQuotes.where((quote) => _likedQuoteIds.contains(quote.id)).toList();
      if (filtered.isEmpty && _allQuotes.isNotEmpty) {
        // If no favorites, maybe show all or a message
        // For now, let's default to showing all if favorites is empty to avoid blank screen
        // _errorMessage = "You haven't liked any quotes yet. Showing all.";
        // filtered = List.from(_allQuotes);
      }
    } else {
      filtered = _allQuotes.where((quote) =>
      quote.category?.toLowerCase() == _currentCategoryFilter.toLowerCase()).toList();
    }

    // Shuffle the filtered list for variety each time a category is selected (optional)
    if (filtered.isNotEmpty && _currentCategoryFilter != "Favorites") { // Don't shuffle favorites maybe
      filtered.shuffle(_random);
    }

    setState(() {
      _displayedQuotes = filtered;
      _currentQuoteIndex = 0; // Reset to first quote of the new list
      if (_displayedQuotes.isNotEmpty) {
        _updateBackgroundImage(0, initialLoad: true); // Update for the new first quote
      } else {
        _currentBackgroundImageUrl = null; // No image if no quotes
        // Set a specific error message if a filter results in no quotes
        if (_currentCategoryFilter != "All" && _currentCategoryFilter != "Favorites") {
          _errorMessage = "No thoughts found for '$_currentCategoryFilter'.";
        } else if (_currentCategoryFilter == "Favorites") {
          _errorMessage = "You haven't liked any thoughts yet!";
        }
      }
    });
  }


  Future<void> _fetchLikedQuotes() async {
    if (_currentUser == null) return;
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('likedQuotes')
          .get();
      if (mounted) {
        final Set<String> likedIds = snapshot.docs.map((doc) => doc.id).toSet();
        // Only update and re-filter if liked quotes actually changed
        if (likedIds.difference(_likedQuoteIds).isNotEmpty || _likedQuoteIds.difference(likedIds).isNotEmpty) {
          setState(() {
            _likedQuoteIds = likedIds;
          });
          // If current filter is "Favorites", re-apply it
          if (_currentCategoryFilter == "Favorites") {
            _applyCategoryFilter();
          }
        }
      }
    } catch (e) {
      print("[ThoughtsScreen] Error fetching liked quotes: $e");
    }
  }

  void _updateBackgroundImage(int index, {bool initialLoad = false}) {
    if (_displayedQuotes.isEmpty || index < 0 || index >= _displayedQuotes.length) {
      if (mounted) setState(() => _currentBackgroundImageUrl = null); // No image if no quotes
      return;
    }
    String newImageUrl = _displayedQuotes[index].imageUrl;
    if (newImageUrl.isEmpty && _backgroundImages.isNotEmpty) {
      newImageUrl = _backgroundImages[_random.nextInt(_backgroundImages.length)];
    }

    if (initialLoad) {
      if (mounted) setState(() => _currentBackgroundImageUrl = newImageUrl);
    } else {
      if (_currentBackgroundImageUrl != newImageUrl) {
        if (mounted) setState(() => _currentBackgroundImageUrl = newImageUrl);
      }
    }
  }

  Future<void> _toggleLikeStatus(String quoteId) async {
    // ... (Your existing logic, ensure it updates Firestore and _likedQuoteIds state)
    // After updating _likedQuoteIds, if the current filter is "Favorites", re-apply the filter.
    // ... (your existing like/unlike logic for Firestore) ...
    // (Simplified for brevity, use your actual robust logic)
    if (_currentUser == null) return;
    final likedRef = _firestore.collection('users').doc(_currentUser!.uid).collection('likedQuotes').doc(quoteId);
    bool originallyLiked = _likedQuoteIds.contains(quoteId);

    if (mounted) {
      setState(() {
        if (originallyLiked) _likedQuoteIds.remove(quoteId);
        else _likedQuoteIds.add(quoteId);

        // If current filter is "Favorites", re-apply to update the view
        if (_currentCategoryFilter == "Favorites") {
          _applyCategoryFilter();
        }
      });
    }
    // Firestore update logic (from your previous code)
    try {
      if (!originallyLiked) {
        QuoteModel? quoteToSave;
        try { quoteToSave = _allQuotes.firstWhere((q) => q.id == quoteId); } catch (e) {/* ... */}
        if (quoteToSave != null) {
          await likedRef.set(quoteToSave.toJson()..addAll({'likedAt': FieldValue.serverTimestamp()}));
        } else {
          await likedRef.set({'id': quoteId, 'text': 'Liked quote not found in allQuotes', 'author': 'Unknown', 'likedAt': FieldValue.serverTimestamp()});
        }
      } else {
        await likedRef.delete();
      }
    } catch (e) {
      // Revert UI on error
      if (mounted) {
        setState(() {
          if (originallyLiked) _likedQuoteIds.add(quoteId);
          else _likedQuoteIds.remove(quoteId);
          if (_currentCategoryFilter == "Favorites") _applyCategoryFilter();
        });
      }
    }
  }

  void _shareQuote(QuoteModel quote) {
    final String shareText = '"${quote.text}"\n- ${quote.author}';
    Share.share(shareText);
  }

  // --- NEW: Method to navigate to CategoriesScreen and handle result ---
  Future<void> _openCategorySelection() async {
    final String? selectedKey = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesScreen(currentSelectedCategory: _currentCategoryFilter),
      ),
    );

    if (selectedKey != null && selectedKey != _currentCategoryFilter && mounted) {
      print("Category selected: $selectedKey");
      setState(() {
        _isLoading = true; // Show loading while filtering
        _errorMessage = ''; // Clear previous errors
        _currentCategoryFilter = selectedKey;
      });
      // No need to call _fetchQuotesFromLocalJson() again as _allQuotes is already populated
      _applyCategoryFilter(); // Apply new filter to _allQuotes
      if (_displayedQuotes.isNotEmpty) {
        _updateBackgroundImage(0, initialLoad: true);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final theme = Theme.of(context); // Get theme for fallback colors

    if (_isLoading && _allQuotes.isEmpty) { // Show loading only on initial full load
      return Container(color: Colors.grey.shade900, child: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    // If _errorMessage is set after trying to filter, show it.
    // Also handles case where _displayedQuotes is empty after filtering.
    if (_displayedQuotes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          if (_currentBackgroundImageUrl != null && _currentBackgroundImageUrl!.isNotEmpty)
            CachedNetworkImage(
              key: ValueKey<String>("empty_bg_$_currentBackgroundImageUrl"),
              imageUrl: _currentBackgroundImageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6))), // Dark scrim
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, color: Colors.white54, size: 60),
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage.isNotEmpty ? _errorMessage : "No thoughts found for '${_currentCategoryFilter}'.",
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: _openCategorySelection,
                    icon: const Icon(Icons.filter_list_rounded, color: _overlayIconColor),
                    label: Text(_currentCategoryFilter == "All" ? "Categories" : _currentCategoryFilter, style: const TextStyle(color: _overlayTextColor)),
                    style: TextButton.styleFrom(
                      backgroundColor: _generalButtonBgColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_currentCategoryFilter != "All") ...[
                    const SizedBox(height:10),
                    TextButton(onPressed: (){
                      setState(() {
                        _currentCategoryFilter = "All";
                        _isLoading = true; // To re-apply filter and show loading
                        _errorMessage = '';
                      });
                      _applyCategoryFilter();
                      if(_displayedQuotes.isNotEmpty) _updateBackgroundImage(0, initialLoad: true);
                      setState(() => _isLoading = false);
                    }, child: Text("Show All Thoughts", style: TextStyle(color: theme.colorScheme.primary)))
                  ]
                ],
              ),
            ),
          ),
        ]),
      );
    }


    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _currentBackgroundImageUrl == null || _currentBackgroundImageUrl!.isEmpty
                ? Container(key: const ValueKey('no_image_thoughts'), color: Colors.grey.shade900)
                : CachedNetworkImage(
              key: ValueKey<String>(_currentBackgroundImageUrl!),
              imageUrl: _currentBackgroundImageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(color: Colors.grey.shade800),
              errorWidget: (context, url, error) => Container(color: Colors.grey.shade900, child: const Center(child: Icon(Icons.error_outline, color: Colors.white54, size: 40))),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.25, 0.7, 1.0],
                ),
              ),
            ),
          ),
          PageView.builder(
            controller: _quotePageController,
            scrollDirection: Axis.vertical,
            itemCount: _displayedQuotes.length,
            onPageChanged: (index) {
              if (mounted) {
                setState(() {
                  _currentQuoteIndex = index;
                  _updateBackgroundImage(index);
                });
              }
            },
            itemBuilder: (context, index) {
              final quote = _displayedQuotes[index];
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Transform.translate(offset: const Offset(-15, -5), child: Text("“", style: TextStyle(fontSize: 60, color: _overlayTextColor.withOpacity(0.5)))),
                          Expanded(child: Text(quote.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, color: _overlayTextColor, fontWeight: FontWeight.w500, height: 1.4, shadows: [Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(1, 1))]))),
                        ],
                        ),
                        const SizedBox(height: 20),
                        Text("— ${quote.author.toUpperCase()} —", style: TextStyle(fontSize: 14, color: _overlayTextColor.withOpacity(0.8), fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: bottomPadding + 20,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _openCategorySelection, // Open category selection
                    icon: const Icon(Icons.filter_list_rounded, color: _overlayIconColor, size: 20), // Changed icon
                    label: Text(
                        _currentCategoryFilter == "All" ? "Categories" : _currentCategoryFilter, // Display current filter
                        style: TextStyle(color: _overlayTextColor, fontFamily: '_primaryFontFamily', fontWeight: FontWeight.w500)
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: _generalButtonBgColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_displayedQuotes.isNotEmpty && _currentQuoteIndex < _displayedQuotes.length)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _likedQuoteIds.contains(_displayedQuotes[_currentQuoteIndex].id)
                                ? Icons.favorite
                                : Icons.favorite_outline,
                            color: _likedQuoteIds.contains(_displayedQuotes[_currentQuoteIndex].id)
                                ? Colors.red.shade400
                                : _overlayIconColor,
                            size: 28,
                          ),
                          tooltip: _likedQuoteIds.contains(_displayedQuotes[_currentQuoteIndex].id)
                              ? "Unlike"
                              : "Like",
                          onPressed: () => _toggleLikeStatus(_displayedQuotes[_currentQuoteIndex].id),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.share_outlined, color: _overlayIconColor, size: 28),
                          tooltip: "Share",
                          onPressed: () => _shareQuote(_displayedQuotes[_currentQuoteIndex]),
                        ),
                      ],
                    )
                  else const SizedBox(width: 88), // Placeholder for alignment if no quote actions
                ],
              ),
            ),
          ),
          // Loading indicator for filtering
          if (_isLoading && _allQuotes.isNotEmpty) // Show loading only when re-filtering, not initial load
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
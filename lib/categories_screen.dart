// lib/categories_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter

import 'data/category_data.dart'; // Your category definitions
import 'theme/theme_provider.dart';

class CategoriesScreen extends StatefulWidget {
  final String? currentSelectedCategory;

  const CategoriesScreen({Key? key, this.currentSelectedCategory}) : super(key: key);

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late String _selectedCategoryKey;
  bool _isCategoriesTabSelected = true;

  static const String _primaryFontFamily = 'Nunito';
  static const double _cardCornerRadius = 16.0;
  static const double _quickAccessCardCornerRadius = 18.0;

  @override
  void initState() {
    super.initState();
    _selectedCategoryKey = widget.currentSelectedCategory ?? "All";
  }

  void _onCategoryTapped(String newSelectedKey) {
    if (mounted) {
      setState(() {
        _selectedCategoryKey = newSelectedKey;
      });
    }
  }

  // Helper for a more pronounced shadow, similar to your HomeScreen cards
  List<BoxShadow> _getMorePronouncedCardShadow(BuildContext context, {Color? shadowColorHint}) {
    final theme = Theme.of(context);
    // Use a slightly darker shadow for more pop, or hint from theme accent
    Color baseShadowColor = shadowColorHint?.withOpacity(0.3) ?? Colors.black.withOpacity(0.15);
    if (theme.brightness == Brightness.dark) {
      baseShadowColor = shadowColorHint?.withOpacity(0.5) ?? Colors.black.withOpacity(0.3);
    }

    return [
      BoxShadow(
        color: baseShadowColor,
        blurRadius: 12.0, // Increased blur
        spreadRadius: 1.0,  // Slight spread
        offset: const Offset(0, 6.0), // Increased Y offset
      ),
      BoxShadow( // Softer ambient shadow
        color: baseShadowColor.withOpacity(0.08),
        blurRadius: 6.0,
        offset: const Offset(0, 2.0),
      ),
    ];
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // For elements at the top that might sit over the scaffold color if no gradient
    final Color topElementsColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;


    final Color selectedTabColor = colorScheme.primary;
    // Unselected tab background will be subtle on the scaffold color
    final Color unselectedTabContainerBg = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);
    final Color selectedTabTextColor = colorScheme.onPrimary;
    final Color unselectedTabTextColor = topElementsColor.withOpacity(0.7);
    final topSafeAreaPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Main background is now scaffold color
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: topSafeAreaPadding + 10, left: 16, right: 16, bottom: 10),
              child: Column(
                children: [
                  // Close Button
                  Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      color: theme.cardColor.withOpacity(0.5), // Slightly visible on scaffold bg
                      borderRadius: BorderRadius.circular(8.0),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, _selectedCategoryKey),
                        borderRadius: BorderRadius.circular(8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(7.0),
                          child: Icon(Icons.close, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
                        ),
                        //tooltip: "Close & Apply Filter",
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Big "Categories" Text (Faded)
                  Text(
                    "Categories",
                    style: TextStyle(
                      fontFamily: _primaryFontFamily,
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.displayLarge?.color?.withOpacity(0.06), // Faded, based on text theme
                      height: 0.8,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // "Categories" / "Themes" Toggle
                  _buildSegmentedControl(
                      context,
                      selectedTabColor,
                      Colors.transparent, // Unselected tab is transparent
                      selectedTabTextColor,
                      unselectedTabTextColor,
                      unselectedTabContainerBg // Background for the whole toggle bar
                  ),
                  // No SizedBox needed here, padding will be handled by next SliverPadding
                ],
              ),
            ),
          ),

          // Quick Access Cards (General, Favorites)
          if (appCategories.isNotEmpty && appCategories.first.title == "Quick Access")
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // Top padding to separate from toggle
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.0,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final categoryItem = appCategories.first.items[index];
                    bool isSelected = _selectedCategoryKey == categoryItem.associatedQuoteCategory;
                    return _buildQuickAccessCategoryCard(context, categoryItem, isSelected, colorScheme);
                  },
                  childCount: appCategories.first.items.length,
                ),
              ),
            ),

          // Scrollable List of Main Categories and their Subcategories
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, mainIndex) {
                if (appCategories.first.title == "Quick Access" && mainIndex == 0) {
                  return const SizedBox.shrink();
                }
                final mainCategory = appCategories[mainIndex];
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 20.0, bottom: 5.0), // Increased top padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15.0, top: 10.0, left: 4), // Increased padding
                        child: Text(
                          mainCategory.title,
                          style: theme.textTheme.headlineSmall?.copyWith( // Using headlineSmall for section titles
                            fontWeight: FontWeight.bold,
                            fontFamily: _primaryFontFamily,
                            color: theme.colorScheme.onBackground.withOpacity(0.85),
                          ),
                        ),
                      ),
                      _buildHorizontallyScrollingSubCategorySection(context, mainCategory.items, colorScheme),
                    ],
                  ),
                );
              },
              childCount: appCategories.length,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 30)),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(
      BuildContext context,
      Color selectedTabColor,
      Color unselectedTabColor, // Will be transparent for the tab itself
      Color selectedTabTextColor,
      Color unselectedTabTextColor,
      Color toggleBarBackgroundColor) { // Background for the bar
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40), // Wider margin for a less wide bar
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: toggleBarBackgroundColor, // Background of the toggle bar
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildTab("Categories", _isCategoriesTabSelected, selectedTabColor,
                unselectedTabColor, selectedTabTextColor, unselectedTabTextColor, () {
                  if (!_isCategoriesTabSelected) {
                    setState(() => _isCategoriesTabSelected = true);
                  }
                }),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildTab("Themes", !_isCategoriesTabSelected, selectedTabColor,
                unselectedTabColor, selectedTabTextColor, unselectedTabTextColor, () {
                  if (_isCategoriesTabSelected) {
                    setState(() => _isCategoriesTabSelected = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Themes functionality coming soon!"), duration: Duration(seconds: 2)),
                    );
                  }
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      String text,
      bool isSelected,
      Color selectedColor,
      Color unselectedColor, // This is transparent
      Color selectedTextColor,
      Color unselectedTextColor,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10), // Adjusted padding
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [
            BoxShadow(
                color: selectedColor.withOpacity(0.45), // Slightly stronger shadow for selected tab
                blurRadius: 6,
                spreadRadius: 0.5,
                offset: const Offset(0, 3))
          ] : [],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _primaryFontFamily,
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessCategoryCard(
      BuildContext context, CategoryItem item, bool isSelected, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    Color cardBackgroundColor;
    Color textColor;
    IconData displayIcon;
    Color iconColor;
    List<BoxShadow> boxShadow = _getMorePronouncedCardShadow(context, shadowColorHint: isSelected ? colorScheme.primary : null);


    bool isGeneral = item.associatedQuoteCategory == "All";
    bool isFavorites = item.associatedQuoteCategory == "Favorites";

    if (isSelected) {
      cardBackgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
      iconColor = colorScheme.onPrimary;
      displayIcon = isGeneral ? Icons.check_circle : (isFavorites ? Icons.favorite : Icons.apps_rounded);
    } else {
      cardBackgroundColor = theme.cardColor; // Standard card color
      textColor = colorScheme.onSurface;
      iconColor = isGeneral ? colorScheme.primary.withOpacity(0.8) : colorScheme.secondary.withOpacity(0.8);
      displayIcon = isGeneral ? Icons.apps_rounded : Icons.favorite_border_rounded;
    }

    return GestureDetector(
      onTap: () => _onCategoryTapped(item.associatedQuoteCategory),
      child: Container( // Use container for custom shadow
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(_quickAccessCardCornerRadius),
          boxShadow: boxShadow,
        ),
        child: Material( // Material for InkWell ripple
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_quickAccessCardCornerRadius),
          child: InkWell(
            onTap: () => _onCategoryTapped(item.associatedQuoteCategory),
            borderRadius: BorderRadius.circular(_quickAccessCardCornerRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontFamily: _primaryFontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(displayIcon, color: iconColor, size: 22),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontallyScrollingSubCategorySection(
      BuildContext context, List<CategoryItem> items, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    double cardWidth = (MediaQuery.of(context).size.width - (16 * 2) - 12) / 2.35;
    double cardHeight = cardWidth / 1.4;

    List<Widget> columnPairs = [];
    for (int i = 0; i < items.length; i += 2) {
      Widget card1 = _buildSubCategoryCard(
          context, items[i], _selectedCategoryKey == items[i].associatedQuoteCategory,
          colorScheme, cardWidth, cardHeight);
      Widget card2 = (i + 1 < items.length)
          ? _buildSubCategoryCard(
          context, items[i + 1], _selectedCategoryKey == items[i + 1].associatedQuoteCategory,
          colorScheme, cardWidth, cardHeight)
          : SizedBox(width: cardWidth, height: cardHeight);

      columnPairs.add(
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [card1, const SizedBox(height: 10), card2],
            ),
          )
      );
    }

    return SizedBox(
      height: (cardHeight * 2) + 10 + 5,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4, right: 16),
        children: columnPairs,
      ),
    );
  }

  Widget _buildSubCategoryCard(
      BuildContext context, CategoryItem item, bool isSelected, ColorScheme colorScheme,
      double width, double height) {
    final theme = Theme.of(context);
    Color cardBackgroundColor = isSelected ? colorScheme.primary.withOpacity(0.9) : theme.cardColor; // Slightly transparent primary if selected
    Color textColor = isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withOpacity(0.9);
    // Border remains subtle, slightly more prominent if selected
    Color borderColor = isSelected ? colorScheme.primary.withOpacity(0.6) : theme.dividerColor.withOpacity(0.2);
    List<BoxShadow> boxShadow = _getMorePronouncedCardShadow(context, shadowColorHint: isSelected ? colorScheme.primary : null);

    String? imagePath = item.imageName != null ? 'assets/category_images/${item.imageName}' : null;

    return SizedBox(
      width: width,
      height: height,
      child: Container( // Container for shadow and background
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(_cardCornerRadius),
          boxShadow: boxShadow,
          border: Border.all(color: borderColor, width: isSelected ? 1.0 : 0.5),
        ),
        child: Material( // Material for InkWell ripple
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_cardCornerRadius),
          child: InkWell(
            onTap: () => _onCategoryTapped(item.associatedQuoteCategory),
            borderRadius: BorderRadius.circular(_cardCornerRadius),
            child: ClipRRect( // ClipRRect to ensure image respects card's rounded corners
              borderRadius: BorderRadius.circular(_cardCornerRadius),
              child: Stack(
                children: [
                  if (imagePath != null)
                    Positioned(
                      bottom: -height * 0.05,
                      right: -width * 0.1,
                      child: ClipPath(
                        child: Image.asset(
                          imagePath,
                          width: width * 0.7, // Adjusted size
                          height: height * 0.7,
                          fit: BoxFit.contain,
                          opacity: AlwaysStoppedAnimation(isSelected ? 0.35 : 0.2), // Adjusted opacity
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, left: 10.0, right: 8.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: _primaryFontFamily,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isSelected)
                          Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top:4.0, right: 2, bottom: 2),
                                child: Icon(Icons.check_circle, size: 16, color: textColor.withOpacity(0.9)),
                              )
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
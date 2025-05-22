// lib/data/category_data.dart

class CategoryItem {
  final String name;
  final String? imageName; // e.g., "positive_thinking.png" from assets/category_images/
  final String associatedQuoteCategory; // Matches "category" in thoughts.json

  CategoryItem({
    required this.name,
    this.imageName,
    String? associatedQuoteCategory,
  }) : this.associatedQuoteCategory = associatedQuoteCategory ?? name; // Default to name if not specified
}

class MainCategory {
  final String title;
  final List<CategoryItem> items;

  MainCategory({required this.title, required this.items});
}

// Example Data - Ensure all items have isLocked = false (or remove the property)
// YOU WILL NEED TO EXPAND THIS WITH ALL YOUR CATEGORIES AND IMAGE NAMES
// Make sure imageName matches files you'll add to 'assets/category_images/'
final List<MainCategory> appCategories = [
  MainCategory(title: "Quick Access", items: [
    CategoryItem(name: "General", imageName: "general_icon.png", associatedQuoteCategory: "All"),
    CategoryItem(name: "Favorites", imageName: "favorites_icon.png", associatedQuoteCategory: "Favorites"),
  ]),
  MainCategory(title: "Most Popular", items: [
    CategoryItem(name: "Positive Thinking", imageName: "positive_thinking.png", associatedQuoteCategory: "Positivity"),
    CategoryItem(name: "Sadness", imageName: "sadness.png"),
    CategoryItem(name: "Short Quotes", imageName: "short_quotes.png"), // Needs logic in ThoughtsScreen
    CategoryItem(name: "Love Yourself", imageName: "love_yourself.png", associatedQuoteCategory: "Self-Love"),
    CategoryItem(name: "Motivation", imageName: "motivation_popular.png", associatedQuoteCategory: "Motivation"), // Added example
    CategoryItem(name: "Wisdom", imageName: "wisdom_popular.png", associatedQuoteCategory: "Wisdom"),       // Added example
  ]),
  MainCategory(title: "Calm Down", items: [
    CategoryItem(name: "Appreciation", imageName: "appreciation.png", associatedQuoteCategory: "Gratitude"),
    CategoryItem(name: "Handling Stress", imageName: "handling_stress.png", associatedQuoteCategory: "Resilience"),
    CategoryItem(name: "Mindfulness", imageName: "mindfulness.png"),
    CategoryItem(name: "Faith", imageName: "faith.png"),
    CategoryItem(name: "Dealing with Anxiety", imageName: "dealing_with_anxiety.png", associatedQuoteCategory: "Anxiety"),
    CategoryItem(name: "Affirmations", imageName: "affirmations.png"),
    CategoryItem(name: "Patience", imageName: "patience.png", associatedQuoteCategory: "Perseverance"), // Added
    CategoryItem(name: "Peace", imageName: "peace.png", associatedQuoteCategory: "Simplicity"), // Added
  ]),
  MainCategory(title: "Hard Times", items: [
    CategoryItem(name: "Sadness", imageName: "sadness_hard.png", associatedQuoteCategory: "Sadness"), // Duplicate name, ensure distinct associatedCategory or handle
    CategoryItem(name: "Heartbroken", imageName: "heartbroken.png"),
    CategoryItem(name: "Letting Go", imageName: "letting_go.png"),
    CategoryItem(name: "Loneliness", imageName: "loneliness.png"),
    CategoryItem(name: "Breakup", imageName: "breakup.png"),
    CategoryItem(name: "Healing", imageName: "healing.png", associatedQuoteCategory: "Resilience"), // Added
    CategoryItem(name: "Strength", imageName: "strength_hard.png", associatedQuoteCategory: "Strength"), // Added
    CategoryItem(name: "Hope", imageName: "hope_hard.png", associatedQuoteCategory: "Hope"), // Added
  ]),
  MainCategory(title: "Inspiration", items: [
    CategoryItem(name: "Life", imageName: "life_insp.png"),
    CategoryItem(name: "Funny", imageName: "funny.png"), // You'll need "Funny" quotes in thoughts.json
    CategoryItem(name: "Morning", imageName: "morning.png"),
    CategoryItem(name: "Dreams", imageName: "dreams_insp.png", associatedQuoteCategory: "Dreams"),
    CategoryItem(name: "Success", imageName: "success_insp.png", associatedQuoteCategory: "Success"),
    CategoryItem(name: "Courage", imageName: "courage_insp.png", associatedQuoteCategory: "Courage"),
    CategoryItem(name: "Creativity", imageName: "creativity_insp.png", associatedQuoteCategory: "Creativity"),
    CategoryItem(name: "Adventure", imageName: "adventure_insp.png", associatedQuoteCategory: "Adventure"),
  ]),
  // TODO: Add "Mental Health", "Work & Productivity" main categories and their 8+ subcategories
  // Example structure:
  // MainCategory(title: "Mental Health", items: [
  //   CategoryItem(name: "Depression", imageName: "depression.png"),
  //   CategoryItem(name: "Mood Disorder", imageName: "mood_disorder.png"),
  //   ... (at least 6 more)
  // ]),
  // MainCategory(title: "Work & Productivity", items: [
  //   CategoryItem(name: "Success", imageName: "success_work.png", associatedQuoteCategory: "Success"),
  //   CategoryItem(name: "Focus", imageName: "focus_work.png"),
  //   ... (at least 6 more)
  // ]),
];
// lib/main.dart
import 'package:counsellorconnect/counselor/counselor_main_navigation_shell.dart';
import 'package:counsellorconnect/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Ensure this is imported
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'theme/theme_provider.dart';

// Import ALL potential entry points
import 'role_selection_screen.dart';
import 'main_navigation_shell.dart';
import 'counselor/counselor_dashboard_screen.dart'; // Adjusted path

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // It's good practice to set a default style early if possible,
  // though MaterialApp's theme will also influence this.
  // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  //   systemNavigationBarColor: Colors.transparent, // Example default
  //   systemNavigationBarIconBrightness: Brightness.dark, // Example default
  // ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final themeProvider = ThemeProvider();
  await themeProvider.loadThemePreferences();
  runApp(ChangeNotifierProvider.value(
    value: themeProvider,
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  Future<String?> _fetchUserRole(String userId) async {
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (docSnap.exists && (docSnap.data() as Map).containsKey('role')) {
        return docSnap.data()!['role'] as String?;
      }
      print("Warning: User document or role missing for $userId. Defaulting to 'user'.");
      return 'user';
    } catch (e) {
      print("Error fetching user role for $userId: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Determine the default system navigation bar color based on the current theme's scaffold background
    final ThemeData currentEffectiveTheme = themeProvider.themeMode == ThemeMode.dark
        ? themeProvider.darkTheme
        : themeProvider.currentLightTheme;

    final Color defaultSystemNavBarColor = currentEffectiveTheme.scaffoldBackgroundColor;
    final Brightness defaultSystemNavBarIconBrightness =
    ThemeData.estimateBrightnessForColor(defaultSystemNavBarColor) == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    // Define a default SystemUiOverlayStyle for the app
    final SystemUiOverlayStyle defaultOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Example: transparent status bar
      statusBarIconBrightness: currentEffectiveTheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: defaultSystemNavBarColor,
      systemNavigationBarIconBrightness: defaultSystemNavBarIconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: defaultOverlayStyle, // Apply this default style globally
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.themeMode,
        theme: themeProvider.currentLightTheme,
        darkTheme: themeProvider.darkTheme,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              // While waiting, ensure the AnnotatedRegion is still in effect if possible,
              // or use a simple Scaffold that might pick up system defaults briefly.
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            Widget screenToShow;
            if (authSnapshot.hasData && authSnapshot.data != null) {
              final user = authSnapshot.data!;
              screenToShow = FutureBuilder<String?>(
                future: _fetchUserRole(user.uid),
                builder: (context, roleSnapshot) {
                  if (roleSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  if (roleSnapshot.hasError || !roleSnapshot.hasData || roleSnapshot.data == null) {
                    // Default to user dashboard on error, this screen will have its own AnnotatedRegion
                    return const MainNavigationShell();
                  }
                  final String role = roleSnapshot.data!;
                  if (role == 'counselor') {
                    // CounselorDashboardScreen should also have its own AnnotatedRegion
                    return const CounselorMainNavigationShell();
                  } else {
                    // MainNavigationShell will have its own more specific AnnotatedRegion
                    return const MainNavigationShell();
                  }
                },
              );
            } else {
              // StartPage and RoleSelectionScreen should ideally also have their own
              // AnnotatedRegion if their bottom background differs from the default scaffold.
              screenToShow = const StartPage();
            }
            // The child of MaterialApp (which home becomes) will inherit the AnnotatedRegion
            // unless it provides its own.
            return screenToShow;
          },
        ),
      ),
    );
  }
}
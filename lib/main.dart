// lib/main.dart
import 'package:counsellorconnect/firebase_options.dart';
import 'package:counsellorconnect/onboarding/onboarding_page.dart';
import 'package:counsellorconnect/services/notification_service.dart';
import 'package:counsellorconnect/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

import 'theme/theme_provider.dart';
import 'main_navigation_shell.dart';
import 'counselor/counselor_main_navigation_shell.dart';

final NotificationService notificationService = NotificationService();

// SharedPreferences Keys (consistent with settings_screen.dart)
const String _checkInReminderEnabledKey = 'checkInReminderEnabled';
const String _checkInTimeHourKey = 'checkInTimeHour';
const String _checkInTimeMinuteKey = 'checkInTimeMinute';
const String _positivityReminderEnabledKey = 'positivityReminderEnabled';
const String _positivityStartTimeHourKey = 'positivityStartTimeHour';
const String _positivityStartTimeMinuteKey = 'positivityStartTimeMinute';
const String _positivityEndTimeHourKey = 'positivityEndTimeHour';
const String _positivityEndTimeMinuteKey = 'positivityEndTimeMinute';

Future<void> _scheduleNotificationsBasedOnPrefs() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  bool checkInEnabled = prefs.getBool(_checkInReminderEnabledKey) ?? false;
  if (checkInEnabled) {
    TimeOfDay checkInTime = TimeOfDay(
      hour: prefs.getInt(_checkInTimeHourKey) ?? 20,
      minute: prefs.getInt(_checkInTimeMinuteKey) ?? 0,
    );
    await notificationService.scheduleDailyCheckInReminder(time: checkInTime);
  } else {
    await notificationService.cancelDailyCheckInReminder();
  }

  bool positivityEnabled = prefs.getBool(_positivityReminderEnabledKey) ?? false;
  if (positivityEnabled) {
    TimeOfDay startTime = TimeOfDay(
      hour: prefs.getInt(_positivityStartTimeHourKey) ?? 9,
      minute: prefs.getInt(_positivityStartTimeMinuteKey) ?? 0,
    );
    TimeOfDay endTime = TimeOfDay(
      hour: prefs.getInt(_positivityEndTimeHourKey) ?? 21,
      minute: prefs.getInt(_positivityEndTimeMinuteKey) ?? 0,
    );
    if ((startTime.hour * 60 + startTime.minute) < (endTime.hour * 60 + endTime.minute)) {
      await notificationService.schedulePositivityReminders(startTime: startTime, endTime: endTime);
    } else {
      print("Positivity reminders not scheduled: start time not before end time.");
      await notificationService.cancelPositivityReminders(); // Ensure they are cancelled if range is invalid
    }
  } else {
    await notificationService.cancelPositivityReminders();
  }

  // Keep Daily Challenge scheduling if it's independent of these settings
  await notificationService.scheduleDailyChallengeNotification(
    title: "🌟 Daily Challenge!",
    body: "A new challenge awaits you today. Tap to check it out!",
    time: const TimeOfDay(hour: 9, minute: 30), // Example time
  );
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await notificationService.init();
  await _scheduleNotificationsBasedOnPrefs(); // Schedule based on saved prefs

  final themeProvider = ThemeProvider();
  await themeProvider.loadThemePreferences();

  runApp(ChangeNotifierProvider.value(
    value: themeProvider,
    child: const MyApp(),
  ));
}

// ... (Rest of your MyApp class and _fetchUserRole method remain unchanged)
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  Future<String?> _fetchUserRole(String userId) async {
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (docSnap.exists && (docSnap.data() as Map).containsKey('role')) {
        return docSnap.data()!['role'] as String?;
      }
      return 'user';
    } catch (e) {
      print("Error fetching user role for $userId: $e");
      return 'user';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final ThemeData currentEffectiveTheme = themeProvider.themeMode == ThemeMode.dark
        ? themeProvider.darkTheme
        : themeProvider.currentLightTheme;
    final Color defaultSystemNavBarColor = currentEffectiveTheme.scaffoldBackgroundColor;
    final Brightness defaultSystemNavBarIconBrightness =
    ThemeData.estimateBrightnessForColor(defaultSystemNavBarColor) == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    final SystemUiOverlayStyle defaultOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: currentEffectiveTheme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: defaultSystemNavBarColor,
      systemNavigationBarIconBrightness: defaultSystemNavBarIconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: defaultOverlayStyle,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.themeMode,
        theme: themeProvider.currentLightTheme,
        darkTheme: themeProvider.darkTheme,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (authSnapshot.hasData && authSnapshot.data != null) {
              final user = authSnapshot.data!;
              return FutureBuilder<String?>(
                future: _fetchUserRole(user.uid),
                builder: (context, roleSnapshot) {
                  if (roleSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  final String role = roleSnapshot.data ?? 'user';
                  if (role == 'counselor') {
                    return const CounselorMainNavigationShell();
                  } else {
                    return const BreathingSplashScreen();
                  }
                },
              );
            } else {
              return const StartPage();
            }
          },
        ),
      ),
    );
  }
}
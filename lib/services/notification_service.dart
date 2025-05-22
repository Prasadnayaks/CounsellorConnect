// lib/services/notification_service.dart
import 'dart:async';
import 'dart:convert'; // For jsonDecode
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart'; // For other features if needed
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Assuming QuoteModel is in this path
import '../models/quote_model.dart'; // For using QuoteModel

// Notification Channel Details
const String _dailyChallengeChannelId = 'daily_challenge_channel';
const String _dailyChallengeChannelName = 'Daily Challenges';
const String _dailyChallengeChannelDescription = 'Notifications for daily challenges.';

const String _thoughtsChannelId = 'thoughts_channel';
const String _thoughtsChannelName = 'Daily Thoughts';
const String _thoughtsChannelDescription = 'Daily inspirational thoughts and quotes.';

const String _checkInChannelId = 'check_in_channel';
const String _checkInChannelName = 'Check-in Reminders';
const String _checkInChannelDescription = 'Daily mood check-in reminders.';

// Notification IDs
const int _dailyChallengeNotificationId = 0;
const int _checkInReminderNotificationId = 4; // Changed from 4 to avoid conflict
const int _positivityReminderBaseId = 100; // Positivity reminders will use IDs 100+

List<QuoteModel> _loadedQuotes = [];
final Random _random = Random();

// Callback for when a notification is tapped when the app is in the background or terminated
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('Background notification tapped: ${notificationResponse.payload}');
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _iosPlugin =>
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    await _configureLocalTimeZone();
    await _loadQuotes(); // Load quotes on init

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Your app icon

    // Following the example: categories and detailed permission requests can be separate.
    // Basic initialization for Darwin platforms.
    final DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: false, // Permissions can be requested later
      requestBadgePermission: false,
      requestSoundPermission: false,
      // onDidReceiveLocalNotification is for iOS < 10 foreground.
      // For iOS 10+, foreground presentation is handled by DarwinNotificationDetails within show()
      // or by implementing UNUserNotificationCenterDelegate's willPresentNotification method.
      // The example does not set onDidReceiveLocalNotification in the main init settings,
      // but rather as part of requesting permissions if needed.
      // For simplicity in your case, and if you don't need complex foreground handling for old iOS,
      // you can omit it here. We can add it back if specifically required for older iOS.
    );

    final InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request necessary permissions
    await requestPermissions();
  }

  Future<void> _loadQuotes() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data/thoughts.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);
      // Assuming _backgroundImages is a global or accessible list of image URLs for quotes
      // For simplicity, I'll assign a placeholder or let QuoteModel handle it.
      _loadedQuotes = jsonData
          .map((item) => QuoteModel.fromLocalJson(item, "placeholder_image_url")) // Provide a placeholder image URL
          .toList();
      print("Loaded ${_loadedQuotes.length} quotes.");
    } catch (e) {
      print("Error loading quotes for notifications: $e");
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        // critical: false, // if you need critical alerts
      );
    } else if (Platform.isAndroid) {
      await _androidPlugin?.requestNotificationsPermission(); // For general notifications (API 33+)
      await _androidPlugin?.requestExactAlarmsPermission(); // For exact alarms (API 31+)
    }
  }

  static Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('Could not get local timezone: $e. Using default.');
      tz.setLocalLocation(tz.getLocation('America/Detroit'));
    }
  }

  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null) {
      print('Notification response payload: $payload');
      // Handle navigation based on payload if necessary
    }
  }

  NotificationDetails _getNotificationDetails(
      String channelId, String channelName, String channelDescription) {
    final AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails darwinNotificationDetails =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(
        android: androidNotificationDetails, iOS: darwinNotificationDetails, macOS: darwinNotificationDetails);
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> _scheduleNotificationWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, title, body, scheduledDate, notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      print('Scheduled exact notification ID $id for: $scheduledDate');
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        print('Exact alarms not permitted for ID $id, trying inexact.');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id, title, body, scheduledDate, notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: '${payload}_inexact',
        );
        print('Scheduled inexact notification ID $id for $scheduledDate');
      } else {
        print('PlatformException while scheduling notification ID $id: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error scheduling notification ID $id: $e');
    }
  }

  Future<void> scheduleDailyCheckInReminder({required TimeOfDay time}) async {
    await cancelNotificationById(_checkInReminderNotificationId);
    await _scheduleNotificationWithFallback(
      id: _checkInReminderNotificationId,
      title: "🌟 Daily Check-in",
      body: "How are you feeling today? Take a moment to reflect.",
      scheduledDate: _nextInstanceOfTime(time),
      notificationDetails: _getNotificationDetails(
          _checkInChannelId, _checkInChannelName, _checkInChannelDescription),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_check_in_payload',
    );
  }

  Future<void> cancelDailyCheckInReminder() async {
    await flutterLocalNotificationsPlugin.cancel(_checkInReminderNotificationId);
    print("Cancelled Daily Check-in Reminder.");
  }

  Future<void> schedulePositivityReminders({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    await cancelPositivityReminders();

    if (_loadedQuotes.isEmpty) {
      print("No quotes loaded to schedule for positivity reminders.");
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // Calculate start and end times for today
    tz.TZDateTime currentSlotTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, startTime.hour, startTime.minute);
    final tz.TZDateTime loopEndTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, endTime.hour, endTime.minute);

    int slotIndex = 0;
    while (currentSlotTime.isBefore(loopEndTime) || currentSlotTime.isAtSameMomentAs(loopEndTime)) {
      if (slotIndex >= 48) break; // Safety break for max 48 half-hour slots

      tz.TZDateTime scheduleFor = currentSlotTime;
      // If this slot time for today has already passed, schedule it for the same slot time tomorrow
      if (scheduleFor.isBefore(now)) {
        scheduleFor = scheduleFor.add(const Duration(days: 1));
      }

      final quote = _loadedQuotes[_random.nextInt(_loadedQuotes.length)];
      final notificationId = _positivityReminderBaseId + slotIndex;

      await _scheduleNotificationWithFallback(
        id: notificationId,
        title: "✨ Daily Positivity", // You can make title dynamic too
        body: "\"${quote.text}\" - ${quote.author}",
        scheduledDate: scheduleFor,
        notificationDetails: _getNotificationDetails(
            _thoughtsChannelId, _thoughtsChannelName, _thoughtsChannelDescription),
        matchDateTimeComponents: DateTimeComponents.time, // Important for daily repetition at this slot time
        payload: 'positivity_reminder_payload_$notificationId',
      );

      currentSlotTime = currentSlotTime.add(const Duration(minutes: 30));
      slotIndex++;
    }
    // Corrected TimeOfDay.format usage with BuildContext (placeholder, will be removed)
    // This print statement was causing the runtime error, as BuildContext isn't available here.
    // For debugging, format TimeOfDay to string manually if needed without BuildContext.
    String startTimeStr = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
    String endTimeStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
    print("Scheduled $slotIndex positivity reminders between $startTimeStr and $endTimeStr.");
  }

  Future<void> cancelPositivityReminders() async {
    for (int i = 0; i < 48; i++) { // Assuming max 48 half-hour slots
      await flutterLocalNotificationsPlugin.cancel(_positivityReminderBaseId + i);
    }
    print("Cancelled all Positivity Reminders.");
  }

  Future<void> scheduleDailyChallengeNotification({
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    await _scheduleNotificationWithFallback(
      id: _dailyChallengeNotificationId,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(time),
      notificationDetails: _getNotificationDetails(_dailyChallengeChannelId,
          _dailyChallengeChannelName, _dailyChallengeChannelDescription),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_challenge_payload',
    );
  }

  // This method was causing the "not defined" error because it was in your main thought process
  // but not in the class. It is correctly defined now.
  Future<void> cancelNotificationById(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    print("Cancelled notification with ID: $id");
  }

  Future<void> cancelAllNotifications() async { // For general use
    await flutterLocalNotificationsPlugin.cancelAll();
    print("Cancelled ALL notifications (general).");
  }
}
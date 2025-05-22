import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// intl is not directly needed here because DayAvailability.formatTimeOfDay handles its own DateFormat.
// import 'package:intl/intl.dart';

import '../models/day_availability_model.dart'; // <-- IMPORT THE SHARED MODEL

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _cardRadius = 16.0;
// --- End Constants ---

class ManageAvailabilityScreen extends StatefulWidget {
  const ManageAvailabilityScreen({Key? key}) : super(key: key);

  @override
  State<ManageAvailabilityScreen> createState() => _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  User? _currentUser;
  bool _isLoading = true;
  String _error = '';

  final Map<String, DayAvailability> _weeklySchedule = {};
  final List<String> _daysOfWeek = [
    "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
  ];
  final Map<String, String> _dayDisplayNames = {
    "monday": "Monday", "tuesday": "Tuesday", "wednesday": "Wednesday",
    "thursday": "Thursday", "friday": "Friday", "saturday": "Saturday", "sunday": "Sunday"
  };

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _initializeSchedule();
    if (_currentUser != null) {
      _loadSchedule();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "User not authenticated. Please log in.";
        });
      }
    }
  }

  void _initializeSchedule() {
    for (var dayKey in _daysOfWeek) {
      _weeklySchedule[dayKey] = DayAvailability(isWorking: false);
    }
  }

  Future<void> _loadSchedule() async {
    // ... (This method should be correct from the previous version, ensure it uses DayAvailability.fromJson) ...
    if (_currentUser == null || !mounted) return;
    setState(() { _isLoading = true; _error = ''; });
    try {
      final docRef = FirebaseFirestore.instance.collection('counselorSchedules').doc(_currentUser!.uid);
      final docSnap = await docRef.get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        final weeklyData = data['weeklyAvailability'] as Map<String, dynamic>?;
        if (weeklyData != null) {
          for (var dayKey in _daysOfWeek) {
            _weeklySchedule[dayKey] = DayAvailability.fromJson(weeklyData[dayKey] as Map<String, dynamic>?);
          }
        } else {
          _initializeSchedule();
        }
      } else {
        _initializeSchedule();
      }
    } catch (e, s) {
      print("Error loading schedule: $e\n$s");
      if (mounted) setState(() { _error = "Failed to load schedule."; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    // ... (This method should be correct from the previous version, uses DayAvailability.toJson) ...
    // Ensure it uses the themed SnackBars correctly.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text( "Authentication error. Cannot save.", style: TextStyle(color: colorScheme.onErrorContainer, fontFamily: _primaryFontFamily), ), backgroundColor: colorScheme.errorContainer, behavior: SnackBarBehavior.floating, margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).size.height * 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)), ));
      return;
    }
    setState(() { _isLoading = true; _error = ''; });
    Map<String, dynamic> weeklyScheduleForFirestore = {};
    _weeklySchedule.forEach((dayKey, availability) {
      weeklyScheduleForFirestore[dayKey] = availability.toJson();
    });
    try {
      await FirebaseFirestore.instance.collection('counselorSchedules').doc(_currentUser!.uid).set({
        'counselorId': _currentUser!.uid, 'weeklyAvailability': weeklyScheduleForFirestore, 'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text("Availability schedule saved!", style: TextStyle(color: colorScheme.onPrimary, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500)), backgroundColor: colorScheme.primary, behavior: SnackBarBehavior.floating, elevation: 4.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)), margin: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).size.height * 0.05), padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), ));
      }
    } catch (e, s) {
      print("Error saving schedule: $e\n$s");
      if (mounted) {
        setState(() { _error = "Failed to save schedule."; });
        ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text("Error saving schedule: ${e.toString()}", style: TextStyle(color: colorScheme.onErrorContainer, fontFamily: _primaryFontFamily)), backgroundColor: colorScheme.errorContainer, behavior: SnackBarBehavior.floating, margin: EdgeInsets.fromLTRB(16,0,16, MediaQuery.of(context).size.height * 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)), ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(BuildContext context, String dayKey, bool isStartTime) async {
    final DayAvailability currentAvailability = _weeklySchedule[dayKey]!; // This is a copy
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    TimeOfDay? initialTime;

    if (isStartTime) {
      initialTime = currentAvailability.startTime ?? const TimeOfDay(hour: 9, minute: 0);
    } else {
      initialTime = currentAvailability.endTime ?? const TimeOfDay(hour: 17, minute: 0);
      if (currentAvailability.startTime != null) {
        if (initialTime.hour < currentAvailability.startTime!.hour ||
            (initialTime.hour == currentAvailability.startTime!.hour && initialTime.minute <= currentAvailability.startTime!.minute)) {
          initialTime = TimeOfDay(hour: currentAvailability.startTime!.hour + 1, minute: currentAvailability.startTime!.minute);
          if (initialTime.hour >= 24) initialTime = const TimeOfDay(hour: 23, minute: 59);
        }
      }
    }

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(backgroundColor: theme.dialogBackgroundColor),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary)),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && mounted) {
      setState(() {
        if (isStartTime) {
          TimeOfDay? newEndTime = currentAvailability.endTime;
          if (currentAvailability.endTime != null &&
              (pickedTime.hour > currentAvailability.endTime!.hour ||
                  (pickedTime.hour == currentAvailability.endTime!.hour && pickedTime.minute >= currentAvailability.endTime!.minute)
              )) {
            // If new start time is after or same as current end time, adjust end time
            int newEndHour = pickedTime.hour + 1;
            newEndTime = TimeOfDay(hour: newEndHour > 23 ? 23 : newEndHour, minute: pickedTime.minute);
          }
          _weeklySchedule[dayKey] = currentAvailability.copyWith(
              startTime: () => pickedTime,
              endTime: () => newEndTime // Pass potentially adjusted newEndTime
          );
        } else { // Picking end time
          if (currentAvailability.startTime != null &&
              (pickedTime.hour < currentAvailability.startTime!.hour ||
                  (pickedTime.hour == currentAvailability.startTime!.hour && pickedTime.minute <= currentAvailability.startTime!.minute)
              )) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("End time must be after start time.", style: TextStyle(color: colorScheme.onErrorContainer, fontFamily: _primaryFontFamily)),
                  backgroundColor: colorScheme.errorContainer,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.fromLTRB(16,0,16, MediaQuery.of(context).size.height * 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
                )
            );
            return;
          }
          _weeklySchedule[dayKey] = currentAvailability.copyWith(endTime: () => pickedTime);
        }
      });
    }
  }

  Widget _buildDayRow(BuildContext context, String dayKey) {
    // Ensure _weeklySchedule[dayKey] is never null by checking or initializing properly
    final DayAvailability availability = _weeklySchedule[dayKey] ?? DayAvailability();
    final theme = Theme.of(context);
    final String dayDisplayName = _dayDisplayNames[dayKey] ?? dayKey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Card(
        elevation: 1.5,
        shadowColor: theme.shadowColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius * 0.75)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dayDisplayName, style: theme.textTheme.titleMedium?.copyWith(fontFamily: _primaryFontFamily, fontWeight: FontWeight.w600)),
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: availability.isWorking,
                      onChanged: (bool value) {
                        setState(() {
                          // Use copyWith to update the immutable DayAvailability object
                          _weeklySchedule[dayKey] = availability.copyWith(
                            isWorking: value,
                            startTime: () => value && availability.startTime == null ? const TimeOfDay(hour: 9, minute: 0) : (value ? availability.startTime : null),
                            endTime: () => value && availability.endTime == null ? const TimeOfDay(hour: 17, minute: 0) : (value ? availability.endTime : null),
                          );
                        });
                      },
                      activeColor: theme.colorScheme.primary,
                      inactiveThumbColor: theme.colorScheme.outline,
                      inactiveTrackColor: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
              if (availability.isWorking) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildTimePickerButton(
                          context: context,
                          label: "Start Time",
                          // Use time.format(context) for display
                          timeToDisplay: availability.startTime?.format(context),
                          onPressed: () => _pickTime(context, dayKey, true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTimePickerButton(
                          context: context,
                          label: "End Time",
                          // Use time.format(context) for display
                          timeToDisplay: availability.endTime?.format(context),
                          onPressed: () => _pickTime(context, dayKey, false),
                        ),
                      ),
                    ],
                  ),
                ),
                if (availability.isWorking && availability.startTime != null && availability.endTime != null &&
                    (availability.startTime!.hour > availability.endTime!.hour ||
                        (availability.startTime!.hour == availability.endTime!.hour && availability.startTime!.minute >= availability.endTime!.minute)
                    ))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "End time must be after start time.",
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 12.5, fontFamily: _primaryFontFamily),
                    ),
                  ),
              ] else ... [
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text("Not working this day", style: TextStyle(fontFamily: _primaryFontFamily, color: theme.hintColor, fontSize: 13)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  // Updated _buildTimePickerButton to accept a pre-formatted string for display
  Widget _buildTimePickerButton({
    required BuildContext context,
    required String label,
    required String? timeToDisplay, // Changed from TimeOfDay? to String?
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(fontFamily: _primaryFontFamily, color: theme.hintColor)),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
          ),
          onPressed: onPressed,
          child: Text(
            timeToDisplay ?? "Set Time", // Use the passed formatted string
            style: TextStyle(
              fontFamily: _primaryFontFamily,
              fontSize: 16,
              color: timeToDisplay != null ? theme.colorScheme.primary : theme.hintColor,
              fontWeight: timeToDisplay != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (AppBar and main body structure should be correct from previous version) ...
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar( /* ... AppBar Details ... */
        title: Text('Manage Weekly Availability', style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, color: theme.appBarTheme.titleTextStyle?.color)),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: 1.0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: theme.iconTheme.color?.withOpacity(0.7)),
            tooltip: "Info",
            onPressed: () { /* ... Info SnackBar ... */
              ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text( "Set your typical working days and hours. Specific date overrides can be managed separately (feature coming soon).", style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.w500, color: theme.colorScheme.onSecondaryContainer) ), backgroundColor: theme.colorScheme.secondaryContainer, behavior: SnackBarBehavior.floating, margin: EdgeInsets.fromLTRB(16,0,16, MediaQuery.of(context).size.height * 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)), ));
            },
          )
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty ? Center(child: Padding( padding: const EdgeInsets.all(16.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48), const SizedBox(height: 10), Text(_error, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 16, fontFamily: _primaryFontFamily)), const SizedBox(height: 10), ElevatedButton(onPressed: _loadSchedule, child: const Text("Retry")) ],), ))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text( "Set your standard working hours for each day of the week.", style: theme.textTheme.titleMedium?.copyWith(fontFamily: _primaryFontFamily, color: theme.hintColor), textAlign: TextAlign.center, ),
            const SizedBox(height: 20),
            ..._daysOfWeek.map((dayKey) => _buildDayRow(context, dayKey)).toList(),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)) : const Icon(Icons.save_alt_rounded),
              label: Text(_isLoading ? 'Saving...' : 'Save Schedule'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontFamily: _primaryFontFamily, fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius))
              ),
              onPressed: _isLoading ? null : _saveSchedule,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
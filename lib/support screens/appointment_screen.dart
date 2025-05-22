// lib/support screens/appointment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import 'chat_screen.dart';
import '../theme/theme_provider.dart';
import '../profile_screen.dart'; // For navigating to user's profile
import '../models/counselor_model.dart';
import '../models/appointment_model.dart';
import '../models/day_availability_model.dart';
import '../widgets/bouncing_widget.dart'; // Import BouncingWidget

import 'package:table_calendar/table_calendar.dart'; // For the date picker

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _cardRadius = 18.0;
const double _tabSelectorRadius = 25.0;
const Duration _tabAnimationDuration = Duration(milliseconds: 350);
const double _conceptualOverlap = 20.0; // For title overlap effect

final List<TimeOfDay> _predefinedBusinessSlots = [
  const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 10, minute: 0),
  const TimeOfDay(hour: 11, minute: 0), const TimeOfDay(hour: 12, minute: 0),
  const TimeOfDay(hour: 14, minute: 0), const TimeOfDay(hour: 15, minute: 0),
  const TimeOfDay(hour: 16, minute: 0), const TimeOfDay(hour: 17, minute: 0),
];
const Duration _bookingLeadTime = Duration(hours: 2);
const int _maxBookingHorizonDays = 60;
// --- End Constants ---

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  List<Counselor> _counselors = [];
  List<Appointment> _userAppointments = [];
  bool _isLoadingCounselors = true;
  bool _isLoadingUserAppointments = true;
  String _counselorError = '';
  String _userAppointmentsError = '';
  User? _currentUser;
  String? _currentUserName;
  bool _isProcessingBooking = false;
  String? _cancellingAppointmentId;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _currentUser = _auth.currentUser;
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setStateIfMounted(() {
      _isLoadingCounselors = true;
      _isLoadingUserAppointments = true;
      _counselorError = '';
      _userAppointmentsError = '';
    });
    await _fetchCurrentUserName();
    await Future.wait([
      _fetchCounselors(),
      _fetchUserAppointments(),
    ]);
  }

  Future<void> _fetchCurrentUserName() async {
    if (_currentUser == null || !mounted) return;
    try {
      final doc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (!mounted) return;
      if (doc.exists && doc.data() != null && (doc.data() as Map).containsKey('name')) {
        _currentUserName = (doc.data() as Map)['name'] as String?;
      } else {
        _currentUserName = _currentUser?.displayName ?? "User";
      }
    } catch (e) {
      print("[AppointmentScreen] Error fetching current user's name: $e");
      if (mounted) _currentUserName = _currentUser?.displayName ?? "User";
    }
  }

  Future<void> _fetchCounselors() async {
    if (!mounted) return;
    setStateIfMounted(() => _isLoadingCounselors = true);
    try {
      QuerySnapshot snapshot = await _firestore.collection('counselors').orderBy('name').get();
      if (!mounted) return;
      _counselors = snapshot.docs.map((doc) {
        try {
          return Counselor.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        } catch (e) {
          print("[AppointmentScreen] Error parsing counselor ${doc.id}: $e. Data: ${doc.data()}");
          return null;
        }
      }).whereType<Counselor>().toList();
      _counselorError = '';
    } catch (e, s) {
      print("[AppointmentScreen] Error fetching counselors: $e\n$s");
      if (mounted) _counselorError = "Could not load counselors. Please try again.";
    } finally {
      if (mounted) setStateIfMounted(() => _isLoadingCounselors = false);
    }
  }

  Future<void> _fetchUserAppointments() async {
    if (!mounted || _currentUser == null) {
      if (mounted) setStateIfMounted(() => _isLoadingUserAppointments = false);
      return;
    }
    setStateIfMounted(() => _isLoadingUserAppointments = true);
    try {
      final snapshot = await _firestore.collection('appointments')
          .where('userId', isEqualTo: _currentUser!.uid)
      // General sort, specific sorts will be applied in view
          .orderBy('requestedDateTime', descending: true)
          .get();
      if (!mounted) return;
      _userAppointments = snapshot.docs.map((doc) {
        try {
          return Appointment.fromFirestore(doc);
        } catch (e) {
          print("[AppointmentScreen] Error parsing user appointment ${doc.id}: $e. Data: ${doc.data()}");
          return null;
        }
      }).whereType<Appointment>().toList();
      _userAppointmentsError = '';
    } catch (e, s) {
      print("[AppointmentScreen] Error fetching user appointments: $e\n$s");
      if (mounted) _userAppointmentsError = "Could not load your appointments. Please try again.";
    } finally {
      if (mounted) setStateIfMounted(() => _isLoadingUserAppointments = false);
    }
  }

  void setStateIfMounted(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<Map<String, DayAvailability>> _fetchCounselorWeeklySchedule(String counselorId) async {
    Map<String, DayAvailability> schedule = {};
    try {
      DocumentSnapshot docSnap = await _firestore.collection('counselorSchedules').doc(counselorId).get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data() as Map<String, dynamic>;
        final weeklyData = data['weeklyAvailability'] as Map<String, dynamic>?;
        if (weeklyData != null) {
          weeklyData.forEach((dayKey, dayJson) {
            if (dayJson is Map<String, dynamic>) {
              schedule[dayKey.toLowerCase()] = DayAvailability.fromJson(dayJson);
            }
          });
        }
      }
    } catch(e) {
      print("[AppointmentScreen - Avail] Error fetching weekly schedule for $counselorId: $e");
    }
    const List<String> days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
    for (var day in days) {
      schedule.putIfAbsent(day, () => DayAvailability(isWorking: false));
    }
    return schedule;
  }

  Future<List<TimeOfDay>> _getConfirmedAppointmentTimesForDay(String counselorId, DateTime date) async {
    List<TimeOfDay> confirmedTimes = [];
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('appointments')
          .where('counselorId', isEqualTo: counselorId)
          .where('status', whereIn: ['confirmed', 'pending']) // Consider pending as booked for availability
          .where('requestedDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('requestedDateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = (data['status'] == 'confirmed' ? data['confirmedDateTime'] : data['requestedDateTime']) as Timestamp?;
        if (ts != null) {
          final dt = ts.toDate();
          confirmedTimes.add(TimeOfDay.fromDateTime(dt));
        }
      }
    } catch(e) {
      print("[AppointmentScreen - Avail] Error fetching confirmed/pending appt times for $counselorId on ${DateFormat('yyyy-MM-dd').format(date)}: $e");
    }
    return confirmedTimes;
  }

  Future<void> _handleBookingRequest(Counselor counselor) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to book.")));
      return;
    }
    if (_isProcessingBooking) return;

    setStateIfMounted(() => _isProcessingBooking = true);
    final DateTime? selectedDateTimeSlot = await _showAdvancedDateTimePickerSheet(context, counselor);

    if (selectedDateTimeSlot != null && mounted) {
      await _createRealAppointmentRequest(counselor, selectedDateTimeSlot);
    } else {
      print("[AppointmentScreen] Advanced Date/Time slot selection cancelled or failed.");
    }
    if (mounted) setStateIfMounted(() => _isProcessingBooking = false);
  }

  Future<DateTime?> _showAdvancedDateTimePickerSheet(BuildContext context, Counselor counselor) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Gradient sheetGradient = LinearGradient( colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight);
    final Color onGradientColor = ThemeData.estimateBrightnessForColor(themeProvider.currentAccentGradient.first) == Brightness.dark ? Colors.white : Colors.black87;

    DateTime focusedDayForCalendar = DateTime.now();
    DateTime? selectedDate;
    TimeOfDay? selectedTimeSlot;
    List<TimeOfDay> availableTimeSlotsForDay = [];
    bool isLoadingSlots = false;
    Map<String, DayAvailability> counselorWeeklySchedule = {};
    bool isConfirmSlotEnabled = false;

    counselorWeeklySchedule = await _fetchCounselorWeeklySchedule(counselor.id);
    selectedDate = _findInitialEnabledDay(focusedDayForCalendar, counselorWeeklySchedule, counselor.id);
    if (selectedDate != null) {
      focusedDayForCalendar = selectedDate!;
    }

    String getDayKey(DateTime date) => DateFormat('EEEE').format(date).toLowerCase();

    Future<void> updateAvailableSlots(DateTime date, StateSetter setSheetState) async {
      if(!mounted) return;
      setSheetState(() {
        isLoadingSlots = true;
        availableTimeSlotsForDay.clear();
        selectedTimeSlot = null;
        isConfirmSlotEnabled = false;
      });

      DayAvailability daySpecificSchedule = counselorWeeklySchedule[getDayKey(date)] ?? DayAvailability();
      if (!daySpecificSchedule.isWorking || daySpecificSchedule.startTime == null || daySpecificSchedule.endTime == null) {
        if(mounted) setSheetState(() => isLoadingSlots = false);
        return;
      }

      List<TimeOfDay> bookedOrPendingTimes = await _getConfirmedAppointmentTimesForDay(counselor.id, date);
      List<TimeOfDay> tempSlots = [];
      DateTime nowWithLeadTime = DateTime.now().add(_bookingLeadTime);
      DateTime counselorWorkStartDateTime = DateTime(date.year, date.month, date.day, daySpecificSchedule.startTime!.hour, daySpecificSchedule.startTime!.minute);
      DateTime counselorWorkEndDateTime = DateTime(date.year, date.month, date.day, daySpecificSchedule.endTime!.hour, daySpecificSchedule.endTime!.minute);

      for (var slotStart in _predefinedBusinessSlots) {
        DateTime slotStartFullDateTime = DateTime(date.year, date.month, date.day, slotStart.hour, slotStart.minute);

        if (slotStartFullDateTime.isBefore(counselorWorkStartDateTime) ||
            slotStartFullDateTime.isAfter(counselorWorkEndDateTime) ||
            slotStartFullDateTime.isAtSameMomentAs(counselorWorkEndDateTime)) {
          continue;
        }
        // Ensure slot is not in the past (considering lead time)
        if (date.isAtSameMomentAs(DateTime(nowWithLeadTime.year, nowWithLeadTime.month, nowWithLeadTime.day)) &&
            slotStartFullDateTime.isBefore(nowWithLeadTime)) {
          continue;
        }

        bool isBooked = bookedOrPendingTimes.any((bookedTime) =>
        bookedTime.hour == slotStart.hour && bookedTime.minute == slotStart.minute);
        if (isBooked) continue;
        tempSlots.add(slotStart);
      }
      if(mounted) {
        setSheetState(() {
          availableTimeSlotsForDay = tempSlots;
          isLoadingSlots = false;
        });
      }
    }
    // Initial call to load slots for the initially selected/default date
    /*if (selectedDate != null) {
      // Using addPostFrameCallback to ensure it runs after the current build cycle
      // where setSheetState might be called from the builder.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ctx as StatefulElement).mounted) { // Check if sheet context is still mounted
          updateAvailableSlots(selectedDate!, (fn) { if ((ctx as StatefulElement).mounted) { setSheetState(fn); } });
        }
      });
    }*/


    return await showModalBottomSheet<DateTime>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25.0))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            isConfirmSlotEnabled = selectedDate != null && selectedTimeSlot != null;

            // This logic for initial slot loading might be better placed right after
            // `selectedDate` gets its initial value or when the sheet first builds.
            // Using WidgetsBinding.instance.addPostFrameCallback ensures it runs after the build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (selectedDate != null && availableTimeSlotsForDay.isEmpty && !isLoadingSlots && (ctx as StatefulElement).mounted) {
                updateAvailableSlots(selectedDate!, (fn) { if ((ctx as StatefulElement).mounted) { setSheetState(fn); } });
              } else if (selectedDate == null && !isLoadingSlots && (ctx as StatefulElement).mounted) {
                if ((ctx as StatefulElement).mounted) setSheetState(() => isLoadingSlots = false);
              }
            });

            return Container(
              decoration: BoxDecoration( gradient: sheetGradient, borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)), ),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 10.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration( color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30), ),
                      child: Text(
                        selectedDate != null
                            ? (selectedTimeSlot != null
                            ? DateFormat('EEE, MMM d  –  hh:mm a').format(DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTimeSlot!.hour, selectedTimeSlot!.minute))
                            : DateFormat('EEE, MMM d, yyyy').format(selectedDate!) + " - Select a slot"
                        )
                            : "Select Date & Time",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: onGradientColor, fontFamily: _primaryFontFamily),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TableCalendar(
                      firstDay: DateTime.now(),
                      lastDay: DateTime.now().add(Duration(days: _maxBookingHorizonDays)),
                      focusedDay: focusedDayForCalendar,
                      currentDay: DateTime.now(),
                      selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                      enabledDayPredicate: (day) => _isDayEnabled(day, counselorWeeklySchedule, counselor.id),
                      onDaySelected: (newlySelectedDate, newFocusedDay) {
                        if ((ctx as StatefulElement).mounted) {
                          setSheetState(() {
                            selectedDate = newlySelectedDate;
                            focusedDayForCalendar = newFocusedDay;
                            selectedTimeSlot = null;
                            availableTimeSlotsForDay.clear();
                            isConfirmSlotEnabled = false;
                          });
                          updateAvailableSlots(newlySelectedDate, (fn) { if ((ctx as StatefulElement).mounted) { setSheetState(fn); } });
                        }
                      },
                      headerStyle: HeaderStyle( formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onGradientColor, fontFamily: _primaryFontFamily), leftChevronIcon: Icon(Icons.chevron_left, color: onGradientColor.withOpacity(0.8)), rightChevronIcon: Icon(Icons.chevron_right, color: onGradientColor.withOpacity(0.8)), ),
                      calendarStyle: CalendarStyle( selectedDecoration: BoxDecoration( color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0,2))]), selectedTextStyle: TextStyle(color: themeProvider.currentAccentColor, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily), todayDecoration: BoxDecoration( border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5), shape: BoxShape.circle, ), todayTextStyle: TextStyle(color: onGradientColor, fontFamily: _primaryFontFamily), defaultTextStyle: TextStyle(color: onGradientColor, fontFamily: _primaryFontFamily), weekendTextStyle: TextStyle(color: onGradientColor.withOpacity(0.8), fontFamily: _primaryFontFamily), outsideTextStyle: TextStyle(color: onGradientColor.withOpacity(0.4), fontFamily: _primaryFontFamily), disabledTextStyle: TextStyle(color: onGradientColor.withOpacity(0.3), fontFamily: _primaryFontFamily, decoration: TextDecoration.lineThrough),),
                      daysOfWeekStyle: DaysOfWeekStyle( weekdayStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12, fontFamily: _primaryFontFamily), weekendStyle: TextStyle(color: onGradientColor.withOpacity(0.7), fontSize: 12, fontFamily: _primaryFontFamily), ),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 15, color: onGradientColor.withOpacity(0.2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("Available Slots", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onGradientColor, fontFamily: _primaryFontFamily)),
                    ),
                    if (isLoadingSlots)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white70))),
                    if (!isLoadingSlots && availableTimeSlotsForDay.isEmpty && selectedDate != null)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text("No available slots for this day.", style: TextStyle(color: onGradientColor.withOpacity(0.85), fontFamily: _primaryFontFamily))),
                    if (!isLoadingSlots && availableTimeSlotsForDay.isNotEmpty)
                      Wrap(
                        spacing: 10.0, runSpacing: 10.0, alignment: WrapAlignment.center,
                        children: availableTimeSlotsForDay.map((slot) {
                          final bool isSelected = selectedTimeSlot == slot;
                          return BouncingWidget(
                            onPressed: () {
                              if ((ctx as StatefulElement).mounted) {
                                setSheetState((){
                                  selectedTimeSlot = isSelected ? null : slot;
                                  isConfirmSlotEnabled = selectedDate != null && selectedTimeSlot != null;
                                });
                              }
                            },
                            child: ChoiceChip(
                              label: Text(MaterialLocalizations.of(context).formatTimeOfDay(slot, alwaysUse24HourFormat: false)),
                              selected: isSelected,
                              onSelected: (bool newSelection) {
                                if ((ctx as StatefulElement).mounted) {
                                  setSheetState((){
                                    selectedTimeSlot = newSelection ? slot : null;
                                    isConfirmSlotEnabled = selectedDate != null && selectedTimeSlot != null;
                                  });
                                }
                              },
                              backgroundColor: Colors.white.withOpacity(0.15),
                              selectedColor: Colors.white,
                              labelStyle: TextStyle( color: isSelected ? themeProvider.currentAccentColor : onGradientColor, fontFamily: _primaryFontFamily, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14 ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: isSelected ? BorderSide(color: themeProvider.currentAccentColor.withOpacity(0.5), width: 1.5) : BorderSide.none),
                              elevation: isSelected ? 3 : 1,
                              pressElevation: 5,
                            ),
                          );
                        }).toList(),
                      ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        BouncingWidget(
                          onPressed: () => Navigator.pop(context),
                          child: TextButton.icon(
                              icon: Icon(Icons.close_rounded, color: onGradientColor.withOpacity(0.8)),
                              label: Text("Cancel", style: TextStyle(color: onGradientColor.withOpacity(0.8), fontFamily: _primaryFontFamily)),
                              onPressed: null
                          ),
                        ),
                        BouncingWidget(
                          onPressed: isConfirmSlotEnabled ? () {
                            final finalDateTime = DateTime( selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTimeSlot!.hour, selectedTimeSlot!.minute );
                            Navigator.pop(context, finalDateTime);
                          } : null,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline_rounded),
                            label: const Text("Confirm Slot"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.transparent,
                              disabledBackgroundColor: isConfirmSlotEnabled
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.1),
                              disabledForegroundColor: isConfirmSlotEnabled
                                  ? (ThemeData.estimateBrightnessForColor(themeProvider.currentAccentColor) == Brightness.dark
                                  ? Colors.white
                                  : Colors.black)
                                  : onGradientColor.withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              textStyle: const TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: isConfirmSlotEnabled ? 2 : 0,
                            ),
                            onPressed: null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  DateTime? _findInitialEnabledDay(DateTime startDate, Map<String, DayAvailability> weeklySchedule, String counselorId) {
    DateTime currentDate = startDate;
    for (int i = 0; i < _maxBookingHorizonDays; i++) {
      if (_isDayEnabled(currentDate, weeklySchedule, counselorId)) {
        return currentDate;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return null;
  }

  bool _isDayPast(DateTime day) {
    final now = DateTime.now();
    return day.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool _isDayEnabled(DateTime day, Map<String, DayAvailability> weeklySchedule, String counselorId) {
    if (_isDayPast(day)) return false;
    if (day.isAfter(DateTime.now().add(Duration(days: _maxBookingHorizonDays)))) return false;
    final dayKey = DateFormat('EEEE').format(day).toLowerCase();
    final DayAvailability? counselorDaySetting = weeklySchedule[dayKey];
    if (counselorDaySetting == null || !counselorDaySetting.isWorking || counselorDaySetting.startTime == null || counselorDaySetting.endTime == null) {
      return false;
    }
    DateTime nowWithLeadTime = DateTime.now().add(_bookingLeadTime);
    DateTime firstPossibleSlotTime = DateTime(day.year, day.month, day.day, counselorDaySetting.startTime!.hour, counselorDaySetting.startTime!.minute);
    DateTime lastPossibleSlotTime = DateTime(day.year, day.month, day.day, counselorDaySetting.endTime!.hour, counselorDaySetting.endTime!.minute);

    // Check if any predefined business slot falls within counselor's working hours and after lead time for the given day
    for (var predefinedSlot in _predefinedBusinessSlots) {
      DateTime slotFullDateTime = DateTime(day.year, day.month, day.day, predefinedSlot.hour, predefinedSlot.minute);
      // Check if slot is within counselor's start and end time
      bool isWithinCounselorHours = !slotFullDateTime.isBefore(firstPossibleSlotTime) &&
          slotFullDateTime.isBefore(lastPossibleSlotTime); // Use isBefore for end time to allow slots that end exactly at endTime

      // If the day being checked is today, ensure the slot is after the lead time from now.
      // If the day is in the future, this lead time check is not against 'now' but against the start of that day.
      bool isAfterLeadTime = true;
      if (isSameDay(day, DateTime.now())) {
        isAfterLeadTime = slotFullDateTime.isAfter(nowWithLeadTime);
      }


      if (isWithinCounselorHours && isAfterLeadTime) {
        return true; // At least one slot is potentially available
      }
    }
    return false;
  }

  Future<void> _createRealAppointmentRequest(Counselor counselor, DateTime requestedDateTime) async {
    if (_currentUser == null) return;
    if (_currentUserName == null || _currentUserName!.isEmpty || _currentUserName == "User") {
      await _fetchCurrentUserName();
    }
    final dataToSave = {
      'userId': _currentUser!.uid,
      'userName': _currentUserName ?? _currentUser?.displayName ?? 'User',
      'counselorId': counselor.id,
      'counselorName': counselor.name,
      'requestedDateTime': Timestamp.fromDate(requestedDateTime),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'confirmedDateTime': null,
      'meetingLink': null,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('appointments').add(dataToSave);
      if (mounted) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Request sent to ${counselor.name} for ${DateFormat('MMM d, hh:mm a').format(requestedDateTime)}",
              style: TextStyle(color: colorScheme.onPrimaryContainer)
          ),
          backgroundColor: colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ));
        await _fetchUserAppointments(); // Refresh the list
        _tabController.animateTo(1); // Switch to status view
      }
    } catch (e, s) {
      print("[AppointmentScreen] Error creating appointment request: $e\n$s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send request: ${e.toString()}")));
      }
    }
  }

  List<BoxShadow> _getAppointmentCardShadow(BuildContext context) {
    final theme = Theme.of(context);
    return [
      BoxShadow(
        color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.22 : 0.10),
        blurRadius: 20.0,
        spreadRadius: 0.5,
        offset: const Offset(0, 8.0),
      ),
      BoxShadow(
        color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.12 : 0.06),
        blurRadius: 10.0,
        offset: const Offset(0, 4.0),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: theme.brightness == Brightness.light ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: theme.brightness == Brightness.light ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding + 10, left: 16, right: 16, bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildProfileButton(context), // Changed from settings to profile
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0, bottom: _conceptualOverlap + 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    "APPOINTMENTS",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 45, // Adjusted size
                      fontWeight: FontWeight.w900,
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.displayLarge?.color?.withOpacity(0.055),
                      height: 0.8,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -2), // Adjusted offset
                    child: Text(
                      "Book & Manage",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: _primaryFontFamily,
                        fontSize: 25, // Adjusted size
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color?.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 15),
              child: _buildTabSelector(context),
            ),
          ),
          SliverFillRemaining( // Ensures TabBarView fills remaining space
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBookingView(context),
                _buildStatusView(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.8);
    final profileButtonBg = theme.brightness == Brightness.light ? Colors.grey.shade200 : theme.colorScheme.surfaceContainerHighest;

    return BouncingWidget(
      onPressed: () {
        // Navigate to the ProfileScreen (user's own profile)
        Navigator.pop(context);
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(builder: (context) => const ProfileScreen()),
        // );
      },
      child: SizedBox(
        width: 44, height: 44,
        child: Material(
          color: profileButtonBg,
          borderRadius: BorderRadius.circular(12.0),
          clipBehavior: Clip.antiAlias,
          elevation: 1.0,
          shadowColor: theme.shadowColor.withOpacity(0.1),
          // Use a generic profile icon or back arrow if preferred
          child: Icon(Icons.arrow_back_ios_new, color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final int numberOfTabs = 2; // For "Book" and "Status"

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0), // Or adjust as needed
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tabWidth = constraints.maxWidth / numberOfTabs;
          return Container(
            height: 48, // Standard height for tab bar
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withOpacity(0.07) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(_tabSelectorRadius),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedAlign(
                  alignment: _tabController.index == 0 ? Alignment.centerLeft : Alignment.centerRight,
                  duration: _tabAnimationDuration,
                  curve: Curves.fastOutSlowIn,
                  child: Container(
                    width: tabWidth,
                    height: 48,
                    decoration: BoxDecoration(
                        color: colorScheme.primary, // Selected tab background
                        borderRadius: BorderRadius.circular(_tabSelectorRadius),
                        boxShadow: [
                          BoxShadow(
                              color: colorScheme.primary.withOpacity(0.35),
                              blurRadius: 9,
                              spreadRadius: 1,
                              offset: const Offset(0, 3))
                        ]),
                  ),
                ),
                Row(
                  children: [
                    _buildTabButton(context, "Book", 0, tabWidth),
                    _buildTabButton(context, "Status", 1, tabWidth),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String text, int index, double tabWidth) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final animation = _tabController.animation ?? kAlwaysDismissedAnimation;

    // Calculate color based on animation value for smooth transition
    final double selectValue = (1.0 - (animation.value - index).abs()).clamp(0.0, 1.0);

    final Color textColor = Color.lerp(
        theme.textTheme.bodyLarge?.color?.withOpacity(0.85) ?? colorScheme.onSurface.withOpacity(0.85), // Unselected text color
        colorScheme.onPrimary, // Selected text color
        selectValue
    )!;
    final FontWeight fontWeight = FontWeight.lerp(FontWeight.w500, FontWeight.bold, selectValue)!;

    return Expanded(
      child: BouncingWidget( // Optional: wrap with BouncingWidget for tap animation
        onPressed: () {
          if (_tabController.index != index) {
            _tabController.animateTo(index);
          }
        },
        child: Container(
          width: tabWidth,
          height: double.infinity,
          color: Colors.transparent, // Important for stack effect
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontFamily: _primaryFontFamily,
              fontSize: 15,
              fontWeight: fontWeight,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }


  Widget _buildBookingView(BuildContext context) {
    if (_isLoadingCounselors) { return const Center(child: CircularProgressIndicator()); }
    if (_counselorError.isNotEmpty) { return Center(child: Text(_counselorError));}
    if (_counselors.isEmpty) { return const Center(child: Text("No counselors available at the moment."));}

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 90), // Padding for content and bottom nav bar
      itemCount: _counselors.length,
      itemBuilder: (context, index) {
        final counselor = _counselors[index];
        // Using a Container for custom shadow and rounded corners
        return Container(
          margin: const EdgeInsets.only(bottom: 20.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor, // Use theme's card color
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: _getAppointmentCardShadow(context), // Your custom shadow
          ),
          child: _buildCounselorCardContent(context, counselor),
        );
      },
    );
  }

  Widget _buildCounselorCardContent(BuildContext context, Counselor counselor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final User? localCurrentUser = _currentUser;

    bool canRequestSlot = !_isProcessingBooking;
    bool canChat = localCurrentUser != null;


    return ClipRRect( // Clip content to rounded corners
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: theme.hoverColor, // Subtle background for avatar
                  backgroundImage: (counselor.photoUrl.isNotEmpty)
                      ? CachedNetworkImageProvider(counselor.photoUrl)
                      : null,
                  child: (counselor.photoUrl.isEmpty)
                      ? Icon(Icons.person_rounded, size: 35, color: theme.iconTheme.color?.withOpacity(0.6))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4), // Align text better with avatar center
                      Text(
                        counselor.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily, height: 1.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        counselor.specialization,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600, fontFamily: _primaryFontFamily),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              counselor.description,
              style: theme.textTheme.bodyMedium?.copyWith(fontFamily: _primaryFontFamily, color: theme.textTheme.bodySmall?.color, height: 1.45),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center buttons
              children: [
                Expanded(
                  child: BouncingWidget(
                    onPressed: canChat ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            counselorId: counselor.id,
                            counselorName: counselor.name,
                            counselorPhotoUrl: counselor.photoUrl,
                          ),
                        ),
                      );
                    } : null,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text("Chat"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: canChat ? colorScheme.primary.withOpacity(0.7) : theme.disabledColor.withOpacity(0.5),
                        ),
                        disabledForegroundColor: theme.disabledColor.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        textStyle: const TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 13.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: null, // Handled by BouncingWidget
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BouncingWidget(
                    onPressed: canRequestSlot ? () => _handleBookingRequest(counselor) : null,
                    child: ElevatedButton.icon(
                      icon: _isProcessingBooking
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary))
                          : Icon(Icons.event_available_outlined, size: 18),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.transparent,
                        disabledBackgroundColor: canRequestSlot
                            ? colorScheme.primary
                            : colorScheme.primary.withOpacity(0.3),
                        disabledForegroundColor: canRequestSlot
                            ? colorScheme.onPrimary
                            : colorScheme.onPrimary.withOpacity(0.5),
                        elevation: canRequestSlot ? 2 : 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        textStyle: const TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 13.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(_isProcessingBooking ? "Loading..." : "Request Slot"),
                      onPressed: null, // Handled by BouncingWidget
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Method to build a section header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 25.0, bottom: 15.0, left: 4, right: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontFamily: _primaryFontFamily,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.85),
        ),
      ),
    );
  }

  Widget _buildStatusView(BuildContext context) {
    if (_isLoadingUserAppointments) { return const Center(child: CircularProgressIndicator()); }
    if (_userAppointmentsError.isNotEmpty) { return Center(child: Text(_userAppointmentsError));}

    final now = DateTime.now();

    // Filter appointments
    final upcomingAppointments = _userAppointments.where((app) {
      final appDateTime = app.displayDateTime;
      return (app.status == 'pending' || app.status == 'confirmed') && appDateTime.isAfter(now);
    }).toList()..sort((a, b) => a.displayDateTime.compareTo(b.displayDateTime)); // Sort ascending

    final successfulAppointments = _userAppointments.where((app) => app.status == 'done').toList()
      ..sort((a, b) => b.displayDateTime.compareTo(a.displayDateTime)); // Sort descending

    final otherAppointments = _userAppointments.where((app) {
      return ['declined', 'cancelled_by_user', 'cancelled_by_counselor', 'no_show', 'expired'].contains(app.status) ||
          ((app.status == 'pending' || app.status == 'confirmed') && app.displayDateTime.isBefore(now) && app.status != 'done');
    }).toList()..sort((a, b) => b.displayDateTime.compareTo(a.displayDateTime)); // Sort descending


    List<Widget> listItems = [];

    // Upcoming Appointments Section
    listItems.add(_buildSectionHeader(context, "Upcoming Sessions"));
    if (upcomingAppointments.isEmpty) {
      listItems.add(const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Text("No upcoming appointments."))));
    } else {
      listItems.addAll(upcomingAppointments.map((app) => Container(
        margin: const EdgeInsets.only(bottom: 18.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: _getAppointmentCardShadow(context),
        ),
        child: _buildAppointmentStatusCardContent(context, app, isUpcoming: true),
      ),
      ));
    }

    // Successful Appointments Section
    listItems.add(_buildSectionHeader(context, "Completed Sessions"));
    if (successfulAppointments.isEmpty) {
      listItems.add(const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Text("No completed appointments yet."))));
    } else {
      listItems.addAll(successfulAppointments.map((app) => Container(
          margin: const EdgeInsets.only(bottom: 18.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: _getAppointmentCardShadow(context),
          ),
          child: _buildAppointmentStatusCardContent(context, app)),
      ));
    }

    // Other Appointments Section
    listItems.add(_buildSectionHeader(context, "Other History"));
    if (otherAppointments.isEmpty) {
      listItems.add(const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Text("No other appointment history."))));
    } else {
      listItems.addAll(otherAppointments.map((app) => Container(
          margin: const EdgeInsets.only(bottom: 18.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: _getAppointmentCardShadow(context),
          ),
          child: _buildAppointmentStatusCardContent(context, app)),
      ));
    }
    listItems.add(SizedBox(height: MediaQuery.of(context).padding.bottom + 10));


    return RefreshIndicator(
      onRefresh: _fetchUserAppointments,
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 90), // Main padding for the whole list
        children: listItems,
      ),
    );
  }


  Widget _buildAppointmentStatusCardContent(BuildContext context, Appointment appointment, {bool isUpcoming = false}) {
    final theme = Theme.of(context);
    final String formattedDate = DateFormat('EEE, MMM d, yyyy').format(appointment.displayDateTime);
    final String formattedTime = DateFormat('hh:mm a').format(appointment.displayDateTime);
    Color statusColor; IconData statusIcon; String statusText = appointment.status.replaceAll('_',' ').toUpperCase();
    bool canUserCancel = (appointment.status == 'pending' ||
        (appointment.status == 'confirmed' && appointment.displayDateTime.isAfter(DateTime.now().add(const Duration(hours: 1)))) // Can cancel if more than 1hr away
    );

    switch (appointment.status.toLowerCase()) {
      case 'confirmed': statusColor = Colors.green.shade600; statusIcon = Icons.check_circle_outline_rounded; break;
      case 'pending': statusColor = Colors.orange.shade700; statusIcon = Icons.pending_actions_rounded; break;
      case 'declined': statusColor = Colors.red.shade600; statusIcon = Icons.cancel_presentation_outlined; break;
      case 'done': statusColor = Colors.blueGrey.shade600; statusIcon = Icons.history_toggle_off_rounded; statusText = "COMPLETED"; break;
      case 'cancelled_by_user': statusColor = theme.hintColor; statusIcon = Icons.cancel_presentation_rounded; statusText = "YOU CANCELLED"; break;
      case 'cancelled_by_counselor': statusColor = theme.hintColor; statusIcon = Icons.cancel_schedule_send_outlined; statusText = "COUNSELOR CANCELLED"; break;
      case 'expired': statusColor = Colors.blueGrey.shade400; statusIcon = Icons.timer_off_outlined; statusText = "EXPIRED"; break;
      case 'no_show': statusColor = Colors.deepOrange.shade600; statusIcon = Icons.person_off_outlined; statusText = "MARKED NO-SHOW"; break;
      default: statusColor = theme.disabledColor; statusIcon = Icons.help_outline_rounded;
    }

    String? confirmationInfo;
    if (isUpcoming && appointment.status == 'confirmed' && appointment.confirmedDateTime != null) {
      confirmationInfo = "Confirmed: ${DateFormat('MMM d, hh:mm a').format(appointment.confirmedDateTime!.toDate())}";
    }


    return ClipRRect(
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    appointment.counselorName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  avatar: Icon(statusIcon, color: statusColor, size: 18),
                  label: Text(statusText),
                  labelStyle: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily),
                  backgroundColor: statusColor.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide.none,
                )
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(formattedDate, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: _primaryFontFamily)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time_filled_outlined, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(formattedTime, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: _primaryFontFamily)),
              ],
            ),
            if (confirmationInfo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 24), // Indent confirmation info
                child: Text(
                  confirmationInfo,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: _primaryFontFamily, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                ),
              ),
            if (appointment.meetingLink != null && appointment.meetingLink!.isNotEmpty && appointment.status == 'confirmed')
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Row(
                  children: [
                    Icon(Icons.videocam_outlined, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BouncingWidget(
                        onPressed: () { print("Launch meeting: ${appointment.meetingLink}"); /* TODO: Implement launch URL */},
                        child: Text(
                          "Join Meeting",
                          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: _primaryFontFamily, color: theme.colorScheme.primary, decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (canUserCancel && !_isCancellingThisAppointment(appointment.id))
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: BouncingWidget(
                    onPressed: () => _cancelAppointment(appointment.id),
                    child: TextButton(
                      onPressed: null, // Handled by BouncingWidget
                      style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.w600)
                      ),
                      child: const Text("Cancel Request"),
                    ),
                  ),
                ),
              ),
            if (_isCancellingThisAppointment(appointment.id))
              const Padding(
                padding: EdgeInsets.only(top: 15.0),
                child: Align(alignment: Alignment.centerRight, child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))),
              )
          ],
        ),
      ),
    );
  }

  bool _isCancellingThisAppointment(String id) => _cancellingAppointmentId == id;

  Future<void> _cancelAppointment(String appointmentId) async {
    if (_isCancellingThisAppointment(appointmentId) || !mounted) return;
    bool? confirmCancel = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text("Cancel Appointment?"),
          content: const Text("Are you sure you want to cancel this appointment request?"),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("No")),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text("Yes, Cancel", style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        )
    );

    if (confirmCancel != true) return;

    setStateIfMounted(() => _cancellingAppointmentId = appointmentId);
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'cancelled_by_user', 'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment request cancelled.")));
        _fetchUserAppointments(); // Refresh the list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error cancelling: ${e.toString()}")));
    } finally {
      if (mounted) setStateIfMounted(() => _cancellingAppointmentId = null);
    }
  }
}
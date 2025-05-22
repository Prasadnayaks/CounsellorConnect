// lib/counselor/counselor_dashboard_screen.dart
import 'package:counsellorconnect/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appointment_model.dart';
import 'counselor_profile_screen.dart';
import './manage_availability_screen.dart';
import '../theme/theme_provider.dart';
import '../widgets/bouncing_widget.dart';

// --- Constants ---
const String _primaryFontFamily = 'Nunito';
const double _cardCornerRadius = 22.0;
const double _tabSelectorRadius = 25.0;
const Duration _tabAnimationDuration = Duration(milliseconds: 350);
const double _conceptualOverlap = 20.0;
const String _profileIconAsset = 'assets/icons/profile_placeholder.png';
// --- End Constants ---

class CounselorDashboardScreen extends StatefulWidget {
  const CounselorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CounselorDashboardScreen> createState() => _CounselorDashboardScreenState();
}

class _CounselorDashboardScreenState extends State<CounselorDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  User? _currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Appointment> _pendingAppointments = [];
  List<Appointment> _upcomingAppointments = [];
  List<Appointment> _pastAppointments = [];
  bool _isLoading = true;
  String _error = '';

  final int _numberOfTabs = 3; // Requests, Upcoming, History

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _numberOfTabs, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _fetchAppointments();
    } else {
      if (mounted) {
        setState(() { _isLoading = false; _error = "Authentication error. Please log in again."; });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    if (!mounted || _currentUser == null) {
      if (mounted) setState(() { _isLoading = false; _error = "Not logged in."; });
      return;
    }
    setState(() { _isLoading = true; _error = ''; });

    try {
      final now = Timestamp.now();
      final DateTime currentDateTime = DateTime.now();
      final String currentCounselorId = _currentUser!.uid;

      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('counselorId', isEqualTo: currentCounselorId)
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedDateTime', descending: false)
          .get();
      List<Appointment> allPending = pendingSnapshot.docs.map((doc) {
        try { return Appointment.fromFirestore(doc); }
        catch(e) { print("[CounselorDashboard] Error parsing PENDING appointment ${doc.id}: $e"); return null; }
      }).whereType<Appointment>().toList();
      _pendingAppointments = allPending.where((appt) =>
          appt.requestedDateTime.toDate().isAfter(currentDateTime.subtract(const Duration(minutes: 5)))
      ).toList();

      final upcomingSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('counselorId', isEqualTo: currentCounselorId)
          .where('status', isEqualTo: 'confirmed')
          .where('confirmedDateTime', isGreaterThanOrEqualTo: now) // Ensures only future/current confirmed appointments
          .orderBy('confirmedDateTime', descending: false)
          .get();
      _upcomingAppointments = upcomingSnapshot.docs.map((doc) {
        try { return Appointment.fromFirestore(doc); }
        catch(e) { print("[CounselorDashboard] Error parsing UPCOMING appointment ${doc.id}: $e"); return null; }
      }).whereType<Appointment>().toList();

      List<Appointment> historyAppointments = [];
      final historyStatusQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('counselorId', isEqualTo: currentCounselorId)
          .where('status', whereIn: ['done', 'declined', 'cancelled_by_user', 'cancelled_by_counselor', 'no_show', 'expired'])
          .orderBy('lastUpdatedAt', descending: true) // Order by when it was last updated for history
          .limit(30)
          .get();
      historyAppointments.addAll(historyStatusQuery.docs.map((doc) {
        try { return Appointment.fromFirestore(doc); }
        catch(e) { print("[CounselorDashboard] Error parsing history (non-confirmed) ${doc.id}: $e"); return null; }
      }).whereType<Appointment>());

      final pastConfirmedSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('counselorId', isEqualTo: currentCounselorId)
          .where('status', isEqualTo: 'confirmed') // Confirmed appointments that are now in the past
          .where('confirmedDateTime', isLessThan: now)
          .orderBy('confirmedDateTime', descending: true)
          .limit(20)
          .get();
      historyAppointments.addAll(pastConfirmedSnapshot.docs.map((doc) {
        try { return Appointment.fromFirestore(doc); }
        catch(e) { print("[CounselorDashboard] Error parsing PAST CONFIRMED appointment ${doc.id}: $e"); return null; }
      }).whereType<Appointment>());

      // Sort all history items together by their relevant date (confirmed/requested or last updated)
      historyAppointments.sort((a, b) {
        DateTime dateA = a.confirmedDateTime?.toDate() ?? a.requestedDateTime.toDate();
        DateTime dateB = b.confirmedDateTime?.toDate() ?? b.requestedDateTime.toDate();
        // If you have a lastUpdatedAt field, you might prefer to sort by that for history
        // DateTime dateA = (a.lastUpdatedAt ?? a.createdAt).toDate();
        // DateTime dateB = (b.lastUpdatedAt ?? b.createdAt).toDate();
        return dateB.compareTo(dateA);
      });
      _pastAppointments = historyAppointments;

    } catch (e, s) {
      print("[CounselorDashboard] CRITICAL ERROR during _fetchAppointments: $e\nStackTrace: $s");
      if (mounted) {
        setState(() => _error = "Could not load appointments. Please check your network and Firestore setup (e.g., Indexes).");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAppointmentStatus(Appointment appointment, String newStatus, {String? userNameForNoShow}) async {
    if (!mounted || _isLoading) return;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (newStatus == 'no_show') {
      bool? confirmNoShow = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardCornerRadius)),
            title: const Text('Confirm No-Show', style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold)),
            content: Text("Are you sure you want to mark that '${userNameForNoShow ?? 'the user'}' did not appear for this session?", style: TextStyle(fontFamily: _primaryFontFamily)),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel', style: TextStyle(fontFamily: _primaryFontFamily, color: theme.hintColor)),
                onPressed: () { Navigator.of(dialogContext).pop(false); },
              ),
              TextButton(
                child: Text('Yes, Mark No-Show', style: TextStyle(fontFamily: _primaryFontFamily, color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                onPressed: () { Navigator.of(dialogContext).pop(true); },
              ),
            ],
          );
        },
      );
      if (confirmNoShow != true) return;
    }

    setState(() => _isLoading = true);
    Map<String, dynamic> updateData = {'status': newStatus, 'lastUpdatedAt': FieldValue.serverTimestamp()};

    if (newStatus == 'confirmed') {
      updateData['confirmedDateTime'] = appointment.requestedDateTime;
    }

    try {
      await FirebaseFirestore.instance.collection('appointments').doc(appointment.id).update(updateData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Appointment status updated to ${newStatus.toLowerCase().replaceAll('_', ' ')}.",
            style: TextStyle(color: colorScheme.onPrimaryContainer, fontFamily: _primaryFontFamily),
          ),
          backgroundColor: colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
          elevation: 4.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardCornerRadius * 0.75)),
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.05, left: 16, right: 16,),
        ));
        await _fetchAppointments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to update status: ${e.toString()}", style: TextStyle(color: colorScheme.onErrorContainer, fontFamily: _primaryFontFamily)),
          backgroundColor: colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.05, left: 16, right: 16,),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardCornerRadius * 0.75)),
        ));
        setState(() => _isLoading = false);
      }
    }
  }

  List<BoxShadow> _getCardShadow(BuildContext context, {Color? shadowColorHint}) {
    final theme = Theme.of(context);
    Color baseShadowColor = shadowColorHint?.withOpacity(0.35) ?? Colors.black.withOpacity(0.18);
    if (theme.brightness == Brightness.dark) {
      baseShadowColor = shadowColorHint?.withOpacity(0.6) ?? Colors.black.withOpacity(0.35);
    }
    return [
      BoxShadow(
        color: baseShadowColor,
        blurRadius: 20,
        spreadRadius: 1,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: baseShadowColor.withOpacity(0.1),
        blurRadius: 10.0,
        offset: const Offset(0, 4.0),
      ),
    ];
  }

  Widget _buildCustomTabSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tabWidth = constraints.maxWidth / _numberOfTabs;
          return Container(
            height: 48,
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withOpacity(0.07) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
              borderRadius: BorderRadius.circular(_tabSelectorRadius),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedAlign(
                  alignment: Alignment((_tabController.index / (_numberOfTabs - 1).toDouble()) * 2.0 - 1.0, 0),
                  duration: _tabAnimationDuration,
                  curve: Curves.fastOutSlowIn,
                  child: Container(
                    width: tabWidth,
                    height: 48,
                    decoration: BoxDecoration(
                        color: colorScheme.primary,
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
                  children: List.generate(_numberOfTabs, (index) {
                    String text = "";
                    if (index == 0) text = "Requests";
                    if (index == 1) text = "Upcoming";
                    if (index == 2) text = "History";
                    return _buildTabButton(context, text, index, tabWidth);
                  }),
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

    final double selectValue = (1.0 - (animation.value - index).abs()).clamp(0.0, 1.0);

    final Color textColor = Color.lerp(
        theme.textTheme.bodyLarge?.color?.withOpacity(0.85) ?? colorScheme.onSurface.withOpacity(0.85),
        colorScheme.onPrimary,
        selectValue
    )!;
    final FontWeight fontWeight = FontWeight.lerp(FontWeight.w500, FontWeight.bold, selectValue)!;

    return Expanded(
      child: BouncingWidget(
        onPressed: () {
          if (_tabController.index != index) {
            _tabController.animateTo(index);
          }
        },
        child: Container(
          width: tabWidth,
          height: double.infinity,
          color: Colors.transparent,
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

  Widget _buildAppDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;
    String userName = user?.displayName ?? user?.email?.split('@').first ?? "Counselor";
    String userEmail = user?.email ?? "No email provided";

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(userName, style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold, fontSize: 17, color: theme.colorScheme.onPrimary)),
            accountEmail: Text(userEmail, style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 13, color: theme.colorScheme.onPrimary.withOpacity(0.8))),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.2),
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Icon(Icons.support_agent_rounded, size: 40, color: theme.colorScheme.onPrimary)
                  : null,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: themeProvider.currentAccentGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          ListTile(
            leading: Icon(Icons.event_note_outlined, color: theme.colorScheme.primary),
            title: const Text('Manage Availability', style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 15, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAvailabilityScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary),
            title: const Text('Profile', style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 15, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CounselorProfileScreen()));
            },
          ),
          const Divider(thickness: 0.5),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text('Logout', style: TextStyle(fontFamily: _primaryFontFamily, fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              _logoutUser(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logoutUser(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => StartPage()),
      );
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error logging out: ${e.toString()}"))
        );
      }
    }
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 52),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error, fontSize: 16.5, fontFamily: _primaryFontFamily),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              onPressed: _fetchAppointments,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.8);
    final profileButtonBg = theme.brightness == Brightness.light ? Colors.grey.shade200 : theme.colorScheme.surfaceContainerHighest;

    return BouncingWidget(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CounselorProfileScreen()),
        );
      },
      child: SizedBox(
        width: 44, height: 44,
        child: Material(
          color: profileButtonBg,
          borderRadius: BorderRadius.circular(12.0),
          clipBehavior: Clip.antiAlias,
          elevation: 1.0,
          shadowColor: theme.shadowColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              _profileIconAsset,
              color: iconColor,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person_outline_rounded,
                color: iconColor,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: theme.brightness == Brightness.light ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: theme.scaffoldBackgroundColor,
      systemNavigationBarIconBrightness: theme.brightness == Brightness.light ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildAppDrawer(context),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: topPadding + 10,
                left: 16,
                right: 16,
                bottom: 5,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BouncingWidget(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light ? Colors.grey.shade200 : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface.withOpacity(0.8), size: 26),
                    ),
                  ),
                  const Spacer(),
                  const Spacer(),
                  BouncingWidget(
                    onPressed: _isLoading ? null : _fetchAppointments,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light ? Colors.grey.shade200 : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface.withOpacity(0.8), size: 26),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildProfileButton(context),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 5.0, bottom: _conceptualOverlap + 15),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    "DASHBOARD",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      fontFamily: _primaryFontFamily,
                      color: theme.textTheme.displayLarge?.color?.withOpacity(0.05),
                      height: 0.8,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -2),
                    child: Text(
                      "Counselor Dashboard",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: _primaryFontFamily,
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
              child: _buildCustomTabSelector(context),
            ),
          ),
          SliverFillRemaining(
            child: Builder(builder: (context) {
              if (_isLoading && _pendingAppointments.isEmpty && _upcomingAppointments.isEmpty && _pastAppointments.isEmpty && _error.isEmpty) {
                return Center(child: CircularProgressIndicator(color: colorScheme.primary));
              }
              if (_error.isNotEmpty) {
                return _buildErrorState(context, _error);
              }
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildAppointmentList(_pendingAppointments, "No pending requests.", context, listType: AppointmentListType.pending),
                  _buildAppointmentList(_upcomingAppointments, "No upcoming appointments.", context, listType: AppointmentListType.upcoming),
                  _buildAppointmentList(_pastAppointments, "Appointment history is clear.", context, listType: AppointmentListType.past),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

enum AppointmentListType { pending, upcoming, past }

Widget _buildAppointmentList(
    List<Appointment> appointments,
    String emptyMessage,
    BuildContext context, {
      required AppointmentListType listType,
    }) {
  final state = context.findAncestorStateOfType<_CounselorDashboardScreenState>();

  if (state != null && state._isLoading && appointments.isEmpty && state._error.isEmpty) {
    return const SizedBox.shrink();
  }

  if (appointments.isEmpty && !(state?._isLoading ?? false)) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              listType == AppointmentListType.pending
                  ? Icons.mark_email_unread_outlined
                  : listType == AppointmentListType.upcoming
                  ? Icons.event_available_outlined
                  : Icons.manage_history_outlined,
              size: 54,
              color: Theme.of(context).hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 15),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).hintColor,
                fontFamily: _primaryFontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  return RefreshIndicator(
    color: Theme.of(context).colorScheme.primary,
    onRefresh: () async {
      if (state != null && !state._isLoading) {
        await state._fetchAppointments();
      }
    },
    child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _buildCounselorAppointmentCard(context, appointment, listType: listType, screenState: state);
      },
    ),
  );
}

Widget _buildCounselorAppointmentCard(
    BuildContext context,
    Appointment appointment, {
      required AppointmentListType listType,
      _CounselorDashboardScreenState? screenState,
    }) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final String formattedDate = appointment.formattedDisplayDate;
  final String formattedTime = appointment.formattedDisplayTime;

  Color statusColor;
  IconData statusIcon;
  String statusText = appointment.status.replaceAll('_', ' ').toUpperCase();
  final String currentActualStatus = appointment.status.trim().toLowerCase();

  switch (currentActualStatus) {
    case 'confirmed': statusColor = Colors.green.shade600; statusIcon = Icons.check_circle_outline_rounded; break;
    case 'pending': statusColor = Colors.orange.shade700; statusIcon = Icons.pending_actions_rounded; break;
    case 'declined': statusColor = Colors.red.shade600; statusIcon = Icons.cancel_presentation_outlined; break;
    case 'done': statusColor = Colors.blueGrey.shade500; statusIcon = Icons.history_toggle_off_rounded; statusText = "COMPLETED"; break;
    case 'cancelled_by_user': statusColor = theme.hintColor; statusIcon = Icons.person_off_outlined; statusText = "USER CANCELLED"; break;
    case 'cancelled_by_counselor': statusColor = theme.colorScheme.error; statusIcon = Icons.do_not_disturb_on_outlined; statusText = "YOU CANCELLED"; break;
    case 'no_show': statusColor = Colors.deepOrange.shade700; statusIcon = Icons.person_off_outlined; statusText = "USER NO-SHOW"; break;
    case 'expired': statusColor = Colors.blueGrey.shade400; statusIcon = Icons.timer_off_outlined; statusText = "EXPIRED"; break;
    default: statusColor = Colors.grey.shade500; statusIcon = Icons.help_outline_rounded; statusText = appointment.status.isNotEmpty ? statusText : "UNKNOWN";
  }

  bool showPendingActions = listType == AppointmentListType.pending && currentActualStatus == 'pending';

  // --- MODIFIED LOGIC FOR UPCOMING ACTIONS VISIBILITY AND ENABLEMENT ---
  final DateTime now = DateTime.now();
  final DateTime appointmentTime = appointment.displayDateTime; // This is confirmedDateTime for 'confirmed' status
  final DateTime endOfActionGracePeriod = appointmentTime.add(const Duration(days: 1)); // 24-hour grace period after session start

  // Determine if "Mark Completed" or "No Show" buttons should be logically active
  bool canMarkOutcome = false;
  if (currentActualStatus == 'confirmed') {
    canMarkOutcome = now.isAfter(appointmentTime) && now.isBefore(endOfActionGracePeriod);
  }

  // Determine if "Cancel Session" button should be logically active
  // Counselor can cancel, for example, up to 1 hour before the session.
  bool canCancelSession = currentActualStatus == 'confirmed' && now.isBefore(appointmentTime.subtract(const Duration(hours: 1)));

  // Show the upcoming actions block if the status is confirmed (individual button logic will handle timing)
  bool showUpcomingActions = listType == AppointmentListType.upcoming && currentActualStatus == 'confirmed';

  // General check if the screen is interactive (not globally loading)
  bool isScreenInteractive = screenState != null && !screenState._isLoading;
  // --- END OF MODIFIED LOGIC ---


  return Container(
    margin: const EdgeInsets.only(bottom: 20.0),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(_cardCornerRadius),
      boxShadow: screenState?._getCardShadow(context),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(_cardCornerRadius),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    appointment.userName ?? 'N/A User Name',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily, height: 1.25, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  avatar: Icon(statusIcon, color: statusColor, size: 17),
                  label: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: _primaryFontFamily),
                  ),
                  backgroundColor: statusColor.withOpacity(0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1, thickness: 0.7, color: theme.dividerColor.withOpacity(0.5)),
            ),
            Row(
              children: [
                Icon(Icons.calendar_month_outlined, size: 17, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75)),
                const SizedBox(width: 9),
                Text(
                  formattedDate,
                  style: theme.textTheme.bodyLarge?.copyWith(fontFamily: _primaryFontFamily, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time_filled_outlined, size: 17, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75)),
                const SizedBox(width: 9),
                Text(
                  formattedTime,
                  style: theme.textTheme.bodyLarge?.copyWith(fontFamily: _primaryFontFamily, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),

            if ((showPendingActions || showUpcomingActions) && screenState != null)
              Container(
                margin: const EdgeInsets.only(top: 18.0),
                child: Opacity(
                  opacity: isScreenInteractive ? 1.0 : 0.6, // Overall opacity when screen is loading
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (showPendingActions)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            BouncingWidget(
                              onPressed: isScreenInteractive ? () => screenState._updateAppointmentStatus(appointment, 'declined') : null,
                              child: OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: colorScheme.error,
                                    disabledForegroundColor: colorScheme.error.withOpacity(0.5),
                                    side: BorderSide(color: isScreenInteractive ? colorScheme.error.withOpacity(0.7) : theme.disabledColor.withOpacity(0.5)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    textStyle: const TextStyle(fontSize: 13, fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                child: const Text("Decline"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            BouncingWidget(
                              onPressed: isScreenInteractive ? () => screenState._updateAppointmentStatus(appointment, 'confirmed') : null,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                label: const Text("Confirm"),
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.transparent,
                                    disabledBackgroundColor: isScreenInteractive ? colorScheme.primary : colorScheme.primary.withOpacity(0.3),
                                    disabledForegroundColor: isScreenInteractive ? colorScheme.onPrimary : colorScheme.onPrimary.withOpacity(0.5),
                                    elevation: isScreenInteractive ? 2 : 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    textStyle: const TextStyle(fontSize: 13, fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                          ],
                        ),
                      if (showUpcomingActions) ...[
                        SizedBox( // Cancel Session Button
                          width: double.infinity,
                          child: BouncingWidget(
                            onPressed: isScreenInteractive && canCancelSession ? () { // Logic for showing dialog
                              showDialog(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardCornerRadius)),
                                    title: const Text('Cancel This Session?', style: TextStyle(fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold)),
                                    content: const Text('Are you sure you want to cancel this confirmed session? The user will be notified.', style: TextStyle(fontFamily: _primaryFontFamily)),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text('No, Keep It', style: TextStyle(fontFamily: _primaryFontFamily, color: theme.hintColor)),
                                        onPressed: () { Navigator.of(dialogContext).pop(); },
                                      ),
                                      TextButton(
                                        child: Text('Yes, Cancel Session', style: TextStyle(fontFamily: _primaryFontFamily, color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.of(dialogContext).pop();
                                          screenState._updateAppointmentStatus(appointment, 'cancelled_by_counselor');
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            } : null,
                            child: TextButton.icon(
                              icon: Icon(Icons.cancel_outlined, size: 18, color: isScreenInteractive && canCancelSession ? theme.colorScheme.error : theme.disabledColor),
                              label: Text("Cancel Session", style: TextStyle(color: isScreenInteractive && canCancelSession ? theme.colorScheme.error : theme.disabledColor, fontSize: 13, fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold)),
                              onPressed: null,
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  alignment: Alignment.centerRight
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        BouncingWidget( // Mark Completed Button
                          onPressed: isScreenInteractive && canMarkOutcome ? () => screenState._updateAppointmentStatus(appointment, 'done') : null,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.task_alt_rounded, size: 18),
                            label: const Text("Mark Completed"),
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.transparent,
                              disabledBackgroundColor: isScreenInteractive && canMarkOutcome ? colorScheme.primary : colorScheme.primary.withOpacity(0.3),
                              disabledForegroundColor: isScreenInteractive && canMarkOutcome ? colorScheme.onPrimary : colorScheme.onPrimary.withOpacity(0.5),
                              elevation: isScreenInteractive && canMarkOutcome ? 2 : 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              textStyle: const TextStyle(fontSize: 13, fontFamily: _primaryFontFamily, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: const Size(180, 40),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        BouncingWidget( // User Did Not Appear Button
                          onPressed: isScreenInteractive && canMarkOutcome ? () => screenState._updateAppointmentStatus(appointment, 'no_show', userNameForNoShow: appointment.userName) : null,
                          child: TextButton.icon(
                            icon: Icon(Icons.person_off_outlined, size:18, color: isScreenInteractive && canMarkOutcome ? theme.colorScheme.onSurfaceVariant.withOpacity(0.8) : theme.disabledColor),
                            label: Text("${appointment.userName?.split(' ').first ?? 'User'} Did Not Appear", style: TextStyle(color: isScreenInteractive && canMarkOutcome ? theme.colorScheme.onSurfaceVariant.withOpacity(0.8) : theme.disabledColor, fontSize: 12, fontFamily: _primaryFontFamily, fontWeight: FontWeight.w600)),
                            onPressed: null,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

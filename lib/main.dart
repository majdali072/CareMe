import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/medications_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/account_screen.dart';
import 'screens/admin_controller_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/admin_bottom_nav.dart';
import 'widgets/floating_buttons.dart';
import 'widgets/add_medication_dialog.dart';
import 'widgets/add_lab_test_dialog.dart';
import 'widgets/add_schedule_dialog.dart';
import 'models/app_models.dart';
import 'services/api_service.dart';
import 'services/locale_controller.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CareMeApp());
}

class CareMeApp extends StatefulWidget {
  const CareMeApp({super.key});

  @override
  State<CareMeApp> createState() => _CareMeAppState();
}

class _CareMeAppState extends State<CareMeApp> {
  static const _themePrefKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themePrefKey);
    if (stored == 'dark') {
      setState(() => _themeMode = ThemeMode.dark);
    } else if (stored == 'light') {
      setState(() => _themeMode = ThemeMode.light);
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.instance.locale,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          title: 'CareMe',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeMode,
          locale: currentLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppRoot(
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
          ),
        );
      },
    );
  }
}

class AppRoot extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const AppRoot({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isLoggedIn = false;
  bool _bootstrapping = true;
  String _userName = '';
  bool _isAdmin = false;
  String _currentPage = 'home';

  List<Medication> _medications = [];
  List<LabTest> _labTests = [];
  List<Appointment> _appointments = [];
  Uint8List? _profilePhoto;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final hasSession = await ApiService.loadSession();
    if (!hasSession) {
      setState(() => _bootstrapping = false);
      return;
    }
    try {
      await ApiService.getProfile();
      setState(() {
        _userName = ApiService.userName ?? '';
        _isAdmin = ApiService.isAdmin;
        _currentPage = _isAdmin ? 'controller' : 'home';
        _isLoggedIn = true;
        _bootstrapping = false;
      });
      _loadData();
      _initNotifications();
    } catch (_) {
      await ApiService.logout();
      setState(() => _bootstrapping = false);
    }
  }

  void _handleLogin(String name, String email, bool isAdmin) {
    setState(() {
      _userName = name;
      _isAdmin = isAdmin;
      _currentPage = _isAdmin ? 'controller' : 'home';
      _isLoggedIn = true;
    });
    _loadData();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await NotificationService.init();
    await NotificationService.registerToken();
  }

  Future<void> _loadData() async {
    // Appointments live only on-device (there is no backend endpoint for them),
    // so load them from local storage first. This is independent of the server
    // and of Google Calendar, so appointments persist regardless of sync.
    await _loadAppointments();
    try {
      final meds = await ApiService.getMedications();
      final labs = await ApiService.getLabTests();
      final photoBytes = await ApiService.getProfilePhoto();

      setState(() {
        // Keep all meds — the Medications screen splits them into
        // Active vs Medication History on its own using `isPastOrHistory`.
        _medications = meds;
        _labTests = labs;
        _profilePhoto = photoBytes;
      });
    } catch (e) {
      // Data will just be empty if server is unreachable
    }
  }

  // ── Local appointment persistence ─────────────────────────────────────────
  // Appointments are stored per-user in SharedPreferences so they survive app
  // restarts and the activity recreation that Google Sign-In can trigger.
  String get _appointmentsKey =>
      'appointments::${ApiService.userEmail ?? 'guest'}';

  Future<void> _loadAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_appointmentsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map(Appointment.fromJson)
          .toList();
      setState(() => _appointments = loaded);
    } catch (_) {
      // Corrupt/missing data — leave appointments empty.
    }
  }

  Future<void> _persistAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_appointments.map((a) => a.toJson()).toList());
      await prefs.setString(_appointmentsKey, raw);
    } catch (_) {
      // Best-effort; ignore storage failures.
    }
  }

  /// Set appointments in state AND persist them. Used everywhere appointments
  /// change (calendar screen edits, AI actions, manual add).
  void _handleAppointmentsChanged(List<Appointment> updated) {
    setState(() => _appointments = updated);
    _persistAppointments();
  }

  void _handleLogout() {
    ApiService.logout();
    setState(() {
      _isLoggedIn = false;
      _userName = '';
      _isAdmin = false;
      _currentPage = 'home';
      _medications = [];
      _labTests = [];
      _appointments = [];
      _profilePhoto = null;
    });
  }

  void _navigate(String page) => setState(() => _currentPage = page);

  void _openAddMedication({Map<String, String>? initialFields}) {
    showDialog(
      context: context,
      builder: (_) => AddMedicationDialog(
        currentMedications: _medications.map((m) => m.name).toList(),
        initialFields: initialFields,
        onAdd: (med) async {
          try {
            final saved = await ApiService.addMedication(med);
            setState(() => _medications.add(saved.copyWith(
              schedule: med.schedule,
              startDate: med.startDate,
              endDate: med.endDate,
              isLifetime: med.isLifetime,
              isHistory: med.isHistory,
            )));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _openAddLabTest() {
    showDialog(
      context: context,
      builder: (_) => AddLabTestDialog(
        onAdd: (lab, {fileBytes, pickedFileName}) async {
          try {
            final saved = await ApiService.addLabTest(lab, fileBytes: fileBytes, pickedFileName: pickedFileName);
            setState(() => _labTests.add(saved));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add: $e')),
              );
            }
          }
        },
      ),
    );
  }

  /// Save a medication that CareAI emitted via a `careme-action` block.
  /// No popup — the AI's natural-language reply is the rundown the user sees.
  /// Failures show a snackbar so the user knows something went wrong; we
  /// don't surface them in the chat itself.
  Future<void> _saveMedicationFromAi(Medication med) async {
    try {
      final saved = await ApiService.addMedication(med);
      if (!mounted) return;
      setState(() => _medications.add(saved.copyWith(
            schedule: med.schedule,
            startDate: med.startDate,
            endDate: med.endDate,
            isLifetime: med.isLifetime,
            isHistory: med.isHistory,
            isPrn: med.isPrn,
          )));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add: $e')),
      );
    }
  }

  /// Save an appointment that CareAI emitted via a `careme-action` block.
  /// Local-only persistence (matches how the manual flow works); the AI's
  /// reply is the rundown.
  void _saveAppointmentFromAi(Appointment apt) {
    if (!mounted) return;
    setState(() => _appointments.add(apt));
    _persistAppointments();
  }

  /// Resolve a name (case-insensitive) to a medication in the user's list.
  /// Returns null when no medication matches; CareAI is supposed to only
  /// reference meds that exist, but the user may have just deleted it.
  Medication? _findMedicationByName(String name) {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final m in _medications) {
      if (m.name.trim().toLowerCase() == needle) return m;
    }
    return null;
  }

  Future<void> _deleteMedicationFromAi(String name) async {
    final med = _findMedicationByName(name);
    if (med == null || med.id == null) return;
    try {
      await ApiService.deleteMedication(med.id!);
      if (!mounted) return;
      setState(() => _medications.removeWhere((m) => m.id == med.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  /// Apply a partial update from the AI to a medication. The fields map
  /// matches the AI's `update_medication` action shape — supplied keys
  /// overwrite the existing values, missing keys keep their old values.
  Future<void> _updateMedicationFromAi(Map<String, dynamic> fields) async {
    final lookupName = (fields['name'] ?? fields['originalName'] ?? '')
        .toString()
        .trim();
    final existing = _findMedicationByName(lookupName);
    if (existing == null || existing.id == null) return;

    bool asBool(Object? v, bool fallback) {
      if (v is bool) return v;
      final s = (v ?? '').toString().toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
      return fallback;
    }

    DateTime? parseDate(Object? v) {
      final s = (v ?? '').toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    List<MedScheduleEntry>? parseSchedule(Object? raw) {
      if (raw is! List) return null;
      final out = <MedScheduleEntry>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final day = (entry['day'] ?? '').toString().trim();
        final times = entry['times'];
        if (day.isEmpty || times is! List) continue;
        out.add(MedScheduleEntry(
          day: day,
          times: times.map((t) => t.toString()).toList(),
        ));
      }
      return out.isEmpty ? null : out;
    }

    // Build the updated medication. For each key that's actually present in
    // the AI's payload we replace the existing value; otherwise keep what
    // was there. `copyWith` only takes non-null overrides, so we feed it
    // explicit values.
    final updated = existing.copyWith(
      name: fields.containsKey('newName')
          ? (fields['newName'] ?? '').toString()
          : existing.name,
      dosage: fields.containsKey('dosage')
          ? (fields['dosage'] ?? '').toString()
          : existing.dosage,
      frequency: fields.containsKey('frequency')
          ? (fields['frequency'] ?? '').toString()
          : existing.frequency,
      purpose: fields.containsKey('purpose')
          ? (fields['purpose'] ?? '').toString()
          : existing.purpose,
      sideEffects: fields.containsKey('sideEffects')
          ? (fields['sideEffects'] ?? '').toString()
          : existing.sideEffects,
      schedule: fields.containsKey('schedule')
          ? parseSchedule(fields['schedule'])
          : existing.schedule,
      startDate: fields.containsKey('startDate')
          ? parseDate(fields['startDate'])
          : existing.startDate,
      endDate: fields.containsKey('endDate')
          ? parseDate(fields['endDate'])
          : existing.endDate,
      isLifetime: fields.containsKey('lifetime')
          ? asBool(fields['lifetime'], existing.isLifetime ?? false)
          : existing.isLifetime,
      isHistory: fields.containsKey('history')
          ? asBool(fields['history'], existing.isHistory)
          : existing.isHistory,
      isPrn: fields.containsKey('prn')
          ? asBool(fields['prn'], existing.isPrn)
          : existing.isPrn,
    );

    try {
      await ApiService.updateMedication(existing.id!, updated);
      if (!mounted) return;
      setState(() {
        final i = _medications.indexWhere((m) => m.id == existing.id);
        if (i != -1) _medications[i] = updated.copyWith(id: existing.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  /// Find an appointment matching `title` (case-insensitive contains) and
  /// optionally a date (compared by year/month/day, ignores time).
  int _findAppointmentIndex(String title, DateTime? date) {
    final needle = title.trim().toLowerCase();
    if (needle.isEmpty) return -1;
    for (var i = 0; i < _appointments.length; i++) {
      final apt = _appointments[i];
      if (!apt.title.toLowerCase().contains(needle)) continue;
      if (date != null) {
        final f = apt.fullDate;
        if (f == null) continue;
        if (f.year != date.year || f.month != date.month || f.day != date.day) {
          continue;
        }
      }
      return i;
    }
    return -1;
  }

  void _deleteAppointmentFromAi(String title, DateTime? date) {
    final idx = _findAppointmentIndex(title, date);
    if (idx < 0) return;
    if (!mounted) return;
    setState(() => _appointments.removeAt(idx));
    _persistAppointments();
  }

  void _updateAppointmentFromAi(Map<String, dynamic> fields) {
    final lookupTitle = (fields['title'] ?? '').toString();
    final lookupDate = DateTime.tryParse((fields['date'] ?? '').toString());
    final idx = _findAppointmentIndex(lookupTitle, lookupDate);
    if (idx < 0) return;
    final existing = _appointments[idx];

    DateTime? newDate = lookupDate;
    if (fields.containsKey('newDate')) {
      newDate = DateTime.tryParse((fields['newDate'] ?? '').toString());
    } else {
      newDate = existing.fullDate;
    }

    final updated = existing.copyWith(
      title: fields.containsKey('newTitle')
          ? (fields['newTitle'] ?? '').toString()
          : existing.title,
      time: fields.containsKey('newTime')
          ? (fields['newTime'] ?? '').toString()
          : existing.time,
      type: fields.containsKey('type')
          ? (fields['type'] ?? '').toString()
          : existing.type,
      location: fields.containsKey('location')
          ? (fields['location'] ?? '').toString()
          : existing.location,
      fullDate: newDate ?? existing.fullDate,
      date: newDate?.day ?? existing.date,
    );

    if (!mounted) return;
    setState(() => _appointments[idx] = updated);
    _persistAppointments();
  }

  void _openAddSchedule({Map<String, String>? initialFields}) {
    showDialog(
      context: context,
      builder: (_) => AddScheduleDialog(
        initialFields: initialFields,
        onAdd: (apt) {
          setState(() => _appointments.add(apt));
          _persistAppointments();
        },
      ),
    );
  }

  bool _scheduleChanged(List<MedScheduleEntry>? a, List<MedScheduleEntry>? b) {
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i].day != b[i].day) return true;
      if (a[i].times.length != b[i].times.length) return true;
      for (int j = 0; j < a[i].times.length; j++) {
        if (a[i].times[j] != b[i].times[j]) return true;
      }
    }
    return false;
  }

  void _handleMedicationsChanged(List<Medication> updated) async {
    // Find which medication was removed
    final removedMeds = _medications.where(
      (m) => m.id != null && !updated.any((u) => u.id == m.id),
    );

    for (final med in removedMeds) {
      try {
        await ApiService.deleteMedication(med.id!);
      } catch (e) {
        // ignore
      }
    }

    // Find which medication was updated (edited)
    for (int i = 0; i < updated.length; i++) {
      final u = updated[i];
      if (u.id != null && i < _medications.length && _medications[i].id == u.id) {
        // Check if content changed
        final orig = _medications[i];
        if (orig.name != u.name ||
            orig.dosage != u.dosage ||
            orig.frequency != u.frequency ||
            orig.time != u.time ||
            orig.purpose != u.purpose ||
            orig.sideEffects != u.sideEffects ||
            orig.startDate != u.startDate ||
            orig.endDate != u.endDate ||
            orig.isLifetime != u.isLifetime ||
            _scheduleChanged(orig.schedule, u.schedule)) {
          try {
            await ApiService.updateMedication(u.id!, u);
          } catch (e) {
            // ignore
          }
        }
      }
    }

    setState(() => _medications = updated);
  }

  void _handleLabTestsChanged(List<LabTest> updated) async {
    final removedLabs = _labTests.where(
      (l) => l.id != null && !updated.any((u) => u.id == l.id),
    );

    for (final lab in removedLabs) {
      try {
        await ApiService.deleteLabTest(lab.id!);
      } catch (e) {
        // ignore
      }
    }

    setState(() => _labTests = updated);
  }

  Widget _buildPage() {
    switch (_currentPage) {
      case 'home':
        return HomeScreen(userName: _userName, onNavigate: _navigate, medications: _medications, appointments: _appointments, labTests: _labTests, profilePhoto: _profilePhoto);
      case 'medications':
        return MedicationsScreen(onBack: () => _navigate('home'), medications: _medications, labTests: _labTests, onMedicationsChanged: _handleMedicationsChanged, onLabTestsChanged: _handleLabTestsChanged);
      case 'calendar':
        return CalendarScreen(onBack: () => _navigate('home'), appointments: _appointments, onAppointmentsChanged: _handleAppointmentsChanged);
      case 'chatbot':
        return ChatbotScreen(
          onBack: () => _navigate('home'),
          profilePhoto: _profilePhoto,
          onSaveMedicationFromAi: _saveMedicationFromAi,
          onSaveAppointmentFromAi: _saveAppointmentFromAi,
          onDeleteMedicationFromAi: _deleteMedicationFromAi,
          onUpdateMedicationFromAi: _updateMedicationFromAi,
          onDeleteAppointmentFromAi: _deleteAppointmentFromAi,
          onUpdateAppointmentFromAi: _updateAppointmentFromAi,
        );
      case 'account':
        return AccountScreen(
          userName: _userName,
          onLogout: _handleLogout,
          onBack: () => _navigate('home'),
          appointments: _appointments,
          profilePhoto: _profilePhoto,
          onProfilePhotoChanged: (bytes) =>
              setState(() => _profilePhoto = bytes),
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      default:
        return HomeScreen(userName: _userName, onNavigate: _navigate, medications: _medications, appointments: _appointments, labTests: _labTests, profilePhoto: _profilePhoto);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isLoggedIn) {
      return LoginScreen(onLogin: _handleLogin);
    }

    if (_isAdmin) {
      return PopScope(
        canPop: _currentPage == 'controller',
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigate('controller');
        },
        child: Scaffold(
          body: Stack(children: [
            if (_currentPage == 'controller') const AdminControllerScreen(),
            if (_currentPage == 'settings') AdminSettingsScreen(onLogout: _handleLogout),
            Positioned(bottom: 0, left: 0, right: 0, child: AdminBottomNav(currentPage: _currentPage, onNavigate: _navigate)),
          ]),
        ),
      );
    }

    // System inset (gesture bar / 3-button area) so the floating buttons
    // sit above the bottom nav consistently across devices.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return PopScope(
      // On the home tab, allow the OS to handle back (exit/minimize the app).
      // On any other tab, intercept back and return to the home tab.
      canPop: _currentPage == 'home',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigate('home');
      },
      child: Scaffold(
        body: Stack(children: [
          Positioned.fill(child: _buildPage()),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: BottomNav(currentPage: _currentPage, onNavigate: _navigate),
          ),
          if (_currentPage != 'chatbot' && _currentPage != 'account')
            PositionedDirectional(
              bottom: 96 + bottomInset,
              end: 16,
              child: FloatingButtons(
                currentPage: _currentPage,
                onAddMedication: _openAddMedication,
                onAddLabTest: _openAddLabTest,
                onAddSchedule: _openAddSchedule,
                onOpenChatbot: () => _navigate('chatbot'),
              ),
            ),
        ]),
      ),
    );
  }
}

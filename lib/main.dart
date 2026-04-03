import 'package:flutter/material.dart';
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

void main() {
  runApp(const CareMeApp());
}

class CareMeApp extends StatelessWidget {
  const CareMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareMe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isLoggedIn = false;
  String _userName = '';
  bool _isAdmin = false;
  String _currentPage = 'home';

  List<Medication> _medications = [];
  List<LabTest> _labTests = [];
  List<Appointment> _appointments = [];

  void _handleLogin(String name, String email) {
    setState(() {
      _userName = name;
      _isAdmin = email.toLowerCase().endsWith('@admin.com');
      _currentPage = _isAdmin ? 'controller' : 'home';
      _isLoggedIn = true;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final meds = await ApiService.getMedications();
      final labs = await ApiService.getLabTests();
      setState(() {
        _medications = meds;
        _labTests = labs;
      });
    } catch (e) {
      // Data will just be empty if server is unreachable
    }
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
    });
  }

  void _navigate(String page) => setState(() => _currentPage = page);

  void _openAddMedication() {
    showDialog(
      context: context,
      builder: (_) => AddMedicationDialog(
        currentMedications: _medications.map((m) => m.name).toList(),
        onAdd: (med) async {
          try {
            final saved = await ApiService.addMedication(med);
            setState(() => _medications.add(saved));
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

  void _openAddSchedule() {
    showDialog(
      context: context,
      builder: (_) => AddScheduleDialog(
        onAdd: (apt) => setState(() => _appointments.add(apt)),
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
        return HomeScreen(userName: _userName, onNavigate: _navigate, medications: _medications, appointments: _appointments, labTests: _labTests);
      case 'medications':
        return MedicationsScreen(onBack: () => _navigate('home'), medications: _medications, labTests: _labTests, onMedicationsChanged: _handleMedicationsChanged, onLabTestsChanged: _handleLabTestsChanged);
      case 'calendar':
        return CalendarScreen(onBack: () => _navigate('home'), appointments: _appointments, onAppointmentsChanged: (a) => setState(() => _appointments = a));
      case 'chatbot':
        return ChatbotScreen(onBack: () => _navigate('home'));
      case 'account':
        return AccountScreen(userName: _userName, onLogout: _handleLogout, onBack: () => _navigate('home'), appointments: _appointments);
      default:
        return HomeScreen(userName: _userName, onNavigate: _navigate, medications: _medications, appointments: _appointments, labTests: _labTests);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return LoginScreen(onLogin: _handleLogin);
    }

    if (_isAdmin) {
      return Scaffold(
        body: Stack(children: [
          if (_currentPage == 'controller') const AdminControllerScreen(),
          if (_currentPage == 'settings') AdminSettingsScreen(onLogout: _handleLogout),
          Positioned(bottom: 0, left: 0, right: 0, child: AdminBottomNav(currentPage: _currentPage, onNavigate: _navigate)),
        ]),
      );
    }

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _buildPage()),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: BottomNav(currentPage: _currentPage, onNavigate: _navigate),
        ),
        if (_currentPage != 'chatbot' && _currentPage != 'account')
          Positioned(
            bottom: 96, right: 16,
            child: FloatingButtons(
              currentPage: _currentPage,
              onAddMedication: _openAddMedication,
              onAddLabTest: _openAddLabTest,
              onAddSchedule: _openAddSchedule,
              onOpenChatbot: () => _navigate('chatbot'),
            ),
          ),
      ]),
    );
  }
}

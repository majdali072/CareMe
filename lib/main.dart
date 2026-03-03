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

  List<Medication> _medications = [
    Medication(name: 'Aspirin', dosage: '100mg', frequency: 'Once daily', time: '8:00 AM', purpose: 'Blood thinner to prevent heart attacks', sideEffects: 'Stomach upset, bleeding'),
    Medication(name: 'Metformin', dosage: '500mg', frequency: 'Twice daily', time: '8:30 AM, 8:30 PM', purpose: 'Control blood sugar in type 2 diabetes', sideEffects: 'Nausea, diarrhea'),
    Medication(name: 'Lisinopril', dosage: '10mg', frequency: 'Once daily', time: '8:00 PM', purpose: 'Treat high blood pressure', sideEffects: 'Dry cough, dizziness'),
    Medication(name: 'Atorvastatin', dosage: '20mg', frequency: 'Once daily', time: '9:00 PM', purpose: 'Lower cholesterol levels', sideEffects: 'Muscle pain, fatigue'),
  ];

  List<LabTest> _labTests = [
    LabTest(name: 'Complete Blood Count (CBC)', date: 'November 5, 2025', doctor: 'Dr. Sarah Johnson', fileName: 'CBC_Results_Nov2025.pdf'),
    LabTest(name: 'Lipid Panel', date: 'October 20, 2025', doctor: 'Dr. Sarah Johnson', fileName: 'Lipid_Panel_Oct2025.pdf'),
    LabTest(name: 'HbA1c', date: 'October 15, 2025', doctor: 'Dr. Michael Chen', fileName: 'HbA1c_Oct2025.pdf'),
  ];

  List<Appointment> _appointments = [
    Appointment(date: 10, title: 'Dr. Sarah Johnson', time: '10:00 AM', type: 'Cardiology Checkup', location: 'Heart Care Clinic'),
    Appointment(date: 15, title: 'Dr. Sarah Johnson', time: '2:30 PM', type: 'Follow-up Visit', location: 'Heart Care Clinic'),
    Appointment(date: 22, title: 'Lab Test', time: '9:00 AM', type: 'Blood Work', location: 'City Medical Lab'),
    Appointment(date: 28, title: 'Dr. Michael Chen', time: '3:00 PM', type: 'Diabetes Management', location: 'Wellness Center'),
  ];

  void _handleLogin(String name, String email) {
    setState(() {
      _userName = name;
      _isAdmin = email.toLowerCase().endsWith('@admin.com');
      _currentPage = _isAdmin ? 'controller' : 'home';
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _userName = '';
      _isAdmin = false;
      _currentPage = 'home';
    });
  }

  void _navigate(String page) => setState(() => _currentPage = page);

  void _openAddMedication() {
    showDialog(
      context: context,
      builder: (_) => AddMedicationDialog(
        currentMedications: _medications.map((m) => m.name).toList(),
        onAdd: (med) => setState(() => _medications.add(med)),
      ),
    );
  }

  void _openAddLabTest() {
    showDialog(
      context: context,
      builder: (_) => AddLabTestDialog(
        onAdd: (lab) => setState(() => _labTests.add(lab)),
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

  Widget _buildPage() {
    switch (_currentPage) {
      case 'home':
        return HomeScreen(userName: _userName, onNavigate: _navigate, medications: _medications, appointments: _appointments, labTests: _labTests);
      case 'medications':
        return MedicationsScreen(onBack: () => _navigate('home'), medications: _medications, labTests: _labTests, onMedicationsChanged: (m) => setState(() => _medications = m), onLabTestsChanged: (l) => setState(() => _labTests = l));
      case 'calendar':
        return CalendarScreen(onBack: () => _navigate('home'), appointments: _appointments, onAppointmentsChanged: (a) => setState(() => _appointments = a));
      case 'chatbot':
        return ChatbotScreen(onBack: () => _navigate('home'));
      case 'account':
        return AccountScreen(userName: _userName, onLogout: _handleLogout, onBack: () => _navigate('home'));
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
        _buildPage(),
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

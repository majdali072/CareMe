import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/app_models.dart';

class HomeScreen extends StatelessWidget {
  final String userName;
  final void Function(String) onNavigate;
  final List<Medication> medications;
  final List<Appointment> appointments;
  final List<LabTest> labTests;
  final Uint8List? profilePhoto;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.onNavigate,
    required this.medications,
    required this.appointments,
    required this.labTests,
    this.profilePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final topMeds = medications.take(3).toList();
    final nextApt = appointments.isNotEmpty ? appointments.first : null;
    final latestLab = labTests.isNotEmpty ? labTests.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CareMe', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    GestureDetector(
                      onTap: () => onNavigate('account'),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          image: profilePhoto != null
                              ? DecorationImage(
                                  image: MemoryImage(profilePhoto!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: profilePhoto == null
                            ? Center(
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Most Frequent Medications
                _buildCard(
                  icon: Icons.medication_rounded,
                  title: 'Most Frequent Medications',
                  child: Column(
                    children: topMeds.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(12), child: Text('No medications added', style: TextStyle(color: Color(0xFF6B7280))))]
                        : topMeds.asMap().entries.map((e) {
                            final med = e.value;
                            final isLast = e.key == topMeds.length - 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(med.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111418))),
                                  const SizedBox(height: 2),
                                  Text('${med.dosage} • ${med.frequency}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                                  Text(med.time, style: const TextStyle(color: Color(0xFF1976D2), fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // Next Appointment
                _buildCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'Next Appointment',
                  child: nextApt == null
                      ? const Padding(padding: EdgeInsets.all(12), child: Text('No upcoming appointments', style: TextStyle(color: Color(0xFF6B7280))))
                      : Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(24)),
                              child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF1976D2)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nextApt.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111418))),
                                  Text(nextApt.type, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF1976D2)),
                                    const SizedBox(width: 4),
                                    Text('November ${nextApt.date}, 2025', style: const TextStyle(fontSize: 13, color: Color(0xFF111418))),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.access_time, size: 14, color: Color(0xFF1976D2)),
                                    const SizedBox(width: 4),
                                    Text(nextApt.time, style: const TextStyle(fontSize: 13, color: Color(0xFF111418))),
                                  ]),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Text(nextApt.location, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 14),

                // Latest Lab Test
                _buildCard(
                  icon: Icons.description_outlined,
                  title: 'Latest Lab Test',
                  child: latestLab == null
                      ? const Padding(padding: EdgeInsets.all(12), child: Text('No lab tests added', style: TextStyle(color: Color(0xFF6B7280))))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(latestLab.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111418))),
                            const SizedBox(height: 4),
                            Text(latestLab.date, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Results available', style: TextStyle(color: Color(0xFF15803D), fontSize: 13)),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

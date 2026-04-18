import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/google_calendar_service.dart';
import '../widgets/edit_appointment_dialog.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback onBack;
  final List<Appointment> appointments;
  final void Function(List<Appointment>) onAppointmentsChanged;

  const CalendarScreen({
    super.key,
    required this.onBack,
    required this.appointments,
    required this.onAppointmentsChanged,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
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
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    left: 16, top: 14,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onBack,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Appointments', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ALL APPOINTMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
                const SizedBox(height: 10),

                if (widget.appointments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFF9CA3AF)),
                        SizedBox(height: 12),
                        Text('No appointments scheduled', style: TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Add your first appointment!', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                      ],
                    ),
                  ),

                ...widget.appointments.asMap().entries.map((e) => _buildAptCard(e.key, e.value)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAptCard(int index, Appointment apt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(apt.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111418), fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                        child: Text('Nov ${apt.date}', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      _iconBtn(Icons.edit_outlined, () {
                        showDialog(
                          context: context,
                          builder: (_) => EditAppointmentDialog(
                            appointment: apt,
                            onSave: (updated) {
                              final apts = List<Appointment>.from(widget.appointments);
                              apts[index] = updated;
                              widget.onAppointmentsChanged(apts);
                            },
                          ),
                        );
                      }),
                      _iconBtn(Icons.delete_outline, () async {
                        // Delete from Google Calendar if event ID exists
                        if (apt.googleEventId != null && apt.googleEventId!.isNotEmpty) {
                          await GoogleCalendarService.deleteEvent(apt.googleEventId!);
                        }
                        final apts = List<Appointment>.from(widget.appointments)..removeAt(index);
                        widget.onAppointmentsChanged(apts);
                      }),
                    ],
                  ),
                  Text(apt.type, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.access_time, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(apt.time, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(apt.location, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
      ),
    );
  }
}

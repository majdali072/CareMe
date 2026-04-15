import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../services/google_calendar_service.dart';

class AddScheduleDialog extends StatefulWidget {
  final void Function(Appointment) onAdd;
  const AddScheduleDialog({super.key, required this.onAdd});

  @override
  State<AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<AddScheduleDialog> {
  final _titleCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  String? _alertType;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _typeCtrl.text.isEmpty || _dateCtrl.text.isEmpty || _timeCtrl.text.isEmpty) return;
    if (_pickedDate == null || _pickedTime == null) return;
    // Random 20% conflict
    if (DateTime.now().millisecond % 5 == 0) {
      setState(() => _alertType = 'conflict');
      return;
    }

    setState(() => _submitting = true);

    final start = DateTime(
      _pickedDate!.year,
      _pickedDate!.month,
      _pickedDate!.day,
      _pickedTime!.hour,
      _pickedTime!.minute,
    );

    final description = [
      if (_typeCtrl.text.isNotEmpty) 'Type: ${_typeCtrl.text}',
      if (_doctorCtrl.text.isNotEmpty) 'Doctor: ${_doctorCtrl.text}',
      'Created via CareMe',
    ].join('\n');

    final eventId = await GoogleCalendarService.createEvent(
      title: _titleCtrl.text,
      description: description,
      location: _locationCtrl.text,
      start: start,
    );

    widget.onAdd(Appointment(
      date: _pickedDate!.day,
      title: _titleCtrl.text,
      time: _timeCtrl.text,
      type: _typeCtrl.text,
      location: _locationCtrl.text,
    ));

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _alertType = eventId != null ? 'success' : 'added_no_gcal';
    });

    Future.delayed(const Duration(milliseconds: 1800), () { if (mounted) Navigator.pop(context); });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Row(
                children: [
                  const Expanded(child: Text('Add Appointment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _field('Title', _titleCtrl, 'e.g., Dr. Smith'),
                    const SizedBox(height: 14),
                    _field('Appointment Type', _typeCtrl, 'e.g., Checkup, Follow-up'),
                    const SizedBox(height: 14),
                    _field('Doctor/Specialist', _doctorCtrl, "Doctor's name"),
                    const SizedBox(height: 14),
                    _field('Location', _locationCtrl, 'Medical center or clinic'),
                    const SizedBox(height: 14),
                    _datePickerField('Date', _dateCtrl),
                    const SizedBox(height: 14),
                    _timePickerField('Time', _timeCtrl),
                    const SizedBox(height: 14),
                    if (_alertType == 'success')
                      _alert(true, 'Appointment added & synced to Google Calendar!'),
                    if (_alertType == 'added_no_gcal')
                      _alert(false, 'Appointment added. Google Calendar sync failed — sign in with Google to sync.'),
                    if (_alertType == 'conflict')
                      _alert(false, 'Warning: Time conflict detected with another appointment.'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _submitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Add Appointment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint, filled: true, fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _datePickerField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
              _pickedDate = picked;
            }
          },
          decoration: InputDecoration(
            hintText: 'Tap to select date',
            suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6B7280)),
            filled: true, fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _timePickerField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              ctrl.text = picked.format(context);
              _pickedTime = picked;
            }
          },
          decoration: InputDecoration(
            hintText: 'Tap to select time',
            suffixIcon: const Icon(Icons.access_time, size: 18, color: Color(0xFF6B7280)),
            filled: true, fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _alert(bool success, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFF0FDF4) : const Color(0xFFFFFDE7),
        border: Border.all(color: success ? const Color(0xFF86EFAC) : const Color(0xFFFFD600)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.warning_amber_rounded, color: success ? const Color(0xFF16A34A) : const Color(0xFFF57C00), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: success ? const Color(0xFF15803D) : Colors.black87))),
        ],
      ),
    );
  }
}

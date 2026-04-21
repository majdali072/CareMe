import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class EditAppointmentDialog extends StatefulWidget {
  final Appointment appointment;
  final void Function(Appointment) onSave;

  const EditAppointmentDialog({super.key, required this.appointment, required this.onSave});

  @override
  State<EditAppointmentDialog> createState() => _EditAppointmentDialogState();
}

class _EditAppointmentDialogState extends State<EditAppointmentDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _dateCtrl;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _titleCtrl = TextEditingController(text: a.title);
    _typeCtrl = TextEditingController(text: a.type);
    _timeCtrl = TextEditingController(text: a.time);
    _locationCtrl = TextEditingController(text: a.location);
    _dateCtrl = TextEditingController(text: a.date.toString());
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
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)])),
              child: Row(
                children: [
                  const Expanded(child: Text('Edit Appointment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _field('Title', _titleCtrl),
                    const SizedBox(height: 12),
                    _field('Type', _typeCtrl),
                    const SizedBox(height: 12),
                    _field('Date (day)', _dateCtrl, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _field('Time', _timeCtrl),
                    const SizedBox(height: 12),
                    _field('Location', _locationCtrl),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onSave(widget.appointment.copyWith(
                            title: _titleCtrl.text,
                            type: _typeCtrl.text,
                            time: _timeCtrl.text,
                            location: _locationCtrl.text,
                            date: int.tryParse(_dateCtrl.text) ?? widget.appointment.date,
                          ));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _field(String label, TextEditingController ctrl, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

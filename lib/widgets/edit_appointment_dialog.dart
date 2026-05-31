import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
  late final TextEditingController _doctorCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _dateCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    // Title and appointment type were merged into a single field; fall back to
    // the legacy type when an older entry only had a type.
    _titleCtrl = TextEditingController(
        text: a.title.isNotEmpty ? a.title : a.type);
    _doctorCtrl = TextEditingController(text: a.doctor);
    _timeCtrl = TextEditingController(text: a.time);
    _locationCtrl = TextEditingController(text: a.location);
    _dateCtrl = TextEditingController(text: a.date.toString());
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty ||
        _doctorCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _dateCtrl.text.trim().isEmpty ||
        _timeCtrl.text.trim().isEmpty) {
      setState(() => _error =
          AppLocalizations.of(context).t('dlg_sched_validation_required'));
      return;
    }
    widget.onSave(widget.appointment.copyWith(
      title: _titleCtrl.text,
      type: '',
      doctor: _doctorCtrl.text,
      time: _timeCtrl.text,
      location: _locationCtrl.text,
      date: int.tryParse(_dateCtrl.text) ?? widget.appointment.date,
    ));
    Navigator.pop(context);
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
                  Expanded(child: Text(AppLocalizations.of(context).t('dlg_edit_appt_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _field('${AppLocalizations.of(context).t('dlg_sched_appointment_field')} *', _titleCtrl),
                    const SizedBox(height: 12),
                    _field('${AppLocalizations.of(context).t('dlg_sched_doctor')} *', _doctorCtrl),
                    const SizedBox(height: 12),
                    _field('${AppLocalizations.of(context).t('dlg_edit_appt_date_day')} *', _dateCtrl, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _field('${AppLocalizations.of(context).t('dlg_schedule_time_label')} *', _timeCtrl),
                    const SizedBox(height: 12),
                    _field('${AppLocalizations.of(context).t('dlg_schedule_location_label')} *', _locationCtrl),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(AppLocalizations.of(context).t('dlg_med_save_btn'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../services/google_calendar_service.dart';
import '../theme/app_theme.dart';

class AddScheduleDialog extends StatefulWidget {
  final void Function(Appointment) onAdd;
  // Optional pre-fill (e.g. when launched from a CareAI action). Keys:
  // title, type, location, date (YYYY-MM-DD), time (HH:MM 24h).
  final Map<String, String>? initialFields;

  const AddScheduleDialog({super.key, required this.onAdd, this.initialFields});

  @override
  State<AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<AddScheduleDialog> {
  final _titleCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  String? _alertType;
  String? _error;
  bool _submitting = false;

  // Google Sign-In state
  GoogleSignInAccount? _googleAccount;
  bool _signingIn = false;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/calendar'],
  );

  @override
  void initState() {
    super.initState();
    final init = widget.initialFields;
    if (init != null) {
      // Title and appointment type are now a single field; fall back to the
      // type when a CareAI prefill only supplied a type.
      _titleCtrl.text = (init['title']?.isNotEmpty ?? false)
          ? init['title']!
          : (init['type'] ?? '');
      _doctorCtrl.text = init['doctor'] ?? '';
      _locationCtrl.text = init['location'] ?? '';
      final dateStr = init['date'] ?? '';
      if (dateStr.isNotEmpty) {
        try {
          _pickedDate = DateTime.parse(dateStr);
          _dateCtrl.text = DateFormat('MMM d, yyyy').format(_pickedDate!);
        } catch (_) {}
      }
      final timeStr = init['time'] ?? '';
      if (timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
            _pickedTime = TimeOfDay(hour: h, minute: m);
            // 24h fallback format that doesn't need localizations.
            _timeCtrl.text =
                '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
          }
        }
      }
    }
    // Check if already signed in
    _googleAccount = _googleSignIn.currentUser;
    if (_googleAccount == null) {
      _googleSignIn.signInSilently().then((account) {
        if (mounted && account != null) {
          setState(() => _googleAccount = account);
        }
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _signingIn = true);
    try {
      final account = await _googleSignIn.signIn();
      if (mounted) {
        setState(() {
          _googleAccount = account;
          _signingIn = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _signingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)
              .t('dlg_sched_google_failed', {'error': e.toString()}))),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _doctorCtrl.text.trim().isEmpty ||
        _locationCtrl.text.trim().isEmpty ||
        _dateCtrl.text.isEmpty ||
        _timeCtrl.text.isEmpty ||
        _pickedDate == null ||
        _pickedTime == null) {
      setState(() => _error =
          AppLocalizations.of(context).t('dlg_sched_validation_required'));
      return;
    }
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
      if (_doctorCtrl.text.isNotEmpty) 'Doctor: ${_doctorCtrl.text}',
      'Created via CareMe',
    ].join('\n');

    String? eventId;
    if (_googleAccount != null) {
      eventId = await GoogleCalendarService.createEvent(
        title: _titleCtrl.text,
        description: description,
        location: _locationCtrl.text,
        start: start,
      );
    }

    widget.onAdd(Appointment(
      date: _pickedDate!.day,
      fullDate: _pickedDate,
      title: _titleCtrl.text,
      time: _timeCtrl.text,
      type: '',
      location: _locationCtrl.text,
      doctor: _doctorCtrl.text,
      googleEventId: eventId,
    ));

    if (!mounted) return;
    setState(() => _submitting = false);
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
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Row(
                children: [
                  Expanded(child: Text(AppLocalizations.of(context).t('dlg_sched_add_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Google Calendar sign-in section
                    _buildGoogleCalendarSection(),
                    const SizedBox(height: 14),
                    _field('${AppLocalizations.of(context).t('dlg_sched_appointment_field')} *',
                        _titleCtrl, AppLocalizations.of(context).t('dlg_sched_appointment_hint')),
                    const SizedBox(height: 14),
                    _field('${AppLocalizations.of(context).t('dlg_sched_doctor')} *',
                        _doctorCtrl, AppLocalizations.of(context).t('dlg_sched_doctor_hint')),
                    const SizedBox(height: 14),
                    _field('${AppLocalizations.of(context).t('dlg_sched_location')} *',
                        _locationCtrl, AppLocalizations.of(context).t('dlg_sched_location_hint')),
                    const SizedBox(height: 14),
                    _datePickerField('${AppLocalizations.of(context).t('dlg_sched_date')} *', _dateCtrl),
                    const SizedBox(height: 14),
                    _timePickerField('${AppLocalizations.of(context).t('dlg_sched_time')} *', _timeCtrl),
                    const SizedBox(height: 14),
                    if (_alertType == 'success')
                      _alert(true, AppLocalizations.of(context).t('dlg_sched_alert_synced')),
                    if (_alertType == 'added_no_gcal')
                      _alert(false, AppLocalizations.of(context).t('dlg_sched_alert_no_gcal')),
                    if (_alertType == 'added_gcal_failed')
                      _alert(false, AppLocalizations.of(context).t('dlg_sched_alert_gcal_failed')),
                    if (_alertType == 'conflict')
                      _alert(false, AppLocalizations.of(context).t('dlg_sched_alert_conflict')),
                    if (_error != null) _alert(false, _error!),
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
                            : Text(AppLocalizations.of(context).t('dlg_sched_add_button'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _buildGoogleCalendarSection() {
    if (_googleAccount != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          border: Border.all(color: const Color(0xFF86EFAC)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).t('dlg_sched_google_connected'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF15803D))),
                  Text(_googleAccount!.email,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                await _googleSignIn.signOut();
                setState(() => _googleAccount = null);
              },
              child: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _signingIn ? null : _signInWithGoogle,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt(context),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: _signingIn
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calendar_month, color: Color(0xFF4285F4), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).t('dlg_sched_google_signin'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                  Text(AppLocalizations.of(context).t('dlg_sched_google_sync_sub'),
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: AppColors.textMuted(context)), filled: true, fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
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
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          style: TextStyle(color: AppColors.textPrimary(context)),
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
            hintText: AppLocalizations.of(context).t('dlg_tap_to_select_date'),
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            suffixIcon: Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary(context)),
            filled: true, fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
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
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          style: TextStyle(color: AppColors.textPrimary(context)),
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
            hintText: AppLocalizations.of(context).t('dlg_sched_tap_time'),
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            suffixIcon: Icon(Icons.access_time, size: 18, color: AppColors.textSecondary(context)),
            filled: true, fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
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

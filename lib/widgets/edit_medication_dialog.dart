import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class EditMedicationDialog extends StatefulWidget {
  final Medication medication;
  final void Function(Medication) onSave;

  const EditMedicationDialog({
    super.key,
    required this.medication,
    required this.onSave,
  });

  @override
  State<EditMedicationDialog> createState() => _EditMedicationDialogState();
}

class _EditMedicationDialogState extends State<EditMedicationDialog> {
  late TextEditingController _name;
  late TextEditingController _dosage;
  late TextEditingController _frequency;
  late TextEditingController _purpose;
  late TextEditingController _sideEffects;

  late List<MedScheduleEntry> _schedule;
  int? _expandedDay;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLifetime = false;
  bool _isHistory = false;
  bool _isPrn = false;
  String? _error;

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _name = TextEditingController(text: m.name);
    _dosage = TextEditingController(text: m.dosage);
    _frequency = TextEditingController(text: m.frequency);
    _purpose = TextEditingController(text: m.purpose);
    _sideEffects = TextEditingController(text: m.sideEffects);

    _schedule = (m.schedule ?? [])
        .map((e) => MedScheduleEntry(
              day: e.day,
              times: List<String>.from(e.times),
            ))
        .toList();

    _startDate = m.startDate;
    _endDate = m.endDate;
    _isLifetime = m.isLifetime ?? false;
    _isHistory = m.isHistory;
    _isPrn = m.isPrn;
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _purpose.dispose();
    _sideEffects.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
  }

  Future<String?> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return null;
    final h = picked.hour.toString().padLeft(2, '0');
    final min = picked.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  // Toggle a weekday on/off in the schedule. Selecting adds an empty entry
  // (and expands it); deselecting removes it. Kept in weekday order.
  void _toggleDay(String day) {
    setState(() {
      final existingIdx = _schedule.indexWhere((e) => e.day == day);
      if (existingIdx >= 0) {
        _schedule.removeAt(existingIdx);
        if (_expandedDay == existingIdx) {
          _expandedDay = null;
        } else if (_expandedDay != null && _expandedDay! > existingIdx) {
          _expandedDay = _expandedDay! - 1;
        }
      } else {
        _schedule.add(MedScheduleEntry(day: day, times: []));
        _schedule.sort((a, b) =>
            _weekDays.indexOf(a.day).compareTo(_weekDays.indexOf(b.day)));
        _expandedDay = _schedule.indexWhere((e) => e.day == day);
      }
    });
  }

  // A single selectable day pill (checkbox-style toggle).
  Widget _dayToggleChip(String day) {
    final selected = _schedule.any((e) => e.day == day);
    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent(context)
              : AppColors.surfaceAlt(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.accent(context)
                : AppColors.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: selected ? Colors.white : AppColors.textMuted(context),
            ),
            const SizedBox(width: 6),
            Text(
              day.substring(0, 3),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final t = AppLocalizations.of(context);
    // Name & dosage are always required.
    if (_name.text.trim().isEmpty || _dosage.text.trim().isEmpty) {
      setState(() => _error = t.t('dlg_med_validation_name_dosage'));
      return;
    }
    // PRN skips schedule & duration entirely (both locked). Otherwise the
    // Schedule is required unless History locks it, and the Duration dates are
    // required (Duration is only locked by PRN).
    if (!_isPrn) {
      final hasValidSchedule =
          _schedule.isNotEmpty && _schedule.any((e) => e.times.isNotEmpty);
      if (!_isHistory && !hasValidSchedule) {
        setState(() => _error = t.t('dlg_med_validation_schedule'));
        return;
      }
      if (_startDate == null) {
        setState(() => _error = t.t('dlg_med_validation_start_date'));
        return;
      }
      if (!_isLifetime && _endDate == null) {
        setState(() => _error = t.t('dlg_med_validation_end_date'));
        return;
      }
    }

    // Auto-compute frequency from schedule (or "As needed" for PRN).
    String freq;
    if (_isPrn) {
      freq = 'As needed';
    } else {
      final totalTimes =
          _schedule.fold<int>(0, (sum, e) => sum + e.times.length);
      final daysWithTimes = _schedule.where((e) => e.times.isNotEmpty).length;
      if (totalTimes == 0) {
        freq = '';
      } else if (daysWithTimes == 7) {
        if (totalTimes % 7 == 0) {
          final n = totalTimes ~/ 7;
          freq = n == 1 ? 'Daily' : 'Daily, $n× per day';
        } else {
          freq = 'Daily, ~${(totalTimes / 7).toStringAsFixed(1)}× per day';
        }
      } else {
        final timeWord = totalTimes == 1 ? 'time' : 'times';
        final dayWord = daysWithTimes == 1 ? 'day' : 'days';
        freq = '$totalTimes $timeWord per week ($daysWithTimes $dayWord)';
      }
    }

    final updated = widget.medication.copyWith(
      name: _name.text.trim(),
      dosage: _dosage.text.trim(),
      frequency: freq,
      purpose: _purpose.text.trim(),
      sideEffects: _sideEffects.text.trim(),
      schedule: _isPrn ? [] : _schedule,
      startDate: _isPrn ? null : _startDate,
      endDate: _isPrn ? null : (_isLifetime ? null : _endDate),
      isLifetime: _isPrn ? false : _isLifetime,
      isHistory: _isHistory,
      isPrn: _isPrn,
    );
    widget.onSave(updated);
    Navigator.pop(context);
  }

  Widget _prnCheckbox() {
    return GestureDetector(
      onTap: () => setState(() {
        _isPrn = !_isPrn;
        if (_isPrn) {
          _schedule.clear();
          _expandedDay = null;
          _isLifetime = false;
        }
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isPrn
              ? AppColors.tint(context)
              : AppColors.surfaceAlt(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isPrn
                ? const Color(0xFF2563EB)
                : AppColors.border(context),
            width: _isPrn ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _isPrn ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isPrn
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: _isPrn
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).t('dlg_med_prn_label'),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context))),
                  const SizedBox(height: 2),
                  Text(
                      AppLocalizations.of(context).t('dlg_med_prn_sub'),
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Expanded(child: _statusOption(label: AppLocalizations.of(context).t('dlg_med_status_active'), isHistory: false)),
          Expanded(child: _statusOption(label: AppLocalizations.of(context).t('dlg_med_status_history'), isHistory: true)),
        ],
      ),
    );
  }

  Widget _statusOption({required String label, required bool isHistory}) {
    final selected = _isHistory == isHistory;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isHistory = isHistory;
          if (_isHistory) _isLifetime = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context).t('dlg_edit_medication_title'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 17)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

            // Basic fields
            _field('${AppLocalizations.of(context).t('dlg_med_name_label')} *', _name),
            _field('${AppLocalizations.of(context).t('meds_dosage_label')} *', _dosage),
            _field(AppLocalizations.of(context).t('dlg_med_purpose_label'), _purpose),
            _field(AppLocalizations.of(context).t('meds_possible_side_effects'), _sideEffects, maxLines: 2),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Status (Active / History)
            Text('${AppLocalizations.of(context).t('dlg_med_status_label_no_star')} *',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary(context))),
            const SizedBox(height: 8),
            _statusToggle(),
            const SizedBox(height: 14),

            // Taken-When-Needed (PRN)
            _prnCheckbox(),
            const SizedBox(height: 20),

            // Schedule section (locked when History or PRN)
            AnimatedOpacity(
              opacity: (_isHistory || _isPrn) ? 0.4 : 1,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _isHistory || _isPrn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                            (_isHistory || _isPrn)
                                ? AppLocalizations.of(context).t('dlg_med_reminder_schedule')
                                : '${AppLocalizations.of(context).t('dlg_med_reminder_schedule')} *',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary(context))),
                        if (_isHistory || _isPrn) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_outline,
                              size: 14, color: AppColors.textMuted(context)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Day picker: tap to select/deselect multiple days.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _weekDays.map(_dayToggleChip).toList(),
                    ),
                    const SizedBox(height: 12),

                    if (_schedule.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Center(
                          child: Text(AppLocalizations.of(context).t('dlg_med_select_days_hint'),
                              style: TextStyle(
                                  color: AppColors.textMuted(context),
                                  fontSize: 13)),
                        ),
                      )
                    else
                      ..._schedule
                          .asMap()
                          .entries
                          .map((e) => _buildScheduleRow(e.key, e.value)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Duration section (locked when PRN)
            AnimatedOpacity(
              opacity: _isPrn ? 0.4 : 1,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: _isPrn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                            _isPrn
                                ? AppLocalizations.of(context).t('meds_duration')
                                : '${AppLocalizations.of(context).t('meds_duration')} *',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary(context))),
                        if (_isPrn) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_outline,
                              size: 14, color: AppColors.textMuted(context)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    _dateTile(
                      label: AppLocalizations.of(context).t('meds_from_short'),
                      date: _startDate,
                      onTap: () async {
                        final d = await _pickDate(_startDate);
                        if (d != null) setState(() => _startDate = d);
                      },
                    ),
                    const SizedBox(height: 8),

                    AnimatedOpacity(
                      opacity: _isLifetime ? 0.4 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _isLifetime,
                        child: _dateTile(
                          label: AppLocalizations.of(context).t('meds_to_short'),
                          date: _endDate,
                          onTap: () async {
                            final d = await _pickDate(_endDate);
                            if (d != null) setState(() => _endDate = d);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            Opacity(
              opacity: (_isHistory || _isPrn) ? 0.4 : 1,
              child: GestureDetector(
                onTap: (_isHistory || _isPrn)
                    ? null
                    : () => setState(() => _isLifetime = !_isLifetime),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _isLifetime ? const Color(0xFF2563EB) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isLifetime
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                      ),
                      child: _isLifetime
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.all_inclusive, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(AppLocalizations.of(context).t('dlg_med_lifetime_medication'),
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context))),
                    if (_isHistory || _isPrn) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_outline,
                          size: 14, color: AppColors.textMuted(context)),
                    ],
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
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

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(AppLocalizations.of(context).t('common_cancel'),
                        style: const TextStyle(color: Color(0xFF6B7280))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(AppLocalizations.of(context).t('common_save'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(int idx, MedScheduleEntry entry) {
    final isOpen = _expandedDay == idx;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedDay = isOpen ? null : idx),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(entry.day,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary(context))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${entry.times.length}×',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                  const SizedBox(height: 10),
                  if (entry.times.isEmpty)
                    Text(AppLocalizations.of(context).t('dlg_med_no_times'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: entry.times.asMap().entries.map((t) {
                        return Chip(
                          label: Text(t.value,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w500)),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          deleteIcon:
                              const Icon(Icons.close, size: 14, color: Color(0xFF6B7280)),
                          onDeleted: () {
                            setState(() {
                              _schedule[idx].times.removeAt(t.key);
                            });
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final t = await _pickTime();
                      if (t != null) {
                        setState(() => _schedule[idx].times.add(t));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tint(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_alarm, size: 14, color: AppColors.accent(context)),
                          const SizedBox(width: 4),
                          Text(AppLocalizations.of(context).t('dlg_med_add_time'),
                              style: TextStyle(
                                  color: AppColors.accent(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    final display = date != null
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : 'Select date';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                display,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: date != null
                        ? AppColors.textPrimary(context)
                        : AppColors.textMuted(context)),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted(context)),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceAlt(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

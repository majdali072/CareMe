import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

const Map<String, List<String>> _drugInteractions = {
  'Warfarin': ['Aspirin', 'Ibuprofen'],
  'Ibuprofen': ['Aspirin', 'Warfarin', 'Lisinopril'],
  'Naproxen': ['Aspirin', 'Lisinopril'],
  'Potassium': ['Lisinopril', 'Spironolactone'],
  'Gemfibrozil': ['Atorvastatin', 'Simvastatin'],
  'Niacin': ['Atorvastatin'],
  'Digoxin': ['Metformin'],
  'Cimetidine': ['Metformin'],
};

class AddMedicationDialog extends StatefulWidget {
  final List<String> currentMedications;
  final void Function(Medication) onAdd;
  // Optional pre-fill (e.g. when launched from a CareAI action). The dialog
  // is still a confirmation step, the user must press Save.
  final Map<String, String>? initialFields;

  const AddMedicationDialog({
    super.key,
    required this.currentMedications,
    required this.onAdd,
    this.initialFields,
  });

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _sideEffectsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initialFields;
    if (init != null) {
      _nameCtrl.text = init['name'] ?? '';
      _dosageCtrl.text = init['dosage'] ?? '';
      _purposeCtrl.text = init['purpose'] ?? '';
      _sideEffectsCtrl.text = init['sideEffects'] ?? '';
    }
  }

  List<MedScheduleEntry> _schedule = [];
  int? _expandedDay;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLifetime = false;
  bool _isHistory = false;
  bool _isPrn = false;

  String? _errorMessage;
  bool _success = false;
  List<String> _interactingMeds = [];
  bool _showInteraction = false;

  // AI-assisted fields (typeahead for name, button-fill for the rest).
  List<String> _nameSuggestions = const [];
  Timer? _nameDebounce;
  bool _nameSuggestLoading = false;
  bool _aiFilling = false;
  String _lastSuggestedFor = '';

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _purposeCtrl.dispose();
    _sideEffectsCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      if (_nameSuggestions.isNotEmpty || _nameSuggestLoading) {
        setState(() {
          _nameSuggestions = const [];
          _nameSuggestLoading = false;
        });
      }
      return;
    }
    _nameDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _nameSuggestLoading = true);
      final results = await ApiService.suggestMedicationNames(trimmed);
      if (!mounted) return;
      // Drop the result if the user has moved on to a different prefix.
      if (_nameCtrl.text.trim() != trimmed) {
        setState(() => _nameSuggestLoading = false);
        return;
      }
      setState(() {
        _nameSuggestions = results;
        _nameSuggestLoading = false;
      });
    });
  }

  Future<void> _runAiFill() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _aiFilling) return;
    setState(() => _aiFilling = true);
    final filled = await ApiService.suggestMedicationFields(name);
    if (!mounted) return;
    bool didFill = false;
    void apply(TextEditingController c, String? value) {
      final v = (value ?? '').trim();
      if (v.isEmpty) return;
      // Don't clobber whatever the user has already typed.
      if (c.text.trim().isNotEmpty) return;
      c.text = v;
      didFill = true;
    }

    apply(_purposeCtrl, filled['purpose']);
    apply(_sideEffectsCtrl, filled['sideEffects']);
    setState(() {
      _aiFilling = false;
      _lastSuggestedFor = name;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(didFill
              ? 'Suggested values filled in. Please review before saving.'
              : 'No new suggestions. Review the existing values.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<String> _checkInteractions(String name) {
    final potentials = _drugInteractions[name] ?? [];
    return widget.currentMedications
        .where((m) => potentials.contains(m))
        .toList();
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
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  // Toggle a weekday on/off in the schedule. Selecting a day adds an empty
  // schedule entry (and expands it so times can be added); deselecting removes
  // it. Entries are kept in weekday order.
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
      _errorMessage = null;
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

  void _submit() {
    setState(() {
      _errorMessage = null;
      _showInteraction = false;
    });

    final t = AppLocalizations.of(context);
    // Validate name & dosage
    if (_nameCtrl.text.trim().isEmpty || _dosageCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = t.t('dlg_med_validation_name_dosage'));
      return;
    }

    // PRN meds skip schedule / date validation entirely.
    if (!_isPrn) {
      // Validate schedule has at least one day with one time.
      // History meds don't need a schedule (no more reminders needed).
      final hasValidSchedule =
          _schedule.isNotEmpty && _schedule.any((e) => e.times.isNotEmpty);
      if (!_isHistory && !hasValidSchedule) {
        setState(() => _errorMessage = t.t('dlg_med_validation_schedule'));
        return;
      }

      // Validate start date
      if (_startDate == null) {
        setState(() => _errorMessage = t.t('dlg_med_validation_start_date'));
        return;
      }

      // Validate end date or lifetime
      if (!_isLifetime && _endDate == null) {
        setState(() => _errorMessage = t.t('dlg_med_validation_end_date'));
        return;
      }
    }

    // Check drug interactions
    final interactions = _checkInteractions(_nameCtrl.text.trim());
    if (interactions.isNotEmpty) {
      setState(() {
        _showInteraction = true;
        _interactingMeds = interactions;
      });
      return;
    }

    // Auto-compute frequency from the schedule. See Medication.computedFrequency.
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

    // Build time string from first entry
    final time = _schedule.isNotEmpty && _schedule.first.times.isNotEmpty
        ? _schedule.first.times.first
        : '';

    widget.onAdd(Medication(
      name: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      frequency: freq,
      time: time,
      purpose: _purposeCtrl.text.trim(),
      sideEffects: _sideEffectsCtrl.text.trim(),
      schedule: _isPrn ? [] : _schedule,
      startDate: _isPrn ? null : _startDate,
      endDate: _isPrn ? null : (_isLifetime ? null : _endDate),
      isLifetime: _isPrn ? false : _isLifetime,
      isHistory: _isHistory,
      isPrn: _isPrn,
    ));
    // Close the dialog immediately — no success popup.
    if (mounted) Navigator.pop(context);
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
                  child: Text(AppLocalizations.of(context).t('dlg_add_medication_title'),
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
                  _buildNameFieldWithAi(),
                  const SizedBox(height: 12),
                  _field(AppLocalizations.of(context).t('dlg_med_dosage_required_star'),
                      _dosageCtrl, AppLocalizations.of(context).t('dlg_med_dosage_example')),
                  const SizedBox(height: 12),
                  _field(AppLocalizations.of(context).t('dlg_med_purpose_label'),
                      _purposeCtrl, AppLocalizations.of(context).t('dlg_med_purpose_placeholder')),
                  const SizedBox(height: 12),
                  _field(AppLocalizations.of(context).t('meds_possible_side_effects'),
                      _sideEffectsCtrl,
                      AppLocalizations.of(context).t('dlg_med_side_effects_placeholder'),
                      maxLines: 2),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Status (Active / History) ──
                  Text(AppLocalizations.of(context).t('dlg_med_status_label'),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary(context))),
                  const SizedBox(height: 8),
                  _statusToggle(),
                  const SizedBox(height: 14),

                  // ── Taken When Needed (PRN) ──
                  _prnCheckbox(),
                  const SizedBox(height: 20),

                  // ── Schedule section (locked when History or PRN) ──
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
                              const Icon(Icons.notifications_active,
                                  size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                  _isHistory
                                      ? AppLocalizations.of(context).t('dlg_med_reminder_schedule')
                                      : AppLocalizations.of(context).t('dlg_med_reminder_schedule_star'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textPrimary(context))),
                              if (_isHistory) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.lock_outline,
                                    size: 14,
                                    color: AppColors.textMuted(context)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isHistory
                                ? AppLocalizations.of(context).t('dlg_med_not_needed_history')
                                : AppLocalizations.of(context).t('dlg_med_choose_days_times'),
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted(context)),
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
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.tint(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFBFDBFE).withOpacity(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? 0.2
                                            : 1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16,
                                      color: AppColors.accent(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context).t('dlg_med_select_days_hint'),
                                      style: TextStyle(
                                          color: AppColors.accent(context),
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
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

                  // ── Duration section (locked when PRN) ──
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
                              Text(_isPrn
                                      ? AppLocalizations.of(context).t('dlg_med_duration_label')
                                      : AppLocalizations.of(context).t('dlg_med_duration_label_star'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color:
                                          AppColors.textPrimary(context))),
                              if (_isPrn) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.lock_outline,
                                    size: 14,
                                    color: AppColors.textMuted(context)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),

                          _dateTile(
                            label: AppLocalizations.of(context).t('dlg_med_start_date'),
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
                                label: AppLocalizations.of(context).t('dlg_med_end_date'),
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
                              color: _isLifetime
                                  ? const Color(0xFF2563EB)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isLifetime
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFD1D5DB),
                                width: 1.5,
                              ),
                            ),
                            child: _isLifetime
                                ? const Icon(Icons.check,
                                    size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.all_inclusive,
                              size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.of(context).t('dlg_med_lifetime_medication'),
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.textPrimary(context))),
                          if (_isHistory || _isPrn) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.lock_outline,
                                size: 14,
                                color: AppColors.textMuted(context)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Alerts
                  if (_success) _alertBox(true,
                      AppLocalizations.of(context).t('dlg_med_added_success')),
                  if (_errorMessage != null)
                    _alertBox(false, _errorMessage!),
                  if (_showInteraction) ...[
                    _alertBox(false, AppLocalizations.of(context)
                        .t('dlg_med_interactions_with', {'name': _nameCtrl.text})),
                    ..._interactingMeds.map((m) => Padding(
                          padding: const EdgeInsets.only(left: 32, bottom: 2),
                          child: Text('- $m',
                              style: const TextStyle(
                                  color: Color(0xFFB91C1C), fontSize: 13)),
                        )),
                    Padding(
                      padding: const EdgeInsets.only(left: 32, top: 4, bottom: 8),
                      child: Text(
                          AppLocalizations.of(context).t('dlg_med_consult_doctor'),
                          style: const TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _success ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(AppLocalizations.of(context).t('dlg_med_add_btn'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Schedule row ──────────────────────────────────────────────────────────
  Widget _buildScheduleRow(int idx, MedScheduleEntry entry) {
    final isOpen = _expandedDay == idx;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandedDay = isOpen ? null : idx),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(entry.day,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary(context))),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.times.isEmpty
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        entry.times.isEmpty
                            ? 'No time'
                            : '${entry.times.length}x',
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
                  Divider(color: AppColors.border(context), height: 1),
                  const SizedBox(height: 10),
                  if (entry.times.isEmpty)
                    Text(AppLocalizations.of(context).t('dlg_med_tap_add_time'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)))
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
                          side:
                              const BorderSide(color: Color(0xFFBFDBFE)),
                          deleteIcon: const Icon(Icons.close,
                              size: 14, color: Color(0xFF6B7280)),
                          onDeleted: () {
                            setState(() {
                              _schedule[idx].times.removeAt(t.key);
                            });
                          },
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final t = await _pickTime();
                      if (t != null) {
                        setState(() {
                          _schedule[idx].times.add(t);
                          _errorMessage = null;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.tint(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_alarm,
                              size: 14, color: AppColors.accent(context)),
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

  // ── Status toggle (Active / History) ─────────────────────────────────────
  // ── Taken-When-Needed (PRN) checkbox ─────────────────────────────────────
  Widget _prnCheckbox() {
    return GestureDetector(
      onTap: () => setState(() {
        _isPrn = !_isPrn;
        if (_isPrn) {
          // Clear schedule + lifetime so the data stays consistent.
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
                  ? const Icon(Icons.check,
                      size: 14, color: Colors.white)
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

  // ── Date tile ─────────────────────────────────────────────────────────────
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
                style:
                    TextStyle(fontSize: 13, color: AppColors.textPrimary(context))),
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
            Icon(Icons.chevron_right,
                size: 16, color: AppColors.textMuted(context)),
          ],
        ),
      ),
    );
  }

  // ── Text field ────────────────────────────────────────────────────────────
  // Medication name field + AI typeahead suggestions + "Suggest with AI"
  // button that fills the remaining fields. The typeahead asks the backend
  // for real medication names matching the prefix; the button asks for a
  // typical dosage / purpose / side-effects payload for the chosen name.
  Widget _buildNameFieldWithAi() {
    final canFill = _nameCtrl.text.trim().isNotEmpty && !_aiFilling;
    final hasSuggestions = _nameSuggestions.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(AppLocalizations.of(context).t('dlg_med_name_required_star'),
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w500)),
            ),
            if (_nameSuggestLoading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accent(context)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          onChanged: _onNameChanged,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).t('dlg_med_name_example'),
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            filled: true,
            fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
        if (hasSuggestions) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _nameSuggestions.length,
              padding: const EdgeInsets.symmetric(vertical: 4),
              separatorBuilder: (_, __) => Divider(
                  height: 1, color: AppColors.border(context)),
              itemBuilder: (ctx, i) {
                final n = _nameSuggestions[i];
                return InkWell(
                  onTap: () {
                    _nameCtrl.text = n;
                    _nameCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: n.length));
                    setState(() => _nameSuggestions = const []);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 14, color: AppColors.accent(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(n,
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      AppColors.textPrimary(context))),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: canFill ? _runAiFill : null,
            icon: _aiFilling
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.accent(context)),
                    ),
                  )
                : Icon(Icons.auto_awesome,
                    size: 16, color: AppColors.accent(context)),
            label: Text(
              _aiFilling
                  ? 'Asking CareAI...'
                  : (_lastSuggestedFor.isEmpty ||
                          _lastSuggestedFor != _nameCtrl.text.trim())
                      ? 'Suggest purpose & side-effects'
                      : 'Re-run AI suggestions',
              style: TextStyle(
                  fontSize: 12, color: AppColors.accent(context)),
            ),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(color: AppColors.border(context)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            filled: true,
            fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border(context))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Alert box ─────────────────────────────────────────────────────────────
  Widget _alertBox(bool success, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        border: Border.all(
            color:
                success ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(success ? Icons.check_circle : Icons.error_outline,
              color: success
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: success
                        ? const Color(0xFF15803D)
                        : const Color(0xFF991B1B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

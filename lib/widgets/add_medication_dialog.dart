import 'package:flutter/material.dart';
import '../models/app_models.dart';

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

  const AddMedicationDialog({
    super.key,
    required this.currentMedications,
    required this.onAdd,
  });

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _frequencyCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _sideEffectsCtrl = TextEditingController();

  // Schedule
  List<MedScheduleEntry> _schedule = [];
  int? _expandedDay;

  // Duration
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLifetime = false;

  // Alerts
  String? _alertType; // 'success' | 'interaction'
  List<String> _interactingMeds = [];

  static const List<String> _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _frequencyCtrl.dispose();
    _purposeCtrl.dispose();
    _sideEffectsCtrl.dispose();
    super.dispose();
  }

  List<String> _checkInteractions(String name) {
    final potentials = _drugInteractions[name] ?? [];
    return widget.currentMedications.where((m) => potentials.contains(m)).toList();
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

  void _addDay() {
    final alreadyAdded = _schedule.map((e) => e.day).toSet();
    final available = _weekDays.where((d) => !alreadyAdded.contains(d)).toList();
    if (available.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Select Day'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: available
                .map((day) => ListTile(
                      title: Text(day),
                      onTap: () {
                        setState(() {
                          _schedule.add(MedScheduleEntry(day: day, times: []));
                          _expandedDay = _schedule.length - 1;
                        });
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty || _dosageCtrl.text.trim().isEmpty) return;

    final interactions = _checkInteractions(_nameCtrl.text.trim());
    if (interactions.isNotEmpty) {
      setState(() {
        _alertType = 'interaction';
        _interactingMeds = interactions;
      });
      return;
    }

    // Build frequency string from schedule
    final freq = _frequencyCtrl.text.trim().isNotEmpty
        ? _frequencyCtrl.text.trim()
        : (_schedule.length == 7
            ? 'Daily'
            : _schedule.isNotEmpty
                ? '${_schedule.length}x/week'
                : '');

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
      schedule: _schedule,
      startDate: _startDate,
      endDate: _isLifetime ? null : _endDate,
      isLifetime: _isLifetime,
    ));
    setState(() => _alertType = 'success');
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
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
                const Expanded(
                  child: Text('Add Medication',
                      style: TextStyle(
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
                  _field('Medication Name', _nameCtrl, 'e.g., Aspirin'),
                  const SizedBox(height: 12),
                  _field('Dosage', _dosageCtrl, 'e.g., 100mg'),
                  const SizedBox(height: 12),
                  _field('Frequency', _frequencyCtrl, 'e.g., Daily, 2x/week'),
                  const SizedBox(height: 12),
                  _field('Purpose', _purposeCtrl, 'e.g., Pain relief'),
                  const SizedBox(height: 12),
                  _field('Possible Side Effects', _sideEffectsCtrl, 'e.g., Nausea', maxLines: 2),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Schedule section
                  Row(
                    children: [
                      const Text('Schedule',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF111418))),
                      const Spacer(),
                      GestureDetector(
                        onTap: _addDay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text('Add Day',
                                  style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_schedule.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Center(
                        child: Text('No days added yet',
                            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                      ),
                    )
                  else
                    ..._schedule.asMap().entries.map((e) =>
                        _buildScheduleRow(e.key, e.value)),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Duration section
                  const Text('Duration',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF111418))),
                  const SizedBox(height: 10),

                  _dateTile(
                    label: 'From',
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
                        label: 'To',
                        date: _endDate,
                        onTap: () async {
                          final d = await _pickDate(_endDate);
                          if (d != null) setState(() => _endDate = d);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Lifetime checkbox
                  GestureDetector(
                    onTap: () => setState(() => _isLifetime = !_isLifetime),
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
                        const Text('Lifetime medication',
                            style: TextStyle(fontSize: 14, color: Color(0xFF111418))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Alerts
                  if (_alertType == 'success')
                    _alert(true, 'Medication added successfully!', []),
                  if (_alertType == 'interaction')
                    _alert(false, '${_nameCtrl.text} has known interactions with:', _interactingMeds),

                  const SizedBox(height: 8),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Add Medication',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  // ── Schedule row (per day) ────────────────────────────────────────────────
  Widget _buildScheduleRow(int idx, MedScheduleEntry entry) {
    final isOpen = _expandedDay == idx;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF111418))),
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
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _schedule.removeAt(idx);
                        if (_expandedDay == idx) _expandedDay = null;
                      });
                    },
                    child: const Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 4),
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
                    const Text('No times added',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))
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
                          deleteIcon: const Icon(Icons.close,
                              size: 14, color: Color(0xFF6B7280)),
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_alarm, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text('Add Time',
                              style: TextStyle(
                                  color: Color(0xFF2563EB),
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
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                display,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: date != null
                        ? const Color(0xFF111418)
                        : const Color(0xFF9CA3AF)),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  // ── Text field ────────────────────────────────────────────────────────────
  Widget _field(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111418),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ── Alert widget ──────────────────────────────────────────────────────────
  Widget _alert(bool success, String message, List<String> meds) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        border: Border.all(
            color: success ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message,
                    style: TextStyle(
                        color: success
                            ? const Color(0xFF15803D)
                            : const Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                ...meds.map((m) => Text('• $m',
                    style: const TextStyle(
                        color: Color(0xFFB91C1C), fontSize: 13))),
                if (!success)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                        'Please consult your doctor before taking this medication.',
                        style: TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

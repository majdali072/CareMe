import 'package:flutter/material.dart';
import '../models/app_models.dart';

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

  void _save() {
    final updated = widget.medication.copyWith(
      name: _name.text.trim(),
      dosage: _dosage.text.trim(),
      frequency: _frequency.text.trim(),
      purpose: _purpose.text.trim(),
      sideEffects: _sideEffects.text.trim(),
      schedule: _schedule,
      startDate: _startDate,
      endDate: _isLifetime ? null : _endDate,
      isLifetime: _isLifetime,
    );
    widget.onSave(updated);
    Navigator.pop(context);
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
                  child: Text('Edit Medication',
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
            _field('Name', _name),
            _field('Dosage', _dosage),
            _field('Frequency', _frequency),
            _field('Purpose', _purpose),
            _field('Possible Side Effects', _sideEffects, maxLines: 2),

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
              ..._schedule.asMap().entries.map((e) => _buildScheduleRow(e.key, e.value)),

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
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF6B7280))),
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
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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

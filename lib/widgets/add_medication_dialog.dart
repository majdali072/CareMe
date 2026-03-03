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

  const AddMedicationDialog({super.key, required this.currentMedications, required this.onAdd});

  @override
  State<AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<AddMedicationDialog> {
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final List<String> _days = [];
  String? _alertType; // 'success' | 'interaction'
  List<String> _interactingMeds = [];

  static const List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  List<String> _checkInteractions(String name) {
    final potentials = _drugInteractions[name] ?? [];
    return widget.currentMedications.where((m) => potentials.contains(m)).toList();
  }

  void _submit() {
    if (_nameCtrl.text.isEmpty || _dosageCtrl.text.isEmpty || _timeCtrl.text.isEmpty || _days.isEmpty) return;

    final interactions = _checkInteractions(_nameCtrl.text.trim());
    if (interactions.isNotEmpty) {
      setState(() { _alertType = 'interaction'; _interactingMeds = interactions; });
      return;
    }

    widget.onAdd(Medication(
      name: _nameCtrl.text,
      dosage: _dosageCtrl.text,
      frequency: _days.length == 7 ? 'Daily' : '${_days.length}x/week',
      time: _timeCtrl.text,
      purpose: '',
      sideEffects: '',
    ));
    setState(() => _alertType = 'success');
    Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) Navigator.pop(context); });
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(
                children: [
                  const Expanded(child: Text('Add Medication', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _field('Medication Name', _nameCtrl, 'e.g., Aspirin'),
                    const SizedBox(height: 14),
                    _field('Dosage', _dosageCtrl, 'e.g., 100mg'),
                    const SizedBox(height: 14),
                    // Days
                    Align(alignment: Alignment.centerLeft, child: const Text('Days to Take', style: TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: _weekdays.map((day) => GestureDetector(
                          onTap: () => setState(() => _days.contains(day) ? _days.remove(day) : _days.add(day)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(value: _days.contains(day), onChanged: (_) => setState(() => _days.contains(day) ? _days.remove(day) : _days.add(day)), activeColor: const Color(0xFF2563EB)),
                                Text(day, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _field('Time', _timeCtrl, 'e.g., 8:00 AM'),
                    const SizedBox(height: 14),
                    if (_alertType == 'success')
                      _alert(true, 'Medication added successfully!', []),
                    if (_alertType == 'interaction')
                      _alert(false, '${_nameCtrl.text} has known interactions with:', _interactingMeds),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Add Medication', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
            hintText: hint,
            filled: true, fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _alert(bool success, String message, List<String> meds) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        border: Border.all(color: success ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(success ? Icons.check_circle : Icons.error_outline, color: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: success ? const Color(0xFF15803D) : const Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500)),
                ...meds.map((m) => Text('• $m', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
                if (!success) const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Please consult your doctor before taking this medication.', style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/app_models.dart';

class EditMedicationDialog extends StatefulWidget {
  final Medication medication;
  final void Function(Medication) onSave;

  const EditMedicationDialog({super.key, required this.medication, required this.onSave});

  @override
  State<EditMedicationDialog> createState() => _EditMedicationDialogState();
}

class _EditMedicationDialogState extends State<EditMedicationDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _freqCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _purposeCtrl;
  late final TextEditingController _sideEffectsCtrl;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _nameCtrl = TextEditingController(text: m.name);
    _dosageCtrl = TextEditingController(text: m.dosage);
    _freqCtrl = TextEditingController(text: m.frequency);
    _timeCtrl = TextEditingController(text: m.time);
    _purposeCtrl = TextEditingController(text: m.purpose);
    _sideEffectsCtrl = TextEditingController(text: m.sideEffects);
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
                  const Expanded(child: Text('Edit Medication', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _field('Medication Name', _nameCtrl),
                    const SizedBox(height: 12),
                    _field('Dosage', _dosageCtrl),
                    const SizedBox(height: 12),
                    _field('Frequency', _freqCtrl),
                    const SizedBox(height: 12),
                    _field('Time', _timeCtrl),
                    const SizedBox(height: 12),
                    _field('Purpose', _purposeCtrl),
                    const SizedBox(height: 12),
                    _field('Side Effects', _sideEffectsCtrl),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onSave(widget.medication.copyWith(
                            name: _nameCtrl.text,
                            dosage: _dosageCtrl.text,
                            frequency: _freqCtrl.text,
                            time: _timeCtrl.text,
                            purpose: _purposeCtrl.text,
                            sideEffects: _sideEffectsCtrl.text,
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

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            filled: true, fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

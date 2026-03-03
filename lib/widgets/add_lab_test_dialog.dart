import 'package:flutter/material.dart';
import '../models/app_models.dart';

class AddLabTestDialog extends StatefulWidget {
  final void Function(LabTest) onAdd;
  const AddLabTestDialog({super.key, required this.onAdd});

  @override
  State<AddLabTestDialog> createState() => _AddLabTestDialogState();
}

class _AddLabTestDialogState extends State<AddLabTestDialog> {
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  bool _showSuccess = false;

  void _submit() {
    if (_nameCtrl.text.isEmpty || _dateCtrl.text.isEmpty || _doctorCtrl.text.isEmpty) return;
    widget.onAdd(LabTest(name: _nameCtrl.text, date: _dateCtrl.text, doctor: _doctorCtrl.text, fileName: '${_nameCtrl.text.replaceAll(' ', '_')}.pdf'));
    setState(() => _showSuccess = true);
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
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Row(
                children: [
                  const Expanded(child: Text('Add Lab Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field('Test Name', _nameCtrl, 'e.g., Complete Blood Count'),
                  const SizedBox(height: 14),
                  _field('Test Date', _dateCtrl, 'e.g., November 5, 2025'),
                  const SizedBox(height: 14),
                  _field('Ordered By', _doctorCtrl, "Doctor's name"),
                  const SizedBox(height: 14),
                  // File upload placeholder
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upload Results (Optional)', style: TextStyle(fontSize: 13, color: Color(0xFF111418), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.upload_file, color: Color(0xFF1976D2), size: 20),
                              SizedBox(width: 8),
                              Text('Choose file', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showSuccess) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), border: Border.all(color: const Color(0xFF86EFAC)), borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                          SizedBox(width: 8),
                          Text('Lab test added successfully!', style: TextStyle(color: Color(0xFF15803D), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
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
                      child: const Text('Add Lab Test', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
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
}

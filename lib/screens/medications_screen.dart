import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../widgets/edit_medication_dialog.dart';

class MedicationsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final List<Medication> medications;
  final List<LabTest> labTests;
  final void Function(List<Medication>) onMedicationsChanged;
  final void Function(List<LabTest>) onLabTestsChanged;

  const MedicationsScreen({
    super.key,
    required this.onBack,
    required this.medications,
    required this.labTests,
    required this.onMedicationsChanged,
    required this.onLabTestsChanged,
  });

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  int? _expandedMed;
  int? _expandedLab;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: 14,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onBack,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Health Records', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medications Section
                const Text('MEDICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ...widget.medications.asMap().entries.map((e) => _buildMedCard(e.key, e.value)),

                const SizedBox(height: 20),

                // Lab Tests Section
                const Text('LAB TEST RESULTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF), letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ...widget.labTests.asMap().entries.map((e) => _buildLabCard(e.key, e.value)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedCard(int index, Medication med) {
    final isExpanded = _expandedMed == index;
    return GestureDetector(
      onTap: () => setState(() => _expandedMed = isExpanded ? null : index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.medication, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111418), fontSize: 15)),
                        Text('${med.dosage} • ${med.frequency}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconBtn(Icons.edit_outlined, const Color(0xFF2563EB), () {
                        showDialog(
                          context: context,
                          builder: (_) => EditMedicationDialog(
                            medication: med,
                            onSave: (updated) {
                              final meds = List<Medication>.from(widget.medications);
                              meds[index] = updated;
                              widget.onMedicationsChanged(meds);
                            },
                          ),
                        );
                      }),
                      _iconBtn(Icons.delete_outline, const Color(0xFF2563EB), () {
                        final meds = List<Medication>.from(widget.medications)..removeAt(index);
                        if (_expandedMed == index) setState(() => _expandedMed = null);
                        widget.onMedicationsChanged(meds);
                      }),
                    ],
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFF3F4F6), height: 1),
                const SizedBox(height: 14),
                _expandedRow(Icons.access_time, 'Time', med.time),
                const SizedBox(height: 10),
                _expandedText('Purpose', med.purpose),
                const SizedBox(height: 10),
                _expandedText('Possible Side Effects', med.sideEffects),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabCard(int index, LabTest lab) {
    final isExpanded = _expandedLab == index;
    return GestureDetector(
      onTap: () => setState(() => _expandedLab = isExpanded ? null : index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lab.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111418), fontSize: 15)),
                        Text(lab.date, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                        child: const Text('File', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      _iconBtn(Icons.delete_outline, const Color(0xFF2563EB), () {
                        final labs = List<LabTest>.from(widget.labTests)..removeAt(index);
                        if (_expandedLab == index) setState(() => _expandedLab = null);
                        widget.onLabTestsChanged(labs);
                      }),
                    ],
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFF3F4F6), height: 1),
                const SizedBox(height: 14),
                _expandedText('Ordered by', lab.doctor),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, color: Color(0xFF1D4ED8), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(lab.fileName, style: const TextStyle(color: Color(0xFF1E3A5F), fontSize: 13))),
                      const Icon(Icons.download_outlined, color: Color(0xFF1D4ED8), size: 18),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _expandedRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF111418))),
          ],
        ),
      ],
    );
  }

  Widget _expandedText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF111418))),
      ],
    );
  }
}

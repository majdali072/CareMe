import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
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
  int? _scheduleOpenMed;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  static String _formatCountdown(Duration d) {
    if (d.inDays > 0) {
      final h = d.inHours % 24;
      return '${d.inDays}d ${h}h';
    }
    final h = d.inHours;
    final min = d.inMinutes % 60;
    if (h > 0) return '${h}h ${min}m';
    return '${min}m';
  }

  Future<void> _downloadFile(LabTest lab) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );
      final bytes = await ApiService.downloadLabTestFile(lab.id!);

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File download not supported on web')),
        );
        return;
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save ${lab.fileName}',
        fileName: lab.fileName,
        bytes: bytes,
      );

      if (savePath != null) {
        // On desktop, saveFile only returns a path; we still have to write bytes.
        // On Android/iOS, file_picker writes the bytes itself when bytes: is passed.
        if (!Platform.isAndroid && !Platform.isIOS) {
          final file = File(savePath);
          await file.writeAsBytes(bytes);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  void _openEditDialog(int index, Medication med) {
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
  }

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
                      child: Text(
                        'Health Records',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
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
                // Medications
                const Text('MEDICATIONS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ...widget.medications
                    .asMap()
                    .entries
                    .map((e) => _buildMedCard(e.key, e.value)),

                const SizedBox(height: 20),

                // Lab Tests
                const Text('LAB TEST RESULTS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                        letterSpacing: 1.2)),
                const SizedBox(height: 10),
                ...widget.labTests
                    .asMap()
                    .entries
                    .map((e) => _buildLabCard(e.key, e.value)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Med Card ──────────────────────────────────────────────────────────────
  Widget _buildMedCard(int index, Medication med) {
    final isExpanded = _expandedMed == index;
    final scheduleOpen = _scheduleOpenMed == index;

    return GestureDetector(
      onTap: () => setState(() => _expandedMed = isExpanded ? null : index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14)),
                    child:
                        const Icon(Icons.medication, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111418),
                                fontSize: 15)),
                        Text('${med.dosage} • ${med.frequency}',
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 13)),
                        Builder(builder: (_) {
                          final next = NotificationService.nextReminderTime(med);
                          if (next == null) return const SizedBox.shrink();
                          final diff = next.difference(DateTime.now());
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_active,
                                    size: 13, color: Color(0xFFF97316)),
                                const SizedBox(width: 4),
                                Text(
                                  'Next reminder in ${_formatCountdown(diff)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFF97316),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iconBtn(Icons.edit_outlined, const Color(0xFF2563EB),
                          () => _openEditDialog(index, med)),
                      _iconBtn(Icons.delete_outline, const Color(0xFF2563EB),
                          () {
                        final meds = List<Medication>.from(widget.medications)
                          ..removeAt(index);
                        if (_expandedMed == index) {
                          setState(() => _expandedMed = null);
                        }
                        widget.onMedicationsChanged(meds);
                      }),
                    ],
                  ),
                ],
              ),

              // Expanded section
              if (isExpanded) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFF3F4F6), height: 1),
                const SizedBox(height: 14),

                _buildScheduleSection(index, med, scheduleOpen),
                const SizedBox(height: 12),
                _buildDurationSection(med),
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

  // ── Schedule section ──────────────────────────────────────────────────────
  Widget _buildScheduleSection(int medIndex, Medication med, bool isOpen) {
    final hasSchedule = med.schedule != null && med.schedule!.isNotEmpty;

    return GestureDetector(
      onTap: () =>
          setState(() => _scheduleOpenMed = isOpen ? null : medIndex),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Schedule',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  if (!hasSchedule)
                    Text(
                      med.time.isNotEmpty ? med.time : '—',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF111418)),
                    ),
                ],
              ),
              const Spacer(),
              if (hasSchedule)
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280), size: 20),
                ),
            ],
          ),
          if (hasSchedule && isOpen) ...[
            const SizedBox(height: 8),
            ...med.schedule!.map((entry) => _buildDayRow(entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildDayRow(MedScheduleEntry entry) {
    return Container(
      margin: const EdgeInsets.only(left: 24, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              entry.day,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: entry.times.map((t) => _timeChip(t)).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '×${entry.times.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(time,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.w500)),
    );
  }

  // ── Duration section ──────────────────────────────────────────────────────
  Widget _buildDurationSection(Medication med) {
    final isLifetime = med.isLifetime ?? false;

    String fromStr =
        med.startDate != null ? _formatDate(med.startDate!) : '—';
    String toStr = isLifetime
        ? 'Lifetime'
        : (med.endDate != null ? _formatDate(med.endDate!) : '—');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Duration',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('From',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    const SizedBox(height: 2),
                    Text(fromStr,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111418))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward,
                  size: 16, color: Color(0xFF9CA3AF)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('To',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    const SizedBox(height: 2),
                    isLifetime
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.all_inclusive,
                                  size: 14, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text('Lifetime',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2563EB))),
                            ],
                          )
                        : Text(toStr,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF111418))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Lab Card ──────────────────────────────────────────────────────────────
  Widget _buildLabCard(int index, LabTest lab) {
    final isExpanded = _expandedLab == index;
    return GestureDetector(
      onTap: () =>
          setState(() => _expandedLab = isExpanded ? null : index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.description_outlined,
                        color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lab.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111418),
                                fontSize: 15)),
                        Text(lab.date,
                            style: const TextStyle(
                                color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('File',
                            style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      _iconBtn(Icons.delete_outline, const Color(0xFF2563EB),
                          () {
                        final labs = List<LabTest>.from(widget.labTests)
                          ..removeAt(index);
                        if (_expandedLab == index) {
                          setState(() => _expandedLab = null);
                        }
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
                if (lab.hasFile)
                  GestureDetector(
                    onTap: () => _downloadFile(lab),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              color: Color(0xFF1D4ED8), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(lab.fileName,
                                  style: const TextStyle(
                                      color: Color(0xFF1E3A5F),
                                      fontSize: 13))),
                          const Icon(Icons.download_outlined,
                              color: Color(0xFF1D4ED8), size: 18),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.description_outlined,
                            color: Color(0xFF9CA3AF), size: 18),
                        SizedBox(width: 8),
                        Text('No file uploaded',
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 13)),
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

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _expandedText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF111418))),
      ],
    );
  }
}

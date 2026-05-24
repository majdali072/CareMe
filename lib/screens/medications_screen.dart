import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/edit_medication_dialog.dart';
import '../theme/app_theme.dart';

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
  int? _expandedHistoryMed;
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
    final t = AppLocalizations.of(context);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('meds_downloading'))),
      );
      final bytes = await ApiService.downloadLabTestFile(lab.id!);

      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.t('meds_download_not_supported_web'))),
        );
        return;
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: t.t('meds_save_dialog_title', {'filename': lab.fileName}),
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
            SnackBar(content: Text(t.t('meds_saved_to', {'path': savePath}))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)
              .t('meds_download_failed', {'error': e.toString()}))),
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
          // Replace by id — `index` is into the filtered active list,
          // not into widget.medications.
          final meds = widget.medications.map((m) {
            if (m.id != null && m.id == med.id) return updated;
            return m;
          }).toList();
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
              children: () {
                final activeMeds = widget.medications
                    .where((m) => !m.isPastOrHistory)
                    .toList();
                final historyMeds = widget.medications
                    .where((m) => m.isPastOrHistory)
                    .toList();

                return [
                  // Active medications
                  Text(AppLocalizations.of(context).t('meds_section_meds'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted(context),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  ...activeMeds
                      .asMap()
                      .entries
                      .map((e) => _buildMedCard(e.key, e.value)),

                  const SizedBox(height: 20),

                  // Lab Tests
                  Text(AppLocalizations.of(context).t('meds_section_labs'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted(context),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  ...widget.labTests
                      .asMap()
                      .entries
                      .map((e) => _buildLabCard(e.key, e.value)),

                  const SizedBox(height: 20),

                  // Medication History
                  Text(AppLocalizations.of(context).t('meds_section_history'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted(context),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  ...historyMeds
                      .asMap()
                      .entries
                      .map((e) => _buildHistoryMedCard(e.key, e.value)),
                ];
              }(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Med Card (active) ────────────────────────────────────────────────────
  Widget _buildMedCard(int index, Medication med) =>
      _buildMedCardCommon(index, med, isHistorySection: false);

  /// Shared card builder for active & history meds so the designs match.
  Widget _buildMedCardCommon(int index, Medication med,
      {required bool isHistorySection}) {
    final isExpanded = isHistorySection
        ? _expandedHistoryMed == index
        : _expandedMed == index;
    final scheduleOpen =
        !isHistorySection && _scheduleOpenMed == index;

    void toggleExpand() {
      setState(() {
        if (isHistorySection) {
          _expandedHistoryMed = isExpanded ? null : index;
        } else {
          _expandedMed = isExpanded ? null : index;
        }
      });
    }

    final t = AppLocalizations.of(context);
    final subtitle = med.isPrn
        ? '${t.t('meds_as_needed')}${med.dosage.isNotEmpty ? ' • ${med.dosage}' : ''}'
        : '${med.dosage}${med.dosage.isNotEmpty && med.computedFrequency.isNotEmpty ? ' • ' : ''}${med.computedFrequency}';

    return GestureDetector(
      onTap: toggleExpand,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                                fontSize: 15)),
                        Text(subtitle,
                            style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 13)),
                        if (!isHistorySection)
                          Builder(builder: (_) {
                            final next =
                                NotificationService.nextReminderTime(med);
                            if (next == null) return const SizedBox.shrink();
                            final diff = next.difference(DateTime.now());
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.notifications_active,
                                      size: 13, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.t('meds_next_reminder_in', {'time': _formatCountdown(diff)}),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2563EB),
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
                      if (!isHistorySection)
                        _iconBtn(Icons.check_circle_outline,
                            const Color(0xFF16A34A), () {
                          // Move to history. Ends today, lifetime cleared,
                          // schedule wiped (no more reminders).
                          final today = DateTime.now();
                          final endToday =
                              DateTime(today.year, today.month, today.day);
                          final updated = widget.medications.map((m) {
                            if (m.id != null && m.id == med.id) {
                              return m.copyWith(
                                isHistory: true,
                                isLifetime: false,
                                endDate: endToday,
                                schedule: [],
                              );
                            }
                            return m;
                          }).toList();
                          if (_expandedMed == index) {
                            setState(() => _expandedMed = null);
                          }
                          widget.onMedicationsChanged(updated);
                        }),
                      _iconBtn(Icons.edit_outlined, const Color(0xFF2563EB),
                          () => _openEditDialog(index, med)),
                      _iconBtn(Icons.delete_outline, const Color(0xFF2563EB),
                          () async {
                        if (isHistorySection && med.id != null) {
                          try {
                            await ApiService.deleteMedication(med.id!);
                          } catch (_) {}
                        }
                        final meds = widget.medications
                            .where((m) => m.id == null || m.id != med.id)
                            .toList();
                        if (isHistorySection) {
                          if (_expandedHistoryMed == index) {
                            setState(() => _expandedHistoryMed = null);
                          }
                        } else {
                          if (_expandedMed == index) {
                            setState(() => _expandedMed = null);
                          }
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
                Divider(color: AppColors.border(context), height: 1),
                const SizedBox(height: 14),

                // Schedule: PRN shows a static label; otherwise the normal
                // collapsible schedule. For history we render it flat.
                if (med.isPrn)
                  _buildPrnScheduleRow()
                else if (isHistorySection)
                  _buildHistoryScheduleBlock(med)
                else
                  _buildScheduleSection(index, med, scheduleOpen),

                if (!med.isPrn) ...[
                  const SizedBox(height: 12),
                  _buildDurationSection(med),
                  const SizedBox(height: 10),
                  _expandedText(t.t('meds_frequency'),
                      med.computedFrequency.isNotEmpty
                          ? med.computedFrequency
                          : '—'),
                ],
                const SizedBox(height: 10),
                _expandedText(t.t('meds_purpose'),
                    med.purpose.isNotEmpty ? med.purpose : '—'),
                const SizedBox(height: 10),
                _expandedText(t.t('meds_possible_side_effects'),
                    med.sideEffects.isNotEmpty ? med.sideEffects : '—'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Inline read-only schedule block for history meds — shows all days/times
  /// at once (not collapsible).
  Widget _buildHistoryScheduleBlock(Medication med) {
    final hasSchedule =
        med.schedule != null && med.schedule!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time,
                size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).t('meds_schedule_label_short'),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textMuted(context))),
          ],
        ),
        const SizedBox(height: 8),
        if (hasSchedule)
          ...med.schedule!.map(_buildDayRow)
        else
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(med.time.isNotEmpty ? med.time : '—',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context))),
          ),
      ],
    );
  }

  /// Static "Taken when needed" row used under Schedule for PRN meds.
  Widget _buildPrnScheduleRow() {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 16, color: Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).t('meds_schedule_label_short'),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textMuted(context))),
            Text(AppLocalizations.of(context).t('meds_taken_when_needed'),
                style: TextStyle(
                    fontSize: 14, color: AppColors.textPrimary(context))),
          ],
        ),
      ],
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
                  Text(AppLocalizations.of(context).t('meds_schedule_label_short'),
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
                  if (!hasSchedule)
                    Text(
                      med.time.isNotEmpty ? med.time : '—',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textPrimary(context)),
                    ),
                ],
              ),
              const Spacer(),
              if (hasSchedule)
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary(context), size: 20),
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
        color: AppColors.surface(context),
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
    final t = AppLocalizations.of(context);
    final isLifetime = med.isLifetime ?? false;

    String fromStr =
        med.startDate != null ? _formatDate(med.startDate!) : '—';
    String toStr = isLifetime
        ? t.t('meds_lifetime_short')
        : (med.endDate != null ? _formatDate(med.endDate!) : '—');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.t('meds_duration'),
              style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('meds_from_short'),
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                    const SizedBox(height: 2),
                    Text(fromStr,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward,
                  size: 16, color: AppColors.textMuted(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t.t('meds_to_short'),
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                    const SizedBox(height: 2),
                    isLifetime
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.all_inclusive,
                                  size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(t.t('meds_lifetime_short'),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2563EB))),
                            ],
                          )
                        : Text(toStr,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary(context))),
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
          color: AppColors.surface(context),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.description_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lab.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                                fontSize: 15)),
                        Text(lab.date,
                            style: TextStyle(
                                color: AppColors.textSecondary(context), fontSize: 13)),
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
                            color: AppColors.tint(context),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(AppLocalizations.of(context).t('meds_file_chip'),
                            style: TextStyle(
                                color: AppColors.accent(context),
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
                Divider(color: AppColors.border(context), height: 1),
                const SizedBox(height: 14),
                _expandedText(AppLocalizations.of(context).t('meds_ordered_by'), lab.doctor),
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
                        color: AppColors.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            color: Color(0xFF9CA3AF), size: 18),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context).t('meds_no_file_uploaded'),
                            style: const TextStyle(
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

  // ── History card (shares design with active cards) ───────────────────────
  Widget _buildHistoryMedCard(int index, Medication med) =>
      _buildMedCardCommon(index, med, isHistorySection: true);

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    // Default brand blue reroutes to the theme-aware accent so it stays
    // legible on dark backgrounds.
    final iconColor =
        color == const Color(0xFF2563EB) ? AppColors.accent(context) : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
            color: AppColors.tint(context),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  Widget _expandedText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context))),
      ],
    );
  }
}

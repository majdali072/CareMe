import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final String userName;
  final void Function(String) onNavigate;
  final List<Medication> medications;
  final List<Appointment> appointments;
  final List<LabTest> labTests;
  final Uint8List? profilePhoto;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.onNavigate,
    required this.medications,
    required this.appointments,
    required this.labTests,
    this.profilePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Only active meds appear in "Most Frequent" (exclude history + PRN
    // since PRN meds have no recurring schedule).
    final topMeds = medications
        .where((m) => !m.isPastOrHistory && !m.isPrn)
        .take(3)
        .toList();
    // "Next appointment" should be the soonest upcoming one.
    final upcomingSorted = appointments
        .where((a) => !a.isPast)
        .toList()
      ..sort((a, b) {
        final da = a.fullDate ?? DateTime(2100);
        final db = b.fullDate ?? DateTime(2100);
        return da.compareTo(db);
      });
    final nextApt = upcomingSorted.isNotEmpty ? upcomingSorted.first : null;
    // Latest Lab Tests: last 5 entries (assumes the list is already in
    // reverse-chronological order from the backend).
    final latestLabs = labTests.take(5).toList();

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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CareMe', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    GestureDetector(
                      onTap: () => onNavigate('account'),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          image: profilePhoto != null
                              ? DecorationImage(
                                  image: MemoryImage(profilePhoto!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: profilePhoto == null
                            ? Center(
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                // Most Frequent Medications
                _buildCard(
                  context: context,
                  icon: Icons.medication_rounded,
                  title: t.t('home_most_frequent_meds'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: topMeds.isEmpty
                        ? [Padding(padding: const EdgeInsets.all(12), child: Text(t.t('home_no_meds_added'), style: TextStyle(color: AppColors.textSecondary(context))))]
                        : topMeds.asMap().entries.map((e) {
                            final med = e.value;
                            final isLast = e.key == topMeds.length - 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border(context))),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(med.name, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                                  const SizedBox(height: 2),
                                  Text('${med.dosage} • ${med.computedFrequency}', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                                  if (med.time.isNotEmpty)
                                    Text(med.time, style: const TextStyle(color: Color(0xFF1976D2), fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // Next Appointment
                _buildCard(
                  context: context,
                  icon: Icons.calendar_today_rounded,
                  title: t.t('home_next_appointment'),
                  child: nextApt == null
                      ? Padding(padding: const EdgeInsets.all(12), child: Text(t.t('home_upcoming_empty'), style: TextStyle(color: AppColors.textSecondary(context))))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nextApt.title,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context))),
                            if (nextApt.type.isNotEmpty)
                              Text(nextApt.type,
                                  style: TextStyle(
                                      color: AppColors.textSecondary(context),
                                      fontSize: 13)),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: Color(0xFF1976D2)),
                              const SizedBox(width: 4),
                              Text(_formatFullDate(nextApt, context),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary(context))),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.access_time,
                                  size: 14, color: Color(0xFF1976D2)),
                              const SizedBox(width: 4),
                              Text(nextApt.time,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary(context))),
                            ]),
                            if (nextApt.location.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: Color(0xFF1976D2)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(nextApt.location,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary(
                                              context)),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                            ],
                          ],
                        ),
                ),

                const SizedBox(height: 14),

                // Latest Lab Tests (last 5)
                _buildCard(
                  context: context,
                  icon: Icons.description_outlined,
                  title: t.t('home_latest_labs'),
                  child: latestLabs.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(t.t('home_no_labs_added'),
                              style: TextStyle(
                                  color: AppColors.textSecondary(context))))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: latestLabs.asMap().entries.map((e) {
                            final lab = e.value;
                            final isLast = e.key == latestLabs.length - 1;
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                            color:
                                                AppColors.border(context))),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.description_outlined,
                                      size: 16,
                                      color: AppColors.accent(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(lab.name,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: AppColors.textPrimary(
                                                    context))),
                                        if (lab.date.isNotEmpty)
                                          Text(lab.date,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .textSecondary(
                                                          context))),
                                      ],
                                    ),
                                  ),
                                  if (lab.hasFile)
                                    Icon(Icons.attach_file,
                                        size: 14,
                                        color:
                                            AppColors.textMuted(context)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _monthKeys = [
    'month_jan', 'month_feb', 'month_mar', 'month_apr',
    'month_may', 'month_jun', 'month_jul', 'month_aug',
    'month_sep', 'month_oct', 'month_nov', 'month_dec',
  ];

  String _formatFullDate(Appointment apt, BuildContext context) {
    final t = AppLocalizations.of(context);
    final d = apt.fullDate;
    if (d == null) return t.t('home_day_prefix', {'date': apt.date.toString()});
    return '${t.t(_monthKeys[d.month - 1])} ${d.day}, ${d.year}';
  }

  Widget _buildCard({required IconData icon, required String title, required Widget child, required BuildContext context}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

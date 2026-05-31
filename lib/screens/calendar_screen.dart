import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../services/google_calendar_service.dart';
import '../widgets/edit_appointment_dialog.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback onBack;
  final List<Appointment> appointments;
  final void Function(List<Appointment>) onAppointmentsChanged;

  const CalendarScreen({
    super.key,
    required this.onBack,
    required this.appointments,
    required this.onAppointmentsChanged,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
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
                    left: 16, top: 14,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onBack,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(AppLocalizations.of(context).t('cal_appointments_title'),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                // Indices into the original list so edit/delete still work
                final indexed = widget.appointments
                    .asMap()
                    .entries
                    .toList();
                final upcoming = indexed
                    .where((e) => !e.value.isPast)
                    .toList();
                final previous = indexed
                    .where((e) => e.value.isPast)
                    .toList();

                return [
                  Text(AppLocalizations.of(context).t('cal_section_upcoming'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted(context),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 10),

                  if (upcoming.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
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
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 48,
                              color: AppColors.textMuted(context)),
                          const SizedBox(height: 12),
                          Text(AppLocalizations.of(context).t('home_upcoming_empty'),
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(AppLocalizations.of(context).t('cal_empty_add_next'),
                              style: TextStyle(
                                  color: AppColors.textMuted(context),
                                  fontSize: 13)),
                        ],
                      ),
                    ),

                  ...upcoming.map((e) => _buildAptCard(e.key, e.value)),

                  const SizedBox(height: 24),

                  Text(AppLocalizations.of(context).t('cal_section_previous'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted(context),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 10),

                  ...previous
                      .map((e) => _buildPreviousAptCard(e.key, e.value)),
                ];
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAptCard(int index, Appointment apt) {
    final t = AppLocalizations.of(context);
    // Show the actual picked date in the pill.
    final String dateLabel;
    final d = apt.fullDate;
    if (d != null) {
      dateLabel = '${t.t(_monthAbbrKeys[d.month - 1])} ${d.day}';
    } else {
      dateLabel = t.t('home_day_prefix', {'date': apt.date.toString()});
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          // Vertically center the whole row so the edit/delete buttons sit
          // in the middle of the card's height regardless of content.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(apt.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                          fontSize: 15)),
                  if (apt.doctor.isNotEmpty || apt.type.isNotEmpty)
                    Text(apt.doctor.isNotEmpty ? apt.doctor : apt.type,
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.access_time, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Text(apt.time, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(apt.location,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(context)),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date pill + edit/delete — vertically centered because the
            // parent Row uses CrossAxisAlignment.center.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.tint(context),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(dateLabel,
                      style: TextStyle(
                          color: AppColors.accent(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconBtn(Icons.edit_outlined, () {
                      showDialog(
                        context: context,
                        builder: (_) => EditAppointmentDialog(
                          appointment: apt,
                          onSave: (updated) {
                            final apts = List<Appointment>.from(widget.appointments);
                            apts[index] = updated;
                            widget.onAppointmentsChanged(apts);
                          },
                        ),
                      );
                    }),
                    _iconBtn(Icons.delete_outline, () async {
                      if (apt.googleEventId != null && apt.googleEventId!.isNotEmpty) {
                        await GoogleCalendarService.deleteEvent(apt.googleEventId!);
                      }
                      final apts = List<Appointment>.from(widget.appointments)..removeAt(index);
                      widget.onAppointmentsChanged(apts);
                    }),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
            color: AppColors.tint(context),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.accent(context), size: 18),
      ),
    );
  }

  static const _monthAbbrKeys = [
    'month_abbr_jan', 'month_abbr_feb', 'month_abbr_mar', 'month_abbr_apr',
    'month_abbr_may', 'month_abbr_jun', 'month_abbr_jul', 'month_abbr_aug',
    'month_abbr_sep', 'month_abbr_oct', 'month_abbr_nov', 'month_abbr_dec',
  ];

  String _formatPastDate(Appointment apt) {
    final t = AppLocalizations.of(context);
    final d = apt.fullDate;
    if (d == null) return t.t('home_day_prefix', {'date': apt.date.toString()});
    return '${t.t(_monthAbbrKeys[d.month - 1])} ${d.day}, ${d.year}';
  }

  Widget _buildPreviousAptCard(int index, Appointment apt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Icon(Icons.history,
                color: AppColors.textSecondary(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apt.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary(context))),
                const SizedBox(height: 2),
                Text(
                  '${_formatPastDate(apt)}${apt.time.isNotEmpty ? ' • ${apt.time}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context)),
                ),
                if (apt.location.isNotEmpty)
                  Text(apt.location,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted(context)),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              final apts =
                  List<Appointment>.from(widget.appointments)..removeAt(index);
              widget.onAppointmentsChanged(apts);
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline,
                  size: 16, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}

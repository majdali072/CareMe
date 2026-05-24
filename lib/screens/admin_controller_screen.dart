import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/country_phone_field.dart';
import '../widgets/location_picker.dart';
import '../theme/app_theme.dart';

// ─── Admin Controller Screen ──────────────────────────────────────────────

class AdminControllerScreen extends StatefulWidget {
  const AdminControllerScreen({super.key});

  @override
  State<AdminControllerScreen> createState() => _AdminControllerScreenState();
}

class _AdminControllerScreenState extends State<AdminControllerScreen> {
  bool _fabExpanded = false;
  bool _loading = true;
  String? _loadError;

  List<ContactEntry> _doctors = [];
  List<ContactEntry> _pharmacies = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getDoctors(),
        ApiService.getPharmacies(),
      ]);
      if (!mounted) return;
      setState(() {
        _doctors = results[0];
        _pharmacies = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _deleteEntry(ContactEntry entry, bool isDoctor) async {
    if (entry.id == null) return;
    try {
      if (isDoctor) {
        await ApiService.deleteDoctor(entry.id!);
        setState(() => _doctors.removeWhere((d) => d.id == entry.id));
      } else {
        await ApiService.deletePharmacy(entry.id!);
        setState(() => _pharmacies.removeWhere((p) => p.id == entry.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)
              .t('admin_delete_failed', {'error': e.toString()}))),
        );
      }
    }
  }

  // ── Add Dialog ───────────────────────────────────────────────────────────
  void _showAddDialog({required bool isDoctor}) {
    final nameCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();
    final phoneCtrl = PhoneInputController();
    final formKey = GlobalKey<FormState>();
    SelectedLocation? pickedLocation;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isDoctor
                            ? AppLocalizations.of(context).t('admin_add_doctor')
                            : AppLocalizations.of(context).t('admin_add_pharmacy'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormField(
                          label: AppLocalizations.of(context).t('admin_name_label'),
                          hint: isDoctor
                              ? AppLocalizations.of(context).t('admin_name_doctor_hint')
                              : AppLocalizations.of(context).t('admin_name_pharmacy_hint'),
                          controller: nameCtrl,
                          icon: isDoctor
                              ? Icons.person_outline_rounded
                              : Icons.local_pharmacy_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? AppLocalizations.of(context).t('admin_name_required')
                              : null,
                        ),
                        if (isDoctor) ...[
                          const SizedBox(height: 16),
                          _FormField(
                            label: AppLocalizations.of(context).t('admin_specialty_label'),
                            hint: AppLocalizations.of(context).t('admin_specialty_hint'),
                            controller: specialtyCtrl,
                            icon: Icons.medical_services_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? AppLocalizations.of(context).t('admin_specialty_required')
                                : null,
                          ),
                        ],
                        const SizedBox(height: 16),
                        StatefulBuilder(
                          builder: (ctx, setLocalState) => LocationAddressField(
                            label: AppLocalizations.of(context).t('admin_address_label'),
                            value: pickedLocation,
                            onChanged: (loc) =>
                                setLocalState(() => pickedLocation = loc),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CountryPhoneField(
                          controller: phoneCtrl,
                          label: AppLocalizations.of(context).t('edit_profile_phone_label'),
                          hint: AppLocalizations.of(context).t('admin_phone_hint'),
                        ),
                        const SizedBox(height: 28),

                        // Submit
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1D4ED8), Color(0xFF6366F1)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF2563EB).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                if (pickedLocation == null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text(AppLocalizations.of(context)
                                            .t('admin_pick_address_first'))),
                                  );
                                  return;
                                }
                                final draft = ContactEntry(
                                  name: nameCtrl.text.trim(),
                                  address: pickedLocation!.address,
                                  phone: phoneCtrl.fullPhone,
                                  latitude: pickedLocation!.latitude,
                                  longitude: pickedLocation!.longitude,
                                  specialty: isDoctor ? specialtyCtrl.text.trim() : '',
                                );
                                try {
                                  final saved = isDoctor
                                      ? await ApiService.addDoctor(draft)
                                      : await ApiService.addPharmacy(draft);
                                  if (!mounted) return;
                                  setState(() {
                                    if (isDoctor) {
                                      _doctors.add(saved);
                                    } else {
                                      _pharmacies.add(saved);
                                    }
                                  });
                                  Navigator.pop(ctx);
                                  _showSuccessSnackBar(isDoctor);
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppLocalizations.of(context)
                                        .t('admin_failed_prefix', {'error': e.toString()}))),
                                  );
                                }
                              },
                              child: Text(
                                isDoctor
                                    ? AppLocalizations.of(context).t('admin_add_doctor')
                                    : AppLocalizations.of(context).t('admin_add_pharmacy'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
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
      },
    );
  }

  void _showSuccessSnackBar(bool isDoctor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isDoctor
              ? AppLocalizations.of(context).t('admin_doctor_added_snack')
              : AppLocalizations.of(context).t('admin_pharmacy_added_snack'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Rendered inside parent Scaffold/Stack (see main.dart). We use a plain
    // Stack so the FAB can float above the parent's AdminBottomNav (~68px).
    return Container(
      color: AppColors.background(context),
      child: Stack(
        children: [
          Column(
            children: [
              // Blue Header
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context).t('admin_controller_title_full'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildControllerBody()),
            ],
          ),

          // FAB (expandable). Sits above the parent AdminBottomNav (~68px).
          Positioned(
            right: 16,
            bottom: 84,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_fabExpanded) ...[
                  FloatingActionButton.extended(
                    heroTag: 'addDoctor',
                    onPressed: () {
                      setState(() => _fabExpanded = false);
                      _showAddDialog(isDoctor: true);
                    },
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text(AppLocalizations.of(context).t('admin_add_doctor')),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    heroTag: 'addPharmacy',
                    onPressed: () {
                      setState(() => _fabExpanded = false);
                      _showAddDialog(isDoctor: false);
                    },
                    icon: const Icon(Icons.local_pharmacy_rounded),
                    label: Text(AppLocalizations.of(context).t('admin_add_pharmacy')),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 10),
                ],
                FloatingActionButton(
                  heroTag: 'mainFab',
                  onPressed: () =>
                      setState(() => _fabExpanded = !_fabExpanded),
                  backgroundColor: const Color(0xFF2563EB),
                  child: Icon(
                    _fabExpanded ? Icons.close_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControllerBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context)
                      .t('admin_failed_prefix', {'error': _loadError ?? ''}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadAll,
                child: Text(AppLocalizations.of(context).t('common_retry_btn')),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 180),
        children: [
          _SectionLabel(label: AppLocalizations.of(context).t('admin_section_doctors')),
          const SizedBox(height: 10),
          if (_doctors.isEmpty)
            _EmptyHint(text: AppLocalizations.of(context).t('admin_no_doctors_yet')),
          ..._doctors.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContactCard(
                entry: d,
                isDoctor: true,
                onDelete: () => _deleteEntry(d, true),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: AppLocalizations.of(context).t('admin_section_pharmacies')),
          const SizedBox(height: 10),
          if (_pharmacies.isEmpty)
            _EmptyHint(text: AppLocalizations.of(context).t('admin_no_pharmacies_yet')),
          ..._pharmacies.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContactCard(
                entry: p,
                isDoctor: false,
                onDelete: () => _deleteEntry(p, false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: AppColors.textMuted(context)),
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary(context),
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final ContactEntry entry;
  final bool isDoctor;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.entry,
    required this.isDoctor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDoctor
                  ? Icons.person_outline_rounded
                  : Icons.local_pharmacy_outlined,
              color: const Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onDelete,
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
                if (entry.specialty.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.specialty,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.address,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary(context)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      entry.phone,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppColors.textMuted(context), fontSize: 14),
            prefixIcon:
                Icon(icon, size: 18, color: AppColors.textMuted(context)),
            filled: true,
            fillColor: AppColors.surfaceAlt(context),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Shared country list used by phone inputs across the app.
const List<Map<String, String>> kCountries = [
  {'name': 'United States', 'code': '+1', 'flag': '\u{1F1FA}\u{1F1F8}'},
  {'name': 'United Kingdom', 'code': '+44', 'flag': '\u{1F1EC}\u{1F1E7}'},
  {'name': 'Canada', 'code': '+1', 'flag': '\u{1F1E8}\u{1F1E6}'},
  {'name': 'Australia', 'code': '+61', 'flag': '\u{1F1E6}\u{1F1FA}'},
  {'name': 'Germany', 'code': '+49', 'flag': '\u{1F1E9}\u{1F1EA}'},
  {'name': 'France', 'code': '+33', 'flag': '\u{1F1EB}\u{1F1F7}'},
  {'name': 'Italy', 'code': '+39', 'flag': '\u{1F1EE}\u{1F1F9}'},
  {'name': 'Spain', 'code': '+34', 'flag': '\u{1F1EA}\u{1F1F8}'},
  {'name': 'Netherlands', 'code': '+31', 'flag': '\u{1F1F3}\u{1F1F1}'},
  {'name': 'Belgium', 'code': '+32', 'flag': '\u{1F1E7}\u{1F1EA}'},
  {'name': 'Switzerland', 'code': '+41', 'flag': '\u{1F1E8}\u{1F1ED}'},
  {'name': 'Sweden', 'code': '+46', 'flag': '\u{1F1F8}\u{1F1EA}'},
  {'name': 'Norway', 'code': '+47', 'flag': '\u{1F1F3}\u{1F1F4}'},
  {'name': 'Denmark', 'code': '+45', 'flag': '\u{1F1E9}\u{1F1F0}'},
  {'name': 'Finland', 'code': '+358', 'flag': '\u{1F1EB}\u{1F1EE}'},
  {'name': 'Ireland', 'code': '+353', 'flag': '\u{1F1EE}\u{1F1EA}'},
  {'name': 'Portugal', 'code': '+351', 'flag': '\u{1F1F5}\u{1F1F9}'},
  {'name': 'Austria', 'code': '+43', 'flag': '\u{1F1E6}\u{1F1F9}'},
  {'name': 'Poland', 'code': '+48', 'flag': '\u{1F1F5}\u{1F1F1}'},
  {'name': 'Greece', 'code': '+30', 'flag': '\u{1F1EC}\u{1F1F7}'},
  {'name': 'Turkey', 'code': '+90', 'flag': '\u{1F1F9}\u{1F1F7}'},
  {'name': 'Russia', 'code': '+7', 'flag': '\u{1F1F7}\u{1F1FA}'},
  {'name': 'India', 'code': '+91', 'flag': '\u{1F1EE}\u{1F1F3}'},
  {'name': 'China', 'code': '+86', 'flag': '\u{1F1E8}\u{1F1F3}'},
  {'name': 'Japan', 'code': '+81', 'flag': '\u{1F1EF}\u{1F1F5}'},
  {'name': 'South Korea', 'code': '+82', 'flag': '\u{1F1F0}\u{1F1F7}'},
  {'name': 'Indonesia', 'code': '+62', 'flag': '\u{1F1EE}\u{1F1E9}'},
  {'name': 'Malaysia', 'code': '+60', 'flag': '\u{1F1F2}\u{1F1FE}'},
  {'name': 'Philippines', 'code': '+63', 'flag': '\u{1F1F5}\u{1F1ED}'},
  {'name': 'Thailand', 'code': '+66', 'flag': '\u{1F1F9}\u{1F1ED}'},
  {'name': 'Vietnam', 'code': '+84', 'flag': '\u{1F1FB}\u{1F1F3}'},
  {'name': 'Singapore', 'code': '+65', 'flag': '\u{1F1F8}\u{1F1EC}'},
  {'name': 'Pakistan', 'code': '+92', 'flag': '\u{1F1F5}\u{1F1F0}'},
  {'name': 'Bangladesh', 'code': '+880', 'flag': '\u{1F1E7}\u{1F1E9}'},
  {'name': 'Saudi Arabia', 'code': '+966', 'flag': '\u{1F1F8}\u{1F1E6}'},
  {'name': 'UAE', 'code': '+971', 'flag': '\u{1F1E6}\u{1F1EA}'},
  {'name': 'Qatar', 'code': '+974', 'flag': '\u{1F1F6}\u{1F1E6}'},
  {'name': 'Kuwait', 'code': '+965', 'flag': '\u{1F1F0}\u{1F1FC}'},
  {'name': 'Bahrain', 'code': '+973', 'flag': '\u{1F1E7}\u{1F1ED}'},
  {'name': 'Oman', 'code': '+968', 'flag': '\u{1F1F4}\u{1F1F2}'},
  {'name': 'Jordan', 'code': '+962', 'flag': '\u{1F1EF}\u{1F1F4}'},
  {'name': 'Lebanon', 'code': '+961', 'flag': '\u{1F1F1}\u{1F1E7}'},
  {'name': 'Iraq', 'code': '+964', 'flag': '\u{1F1EE}\u{1F1F6}'},
  {'name': 'Egypt', 'code': '+20', 'flag': '\u{1F1EA}\u{1F1EC}'},
  {'name': 'Morocco', 'code': '+212', 'flag': '\u{1F1F2}\u{1F1E6}'},
  {'name': 'Tunisia', 'code': '+216', 'flag': '\u{1F1F9}\u{1F1F3}'},
  {'name': 'Algeria', 'code': '+213', 'flag': '\u{1F1E9}\u{1F1FF}'},
  {'name': 'Libya', 'code': '+218', 'flag': '\u{1F1F1}\u{1F1FE}'},
  {'name': 'Nigeria', 'code': '+234', 'flag': '\u{1F1F3}\u{1F1EC}'},
  {'name': 'South Africa', 'code': '+27', 'flag': '\u{1F1FF}\u{1F1E6}'},
  {'name': 'Kenya', 'code': '+254', 'flag': '\u{1F1F0}\u{1F1EA}'},
  {'name': 'Ghana', 'code': '+233', 'flag': '\u{1F1EC}\u{1F1ED}'},
  {'name': 'Brazil', 'code': '+55', 'flag': '\u{1F1E7}\u{1F1F7}'},
  {'name': 'Mexico', 'code': '+52', 'flag': '\u{1F1F2}\u{1F1FD}'},
  {'name': 'Argentina', 'code': '+54', 'flag': '\u{1F1E6}\u{1F1F7}'},
  {'name': 'Colombia', 'code': '+57', 'flag': '\u{1F1E8}\u{1F1F4}'},
  {'name': 'Chile', 'code': '+56', 'flag': '\u{1F1E8}\u{1F1F1}'},
  {'name': 'Peru', 'code': '+51', 'flag': '\u{1F1F5}\u{1F1EA}'},
  {'name': 'New Zealand', 'code': '+64', 'flag': '\u{1F1F3}\u{1F1FF}'},
  {'name': 'Israel', 'code': '+972', 'flag': '\u{1F1EE}\u{1F1F1}'},
  {'name': 'Palestine', 'code': '+970', 'flag': '\u{1F1F5}\u{1F1F8}'},
  {'name': 'Syria', 'code': '+963', 'flag': '\u{1F1F8}\u{1F1FE}'},
  {'name': 'Yemen', 'code': '+967', 'flag': '\u{1F1FE}\u{1F1EA}'},
  {'name': 'Sudan', 'code': '+249', 'flag': '\u{1F1F8}\u{1F1E9}'},
  {'name': 'Somalia', 'code': '+252', 'flag': '\u{1F1F8}\u{1F1F4}'},
  {'name': 'Ethiopia', 'code': '+251', 'flag': '\u{1F1EA}\u{1F1F9}'},
  {'name': 'Tanzania', 'code': '+255', 'flag': '\u{1F1F9}\u{1F1FF}'},
  {'name': 'Uganda', 'code': '+256', 'flag': '\u{1F1FA}\u{1F1EC}'},
  {'name': 'Mauritania', 'code': '+222', 'flag': '\u{1F1F2}\u{1F1F7}'},
];

/// A controller that exposes the selected country code/flag and the local
/// phone number, plus a combined [fullPhone] getter.
class PhoneInputController extends ChangeNotifier {
  String _code;
  String _flag;
  final TextEditingController numberController;

  PhoneInputController({
    String code = '+1',
    String flag = '\u{1F1FA}\u{1F1F8}',
    String initialNumber = '',
  })  : _code = code,
        _flag = flag,
        numberController = TextEditingController(text: initialNumber);

  String get code => _code;
  String get flag => _flag;
  String get number => numberController.text.trim();

  /// Combined phone (e.g. "+1 5552345678"). Empty if the number is empty.
  String get fullPhone => number.isEmpty ? '' : '$_code $number';

  void setCountry({required String code, required String flag}) {
    _code = code;
    _flag = flag;
    notifyListeners();
  }

  @override
  void dispose() {
    numberController.dispose();
    super.dispose();
  }
}

/// Country-code + phone number input, matching the styling used in
/// `account_screen`'s edit-profile form.
class CountryPhoneField extends StatefulWidget {
  final PhoneInputController controller;
  final String? label;
  final String? hint;

  const CountryPhoneField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
  });

  @override
  State<CountryPhoneField> createState() => _CountryPhoneFieldState();
}

class _CountryPhoneFieldState extends State<CountryPhoneField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _showPicker() {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(kCountries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollCtrl) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context).t('country_picker_title'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchCtrl,
                            onChanged: (val) {
                              setSheetState(() {
                                final q = val.toLowerCase();
                                filtered = kCountries
                                    .where((c) =>
                                        c['name']!.toLowerCase().contains(q) ||
                                        c['code']!.contains(val))
                                    .toList();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).t('country_picker_search'),
                              prefixIcon: const Icon(Icons.search,
                                  size: 20, color: Color(0xFF9CA3AF)),
                              filled: true,
                              fillColor: AppColors.surfaceAlt(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final country = filtered[i];
                          final isSelected =
                              country['code'] == widget.controller.code &&
                                  country['flag'] == widget.controller.flag;
                          return ListTile(
                            leading: Text(country['flag']!,
                                style: const TextStyle(fontSize: 24)),
                            title: Text(country['name']!,
                                style: const TextStyle(fontSize: 15)),
                            trailing: Text(
                              country['code']!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFEFF6FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onTap: () {
                              widget.controller.setCountry(
                                code: country['code']!,
                                flag: country['flag']!,
                              );
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            GestureDetector(
              onTap: _showPicker,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.controller.flag,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(widget.controller.code,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context))),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down,
                        size: 18, color: Color(0xFF6B7280)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: widget.controller.numberController,
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? AppLocalizations.of(context).t('phone_required')
                        : null,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: widget.hint ??
                      AppLocalizations.of(context).t('edit_profile_phone_hint'),
                  hintStyle: const TextStyle(
                      color: Color(0xFFCBD5E1), fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surfaceAlt(context),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
            ),
          ],
        ),
      ],
    );
  }
}

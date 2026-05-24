import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/location_picker.dart';
import 'otp_verification_screen.dart';
import 'change_password_screen.dart';
import '../theme/app_theme.dart';

/// Support contact phone number, displayed in About / Help & Support and
/// opened directly in WhatsApp when the user taps the row.
const String _kSupportWhatsappNumber = '+96178889290';
const String _kSupportWhatsappUrl = 'https://wa.me/96178889290';

class AccountScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onBack;
  final List<Appointment> appointments;
  final Uint8List? profilePhoto;
  final void Function(Uint8List?) onProfilePhotoChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const AccountScreen({
    super.key,
    required this.userName,
    required this.onLogout,
    required this.onBack,
    required this.appointments,
    this.profilePhoto,
    required this.onProfilePhotoChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

const List<Map<String, String>> _countries = [
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

class _AccountScreenState extends State<AccountScreen> {
  bool _showEditProfile = false;
  bool _showSecurity = false;
  bool _isLoading = true;
  bool _isSaving = false;

  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _countryCode = '+1';
  String _countryFlag = '\u{1F1FA}\u{1F1F8}';
  String _dateOfBirth = '';
  String _address = '';
  double? _latitude;
  double? _longitude;
  Uint8List? _profilePhoto;

  TextEditingController? _editNameCtrl;
  TextEditingController? _editPhoneCtrl;
  TextEditingController? _editDobCtrl;
  SelectedLocation? _editLocation;

  @override
  void initState() {
    super.initState();
    _fullName = widget.userName;
    _profilePhoto = widget.profilePhoto;
    _loadProfile();
  }

  @override
  void dispose() {
    _disposeEditControllers();
    super.dispose();
  }

  void _openEditProfile() {
    _editNameCtrl?.dispose();
    _editPhoneCtrl?.dispose();
    _editDobCtrl?.dispose();
    _editNameCtrl = TextEditingController(text: _fullName);
    _editPhoneCtrl = TextEditingController(text: _localNumber());
    _editDobCtrl = TextEditingController(text: _dateOfBirth);
    _editLocation = _address.isEmpty
        ? null
        : SelectedLocation.fromParts(
            address: _address,
            latitude: _latitude,
            longitude: _longitude,
          );
    setState(() => _showEditProfile = true);
  }

  void _disposeEditControllers() {
    _editNameCtrl?.dispose();
    _editPhoneCtrl?.dispose();
    _editDobCtrl?.dispose();
    _editNameCtrl = null;
    _editPhoneCtrl = null;
    _editDobCtrl = null;
    _editLocation = null;
  }

  void _closeEditProfile() {
    _disposeEditControllers();
    setState(() => _showEditProfile = false);
  }

  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 80);
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    setState(() => _profilePhoto = bytes);
    widget.onProfilePhotoChanged(bytes);

    // Upload to backend
    await ApiService.uploadProfilePhoto(bytes);
  }

  Future<void> _removeProfileImage() async {
    setState(() => _profilePhoto = null);
    widget.onProfilePhotoChanged(null);
    await ApiService.deleteProfilePhoto();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getProfile();
      final savedPhone = data['phone'] ?? '';
      _parsePhone(savedPhone);
      setState(() {
        _fullName = data['name'] ?? widget.userName;
        _email = data['email'] ?? '';
        _phone = savedPhone;
        _dateOfBirth = data['dateOfBirth'] ?? '';
        _address = data['address'] ?? '';
        _latitude = (data['latitude'] as num?)?.toDouble();
        _longitude = (data['longitude'] as num?)?.toDouble();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _email = '${widget.userName.toLowerCase()}@email.com';
        _isLoading = false;
      });
    }
  }

  void _parsePhone(String fullPhone) {
    if (fullPhone.isEmpty) return;
    // Try to match a country code from the saved phone
    for (final c in _countries) {
      final code = c['code']!;
      if (fullPhone.startsWith(code)) {
        _countryCode = code;
        _countryFlag = c['flag']!;
        return;
      }
    }
  }

  String _localNumber() {
    if (_phone.startsWith(_countryCode)) {
      return _phone.substring(_countryCode.length).trim();
    }
    return _phone;
  }

  void _showCountryPicker(void Function(Map<String, String>) onSelect) {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> filtered = List.from(_countries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                            bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 12),
                          Text(AppLocalizations.of(context).t('country_picker_title'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchCtrl,
                            onChanged: (val) {
                              setSheetState(() {
                                filtered = _countries
                                    .where((c) =>
                                        c['name']!
                                            .toLowerCase()
                                            .contains(val.toLowerCase()) ||
                                        c['code']!.contains(val))
                                    .toList();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).t('country_picker_search'),
                              prefixIcon: const Icon(Icons.search,
                                  size: 20, color: Color(0xFF9CA3AF)),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB))),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
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
                          final isSelected = country['code'] == _countryCode &&
                              country['flag'] == _countryFlag;
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
                                borderRadius: BorderRadius.circular(8)),
                            onTap: () {
                              onSelect(country);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_showEditProfile) return _buildEditProfile();
    if (_showSecurity) return _buildSecurity();
    return _buildMain();
  }

  Widget _buildMain() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: widget.onBack,
                          ),
                        ),
                        Center(
                          child: Text(AppLocalizations.of(context).t('account_title'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _pickProfileImage,
                      onLongPress: _profilePhoto != null ? _removeProfileImage : null,
                      child: Stack(
                        children: [
                          _buildAvatar(80),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(15),
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_fullName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                    Text(_email,
                        style: const TextStyle(
                            color: Color(0xFFBFDBFE), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                _buildSection(AppLocalizations.of(context).t('account_section_personal'), [
                  _buildInfoRow(Icons.mail_outline,
                      AppLocalizations.of(context).t('account_info_email'), _email),
                  _buildInfoRow(Icons.phone_outlined,
                      AppLocalizations.of(context).t('account_info_phone'),
                      _phone.isEmpty ? AppLocalizations.of(context).t('common_not_set') : _phone),
                  _buildInfoRow(Icons.cake_outlined,
                      AppLocalizations.of(context).t('account_info_dob'),
                      _dateOfBirth.isEmpty ? AppLocalizations.of(context).t('common_not_set') : _dateOfBirth),
                  _buildInfoRow(Icons.location_on_outlined,
                      AppLocalizations.of(context).t('account_info_address'),
                      _address.isEmpty ? AppLocalizations.of(context).t('common_not_set') : _address),
                ]),
                const SizedBox(height: 14),
                _buildSection(AppLocalizations.of(context).t('account_section_settings'), [
                  _buildNavRow(
                      Icons.person_outline,
                      const Color(0xFF2563EB),
                      AppLocalizations.of(context).t('account_edit_profile'),
                      AppLocalizations.of(context).t('account_edit_profile_sub'),
                      _openEditProfile),
                  _buildNavRow(
                      Icons.lock_outline,
                      const Color(0xFFDC2626),
                      AppLocalizations.of(context).t('account_security'),
                      AppLocalizations.of(context).t('account_security_sub'),
                      () => setState(() => _showSecurity = true)),
                  _buildThemeToggleRow(),
                ]),
                const SizedBox(height: 14),
                _buildSection(AppLocalizations.of(context).t('account_section_support'), [
                  _buildNavRow(
                      Icons.help_outline,
                      const Color(0xFF16A34A),
                      AppLocalizations.of(context).t('account_help_support'),
                      AppLocalizations.of(context).t('account_help_support_sub'),
                      _showHelpSupport),
                  _buildNavRow(
                      Icons.description_outlined,
                      const Color(0xFF7C3AED),
                      AppLocalizations.of(context).t('account_terms_privacy'),
                      AppLocalizations.of(context).t('account_terms_privacy_sub'),
                      _showTermsPrivacy),
                  _buildNavRow(Icons.info_outline, const Color(0xFF0891B2),
                      AppLocalizations.of(context).t('account_about'),
                      AppLocalizations.of(context).t('account_about_sub'), _showAbout),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(AppLocalizations.of(context).t('account_sign_out')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      foregroundColor: const Color(0xFFDC2626),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditProfile() {
    final nameCtrl = _editNameCtrl ??=
        TextEditingController(text: _fullName);
    final phoneCtrl = _editPhoneCtrl ??=
        TextEditingController(text: _localNumber());
    final dobCtrl = _editDobCtrl ??=
        TextEditingController(text: _dateOfBirth);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                      left: 16,
                      top: 14,
                      child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _closeEditProfile)),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(AppLocalizations.of(context).t('edit_profile_title'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8)
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          children: [
                            _buildAvatar(80),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1976D2),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: AppColors.surface(context), width: 2)),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Text(AppLocalizations.of(context).t('edit_profile_change_picture'),
                            style: const TextStyle(
                                color: Color(0xFF2563EB), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSection(AppLocalizations.of(context).t('edit_profile_section_general'), [
                  _buildEditField(AppLocalizations.of(context).t('edit_profile_name_label'), nameCtrl),
                  _buildInfoRow(Icons.mail_outline,
                      AppLocalizations.of(context).t('account_info_email'), _email),
                  _buildPhoneField(phoneCtrl),
                  _buildDatePickerField(AppLocalizations.of(context).t('edit_profile_dob_label'), dobCtrl),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: LocationAddressField(
                      label: AppLocalizations.of(context).t('edit_profile_address_label'),
                      value: _editLocation,
                      autoDetect: true,
                      onChanged: (loc) =>
                          setState(() => _editLocation = loc),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            try {
                              final fullPhone = phoneCtrl.text.trim().isEmpty
                                  ? ''
                                  : '$_countryCode ${phoneCtrl.text.trim()}';
                              await ApiService.updateProfile(
                                name: nameCtrl.text,
                                phone: fullPhone,
                                dateOfBirth: dobCtrl.text,
                                address: _editLocation?.address ?? '',
                                latitude: _editLocation?.latitude,
                                longitude: _editLocation?.longitude,
                              );
                              final savedAddress = _editLocation?.address ?? '';
                              final savedLat = _editLocation?.latitude;
                              final savedLng = _editLocation?.longitude;
                              final savedName = nameCtrl.text;
                              final savedDob = dobCtrl.text;
                              _disposeEditControllers();
                              setState(() {
                                _fullName = savedName;
                                _phone = fullPhone;
                                _dateOfBirth = savedDob;
                                _address = savedAddress;
                                _latitude = savedLat;
                                _longitude = savedLng;
                                _showEditProfile = false;
                                _isSaving = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(AppLocalizations.of(context)
                                          .t('edit_profile_saved'))),
                                );
                              }
                            } catch (e) {
                              setState(() => _isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppLocalizations.of(context)
                                      .t('edit_profile_save_failed', {'error': e.toString()}))),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(AppLocalizations.of(context).t('edit_profile_save'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportMyData() async {
    final saved = await _exportPdf(loadingDialog: true);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('common_saved')),
          backgroundColor: const Color(0xFF1E3A5F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Generates the PDF on the backend, lets the user pick a save location,
  /// and returns true if the file was actually written.
  /// Returns false on user-cancel.
  /// Throws on backend / file errors so the caller can decide what to do.
  Future<bool> _exportPdf({bool loadingDialog = false}) async {
    if (loadingDialog) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E3A5F))),
      );
    }

    try {
      final appointmentMaps = widget.appointments
          .map((a) => {
                'date': a.date,
                'fullDate': a.fullDate?.toIso8601String(),
                'title': a.title,
                'time': a.time,
                'type': a.type,
                'location': a.location,
              })
          .toList();

      final bytes = await ApiService.exportData(appointmentMaps);

      if (loadingDialog && mounted) {
        Navigator.of(context).pop(); // dismiss loading
      }
      if (!mounted) return false;

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: AppLocalizations.of(context).t('security_download_title'),
        fileName: AppLocalizations.of(context).t('security_download_filename'),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (savePath == null) return false;

      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(savePath).writeAsBytes(bytes);
      }
      return true;
    } catch (e) {
      if (loadingDialog && mounted) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)
                .t('security_download_failed', {'error': e.toString()})),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      rethrow;
    }
  }

  void _showTermsPrivacy() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context).t('terms_privacy_title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _termsBlock(AppLocalizations.of(context).t('terms_section'),
                        AppLocalizations.of(context).t('terms_text_full')),
                    const SizedBox(height: 16),
                    _termsBlock(AppLocalizations.of(context).t('privacy_section'),
                        AppLocalizations.of(context).t('privacy_text_full')),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(AppLocalizations.of(context).t('common_close')),
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

  Widget _termsBlock(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context))),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(content,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary(context))),
          ),
        ],
      ),
    );
  }

  /// Open WhatsApp directly to the support number. Falls back to a snackbar
  /// when the device has no app that can handle the URL.
  Future<void> _openSupportWhatsapp() async {
    final uri = Uri.parse(_kSupportWhatsappUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_kSupportWhatsappNumber)),
      );
    }
  }

  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context).t('account_help_support'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).t('help_faq_title'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary(context))),
                    const SizedBox(height: 12),
                    _faqItem(AppLocalizations.of(context).t('help_q1'),
                        AppLocalizations.of(context).t('help_a1')),
                    _faqItem(AppLocalizations.of(context).t('help_q2'),
                        AppLocalizations.of(context).t('help_a2')),
                    _faqItem(AppLocalizations.of(context).t('help_q3'),
                        AppLocalizations.of(context).t('help_a3')),
                    _faqItem(AppLocalizations.of(context).t('help_q4'),
                        AppLocalizations.of(context).t('help_a4')),
                    _faqItem(AppLocalizations.of(context).t('help_q5'),
                        AppLocalizations.of(context).t('help_a5')),
                    _faqItem(AppLocalizations.of(context).t('help_q6'),
                        AppLocalizations.of(context).t('help_a6')),
                    Divider(height: 32, color: AppColors.border(context)),
                    Text(AppLocalizations.of(context).t('help_contact_title'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary(context))),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.chat,
                          color: Color(0xFF25D366)),
                      title: Text(AppLocalizations.of(context).t('help_contact_whatsapp_label'),
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: AppColors.textPrimary(context))),
                      subtitle: Text(_kSupportWhatsappNumber,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(context))),
                      trailing: Icon(Icons.open_in_new,
                          size: 16, color: AppColors.textMuted(context)),
                      onTap: _openSupportWhatsapp,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    Divider(height: 32, color: AppColors.border(context)),
                    Text(
                      AppLocalizations.of(context).t('help_response_time'),
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted(context)),
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

  Widget _faqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary(context))),
          const SizedBox(height: 4),
          Text(answer,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textSecondary(context))),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context).t('about_title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white)),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/CareMe_Logo.png',
                        width: 80, height: 80),
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context).t('app_name'),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context))),
                  const SizedBox(height: 4),
                  Text(AppLocalizations.of(context).t('about_version'),
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted(context))),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).t('about_description'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).t('about_features_title'),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary(context))),
                        const SizedBox(height: 10),
                        _FeatureRow(
                            icon: Icons.medication_outlined,
                            color: const Color(0xFF2563EB),
                            text: AppLocalizations.of(context).t('about_feature_med')),
                        const SizedBox(height: 8),
                        _FeatureRow(
                            icon: Icons.science_outlined,
                            color: const Color(0xFF7C3AED),
                            text: AppLocalizations.of(context).t('about_feature_lab')),
                        const SizedBox(height: 8),
                        _FeatureRow(
                            icon: Icons.calendar_month_outlined,
                            color: const Color(0xFF16A34A),
                            text: AppLocalizations.of(context).t('about_feature_appt')),
                        const SizedBox(height: 8),
                        _FeatureRow(
                            icon: Icons.smart_toy_outlined,
                            color: const Color(0xFFF97316),
                            text: AppLocalizations.of(context).t('about_feature_ai')),
                        const SizedBox(height: 8),
                        _FeatureRow(
                            icon: Icons.picture_as_pdf_outlined,
                            color: const Color(0xFFDC2626),
                            text: AppLocalizations.of(context).t('about_feature_pdf')),
                        const SizedBox(height: 8),
                        _FeatureRow(
                            icon: Icons.lock_outline,
                            color: const Color(0xFF0891B2),
                            text: AppLocalizations.of(context).t('about_feature_secure')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).t('about_tagline'),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted(context),
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _openSupportWhatsapp,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat,
                            size: 14, color: Color(0xFF25D366)),
                        const SizedBox(width: 4),
                        Text(
                          _kSupportWhatsappNumber,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF25D366)),
                        ),
                      ],
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

  void _showAccountClosureOptions() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.manage_accounts_outlined,
                      color: AppColors.textPrimary(context), size: 26),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context).t('account_closure_title'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).t('account_closure_subtitle'),
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 14),
              _buildClosureOption(
                ctx,
                icon: Icons.delete_forever_outlined,
                color: const Color(0xFFDC2626),
                title: AppLocalizations.of(context).t('account_delete_title'),
                subtitle: AppLocalizations.of(context).t('account_delete_subtitle'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteAccount();
                },
              ),
              _buildClosureOption(
                ctx,
                icon: Icons.download_done_outlined,
                color: const Color(0xFFB45309),
                title: AppLocalizations.of(context).t('account_delete_download_title'),
                subtitle: AppLocalizations.of(context).t('account_delete_download_subtitle'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteAndDownload();
                },
              ),
              _buildClosureOption(
                ctx,
                icon: Icons.shield_outlined,
                color: const Color(0xFF2563EB),
                title: AppLocalizations.of(context).t('security_deactivate'),
                subtitle: AppLocalizations.of(context).t('account_deactivate_subtitle'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeactivateAccount();
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context).t('common_cancel'),
                      style: TextStyle(color: AppColors.textSecondary(context))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClosureOption(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border(context)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary(context))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted(context))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textMuted(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_outlined,
                color: Color(0xFFDC2626), size: 28),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context).t('account_delete_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).t('account_delete_confirm_body'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).t('common_cancel'),
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performDeleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).t('common_delete')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAndDownload() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.download_done_outlined,
                color: Color(0xFFB45309), size: 28),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context).t('account_delete_download_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).t('account_delete_download_confirm_body'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).t('common_cancel'),
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              bool exported;
              try {
                exported = await _exportPdf(loadingDialog: true);
              } catch (_) {
                return; // export already showed an error snackbar
              }
              if (!exported) return; // user cancelled save dialog
              await _performDeleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).t('account_export_and_delete')),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivateAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 28),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context).t('security_deactivate_confirm_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).t('security_deactivate_confirm_body'),
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).t('common_cancel'),
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.deactivateAccount();
                if (mounted) {
                  widget.onLogout();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)
                        .t('security_deactivated_snack'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)
                        .t('security_deactivate_failed', {'error': e.toString()}))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).t('security_deactivate_button')),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFDC2626))),
    );
    try {
      await ApiService.deleteAccount();
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        widget.onLogout();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('account_deleted_snack'))),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)
              .t('account_delete_failed', {'error': e.toString()}))),
        );
      }
    }
  }

  Widget _buildSecurity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                      left: 16,
                      top: 14,
                      child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () =>
                              setState(() => _showSecurity = false))),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text(AppLocalizations.of(context).t('security_title'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                _buildSection(AppLocalizations.of(context).t('security_section_password'), [
                  _buildNavRow(Icons.lock_outline, const Color(0xFFDC2626),
                      AppLocalizations.of(context).t('security_change_password'),
                      AppLocalizations.of(context).t('security_change_password_sub'), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OTPVerificationScreen(
                          verificationType: 'email',
                          contactInfo: _email,
                          onVerify: (otp) {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ]),
                const SizedBox(height: 14),
                _buildSection(AppLocalizations.of(context).t('security_section_privacy'), [
                  _buildNavRow(
                      Icons.storage_outlined,
                      const Color(0xFF7C3AED),
                      AppLocalizations.of(context).t('security_download_data'),
                      AppLocalizations.of(context).t('security_download_data_sub'),
                      _exportMyData),
                  _buildNavRow(
                      Icons.shield_outlined,
                      const Color(0xFFDC2626),
                      AppLocalizations.of(context).t('account_closure_title'),
                      AppLocalizations.of(context).t('account_closure_nav_sub'),
                      _showAccountClosureOptions),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Shared widgets ----------

  Widget _buildAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _profilePhoto == null
            ? const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)])
            : null,
        borderRadius: BorderRadius.circular(size / 2),
        image: _profilePhoto != null
            ? DecorationImage(
                image: MemoryImage(_profilePhoto!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _profilePhoto == null
          ? Center(
              child: Text(
                _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                    fontSize: 15)),
          ),
          Divider(height: 1, color: AppColors.border(context)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(context)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
              Text(value,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggleRow() {
    final isDark = widget.themeMode == ThemeMode.dark;
    final iconBg = isDark ? const Color(0xFF6366F1) : const Color(0xFFF59E0B);
    final icon = isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined;
    final primaryTextColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context).t('account_dark_mode'),
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: primaryTextColor,
                        fontSize: 14)),
                Text(isDark
                        ? AppLocalizations.of(context).t('account_dark_on')
                        : AppLocalizations.of(context).t('account_dark_off'),
                    style: TextStyle(fontSize: 12, color: subTextColor)),
              ],
            ),
          ),
          Switch(
            value: isDark,
            onChanged: (v) =>
                widget.onThemeModeChanged(v ? ThemeMode.dark : ThemeMode.light),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(IconData icon, Color iconBg, String title,
      String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconBg, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted(context), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField(TextEditingController phoneCtrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).t('edit_profile_phone_label'),
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  _showCountryPicker((country) {
                    setState(() {
                      _countryCode = country['code']!;
                      _countryFlag = country['flag']!;
                    });
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt(context),
                    border: Border.all(color: AppColors.border(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_countryFlag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(_countryCode,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context))),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down,
                          size: 18, color: AppColors.textSecondary(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).t('edit_profile_phone_hint'),
                    hintStyle: TextStyle(color: AppColors.textMuted(context)),
                    filled: true,
                    fillColor: AppColors.surfaceAlt(context),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border(context))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border(context))),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceAlt(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(context))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(context))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            readOnly: true,
            style: TextStyle(color: AppColors.textPrimary(context)),
            onTap: () async {
              DateTime initial = DateTime(1990, 1, 15);
              if (ctrl.text.isNotEmpty) {
                try {
                  initial = DateFormat('yyyy-MM-dd').parse(ctrl.text);
                } catch (_) {}
              }
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
              }
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceAlt(context),
              hintText: AppLocalizations.of(context).t('edit_profile_dob_hint'),
              hintStyle: TextStyle(color: AppColors.textMuted(context)),
              suffixIcon: Icon(Icons.calendar_today,
                  size: 18, color: AppColors.textSecondary(context)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(context))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(context))),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _FeatureRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context)))),
      ],
    );
  }
}

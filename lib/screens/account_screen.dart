import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../widgets/location_picker.dart';
import 'otp_verification_screen.dart';
import 'change_password_screen.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _fullName = widget.userName;
    _profilePhoto = widget.profilePhoto;
    _loadProfile();
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
                          const Text('Select Country',
                              style: TextStyle(
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
                              hintText: 'Search country...',
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
                        const Center(
                          child: Text('Account',
                              style: TextStyle(
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
                _buildSection('Personal Information', [
                  _buildInfoRow(Icons.mail_outline, 'Email', _email),
                  _buildInfoRow(Icons.phone_outlined, 'Phone',
                      _phone.isEmpty ? 'Not set' : _phone),
                  _buildInfoRow(Icons.cake_outlined, 'Date of Birth',
                      _dateOfBirth.isEmpty ? 'Not set' : _dateOfBirth),
                  _buildInfoRow(Icons.location_on_outlined, 'Address',
                      _address.isEmpty ? 'Not set' : _address),
                ]),
                const SizedBox(height: 14),
                _buildSection('Settings', [
                  _buildNavRow(
                      Icons.person_outline,
                      const Color(0xFF2563EB),
                      'Edit Profile',
                      'Update your personal information',
                      () => setState(() => _showEditProfile = true)),
                  _buildNavRow(
                      Icons.lock_outline,
                      const Color(0xFFDC2626),
                      'Security & Privacy',
                      'Password, privacy controls',
                      () => setState(() => _showSecurity = true)),
                  _buildThemeToggleRow(),
                ]),
                const SizedBox(height: 14),
                _buildSection('Support', [
                  _buildNavRow(
                      Icons.help_outline,
                      const Color(0xFF16A34A),
                      'Help & Support',
                      'FAQs and contact support',
                      _showHelpSupport),
                  _buildNavRow(
                      Icons.description_outlined,
                      const Color(0xFF7C3AED),
                      'Terms & Privacy',
                      'View policies',
                      _showTermsPrivacy),
                  _buildNavRow(Icons.info_outline, const Color(0xFF0891B2),
                      'About CareMe', 'Version 1.0.0', _showAbout),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out'),
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
    final nameCtrl = TextEditingController(text: _fullName);
    final phoneCtrl = TextEditingController(text: _localNumber());
    final dobCtrl = TextEditingController(text: _dateOfBirth);
    SelectedLocation? draftLocation = _address.isEmpty
        ? null
        : SelectedLocation.fromParts(
            address: _address,
            latitude: _latitude,
            longitude: _longitude,
          );

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
                              setState(() => _showEditProfile = false))),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text('Edit Profile',
                              style: TextStyle(
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
                        child: const Text('Change profile picture',
                            style: TextStyle(
                                color: Color(0xFF2563EB), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSection('General Information', [
                  _buildEditField('Full Name', nameCtrl),
                  _buildInfoRow(Icons.mail_outline, 'Email', _email),
                  _buildPhoneField(phoneCtrl),
                  _buildDatePickerField('Date of Birth', dobCtrl),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: StatefulBuilder(
                      builder: (ctx, setLocalState) => LocationAddressField(
                        label: 'Address',
                        value: draftLocation,
                        autoDetect: true,
                        onChanged: (loc) =>
                            setLocalState(() => draftLocation = loc),
                      ),
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
                                address: draftLocation?.address ?? '',
                                latitude: draftLocation?.latitude,
                                longitude: draftLocation?.longitude,
                              );
                              setState(() {
                                _fullName = nameCtrl.text;
                                _phone = fullPhone;
                                _dateOfBirth = dobCtrl.text;
                                _address = draftLocation?.address ?? '';
                                _latitude = draftLocation?.latitude;
                                _longitude = draftLocation?.longitude;
                                _showEditProfile = false;
                                _isSaving = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Profile updated successfully')),
                                );
                              }
                            } catch (e) {
                              setState(() => _isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save: $e')),
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
                        : const Text('Save Changes',
                            style: TextStyle(
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

  Future<void> _downloadMyData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A5F))),
    );

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

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      // Let the user pick where to save — native system save dialog.
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save your health data',
        fileName: 'CareMe_MyData.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (savePath == null) {
        // User cancelled the save dialog
        return;
      }

      // On Android/iOS the file_picker plugin writes bytes itself when
      // `bytes:` is supplied. On desktop it only returns the path, so we
      // need to write ourselves.
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(savePath).writeAsBytes(bytes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $savePath'),
          backgroundColor: const Color(0xFF1E3A5F),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download data: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                  const Text('Terms & Privacy',
                      style: TextStyle(
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
                    _termsBlock('Terms of Service', _termsText),
                    const SizedBox(height: 16),
                    _termsBlock('Privacy Policy', _privacyText),
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
                        child: const Text('Close'),
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
                  const Text('Help & Support',
                      style: TextStyle(
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
                    Text('Frequently Asked Questions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary(context))),
                    const SizedBox(height: 12),
                    _faqItem('How do I add a medication?',
                        'Go to the Medications tab and tap the + button. Fill in the medication details and tap Save.'),
                    _faqItem('How do I upload lab results?',
                        'Go to the Lab Tests tab and tap the + button. You can upload a file or enter the details manually.'),
                    _faqItem('Is my health data secure?',
                        'Yes. Your data is encrypted in transit and at rest. We never sell or share your personal health information.'),
                    _faqItem('How do I change my password?',
                        'Go to Settings > Security & Privacy > Change Password. You will need to verify your identity via email OTP first.'),
                    _faqItem('How do I deactivate my account?',
                        'Go to Settings > Security & Privacy > Deactivate Account. Your data is preserved and you can contact support to reactivate anytime.'),
                    _faqItem('Can I export my data?',
                        'Yes. Go to Settings > Security & Privacy > Download My Data to export your health records as a PDF.'),
                    Divider(height: 32, color: AppColors.border(context)),
                    Text('Contact Support',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary(context))),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.email_outlined,
                          color: Color(0xFF2563EB)),
                      title: Text('Email',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: AppColors.textPrimary(context))),
                      subtitle: Text('support@careme.app',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(context))),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    Divider(height: 32, color: AppColors.border(context)),
                    Text(
                      'Our support team typically responds within 24 hours.',
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

  static const String _termsText = '''Last updated: April 2026

1. Acceptance of Terms
By creating an account or otherwise using CareMe ("the App"), you confirm that you have read, understood, and agreed to be bound by these Terms of Service. If you do not agree, do not use the App.

2. Eligibility
You must be at least 18 years old, or use the App under the supervision of a parent or legal guardian. By using the App you represent that you meet these requirements.

3. Description of Service
CareMe is a personal health-management tool that lets you record and review your own medications, lab results, and appointments, set reminders, and chat with an AI assistant ("CareAI") for general wellness information. CareMe is provided "as is" and does not constitute medical advice, diagnosis, or treatment.

4. Medical Disclaimer
THE APP IS NOT A MEDICAL DEVICE. Information shown — including content generated by CareAI — is for informational purposes only and is not a substitute for professional medical judgment. Always consult a qualified healthcare provider before starting, changing, or stopping any treatment. In case of a medical emergency call your local emergency number immediately; do not rely on the App.

5. Account & Security
You are responsible for keeping your credentials confidential and for all activity that occurs under your account. Notify us immediately at support@careme.app if you suspect unauthorized access. We may suspend or terminate accounts that violate these Terms or applicable law.

6. User Content & Accuracy
You retain ownership of the data you enter ("User Content"). You alone are responsible for the accuracy, completeness, and legality of that data. By submitting content you grant CareMe a limited licence to store and process it solely to operate the App for you.

7. Acceptable Use
You agree not to: (a) misuse the App, attempt to disrupt our infrastructure, or reverse engineer it; (b) submit content you do not have the right to share; (c) use the App to harass, harm, or impersonate others; (d) rely on CareAI for emergency, diagnostic, or treatment decisions.

8. Third-Party Services
CareMe integrates with third-party services (e.g. Google Sign-In, Google Calendar, Google Maps, Google Generative Language API, Firebase Cloud Messaging). Your use of those services is governed by their own terms and privacy policies.

9. Changes to the Service or Terms
We may update the App or these Terms at any time. Material changes will be communicated through the App. Continued use after a change constitutes acceptance of the revised Terms.

10. Disclaimers & Limitation of Liability
TO THE MAXIMUM EXTENT PERMITTED BY LAW, CAREME AND ITS CONTRIBUTORS PROVIDE THE APP WITHOUT WARRANTIES OF ANY KIND AND ARE NOT LIABLE FOR ANY INDIRECT, INCIDENTAL, CONSEQUENTIAL, OR SPECIAL DAMAGES, INCLUDING LOSS OF DATA, ARISING FROM YOUR USE OF THE APP.

11. Termination
You may stop using the App at any time. We may suspend or terminate access where required by law or in response to misuse. You can deactivate your account from Settings → Security & Privacy.

12. Governing Law
These Terms are governed by the laws of the user\'s country of residence, except where mandatory consumer-protection rules require otherwise.

13. Contact
Questions or concerns about these Terms: support@careme.app.''';

  static const String _privacyText = '''Last updated: April 2026

1. Who We Are
CareMe ("we", "us") is the operator of the CareMe mobile application. This Privacy Policy explains what information we collect about you, how we use it, and the choices you have.

2. Information We Collect
- Account information: name, email address, hashed password, date of birth, country code, phone number, and home address (with optional GPS coordinates for finding nearby providers).
- Health information you choose to record: medications, dosages, schedules, lab tests and uploaded files, appointments.
- Authentication data: when you sign in with Google we receive your Google profile name and email; we do not access your contacts or other Google data unless you grant calendar sync.
- Device data: a Firebase Cloud Messaging token used to deliver reminder notifications, and basic diagnostic logs.
- Chat content: messages you send to CareAI and any files you attach are sent to Google\'s Generative Language API to produce a response.

3. How We Use Your Information
We use your data only to provide the App\'s features: storing your records, sending medication reminders, generating personalized AI responses, and securing your account. We do not use your health data for advertising.

4. Legal Basis
We process personal data based on (a) the contract between you and us when you accept these Terms and (b) your consent for optional features such as location services, push notifications, camera, calendar sync, and AI chat.

5. Data Security
Your password is stored using a one-way hash. Sensitive health fields (medication, lab data) are encrypted at rest with a server-managed key. All traffic between the App and our servers travels over HTTPS/TLS.

6. Sharing & Third Parties
We do not sell, rent, or trade your personal information. We share data only with the service providers strictly required to run the App — for example Google (Sign-In, Maps, Calendar, Generative Language API) and Firebase (push notifications). Each provider acts as our data processor and is bound by its own commitments.

7. Data Retention
We keep your data while your account is active. If you deactivate your account, your records are retained in a disabled state in case you wish to reactivate. You may request permanent deletion at any time by emailing support@careme.app.

8. Your Rights
Depending on your jurisdiction (e.g. GDPR for the EU/EEA, CCPA for California), you may have the right to access, correct, export, restrict, or delete your personal data. Use Settings → Security & Privacy → Download My Data to export, or contact us to exercise other rights.

9. Children
CareMe is not directed to children under 13 (or the relevant local minimum age). We do not knowingly collect data from such users. If you believe a child has created an account, please contact us so we can remove it.

10. Health-Information Notice
CareMe is intended for personal recordkeeping and is not a HIPAA-covered entity. Records you store are not subject to HIPAA, but we apply commercially reasonable safeguards to protect them.

11. Changes to This Policy
We may update this policy as the App evolves. Material changes will be highlighted in-app. The "Last updated" date at the top reflects the current version.

12. Contact
Privacy questions or requests: support@careme.app.''';

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
                  const Text('About CareMe',
                      style: TextStyle(
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
                    child: Image.asset('assets/CareMe-Logo.png',
                        width: 80, height: 80),
                  ),
                  const SizedBox(height: 12),
                  Text('CareMe',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context))),
                  const SizedBox(height: 4),
                  Text('Version 1.0.0',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textMuted(context))),
                  const SizedBox(height: 16),
                  Text(
                    'CareMe is your personal health companion, designed to help you stay on top of your health by managing medications, tracking lab results, and organizing medical appointments — all in one place.',
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
                        Text('Key Features',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary(context))),
                        const SizedBox(height: 10),
                        const _FeatureRow(
                            icon: Icons.medication_outlined,
                            color: Color(0xFF2563EB),
                            text: 'Medication tracking & reminders'),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                            icon: Icons.science_outlined,
                            color: Color(0xFF7C3AED),
                            text: 'Lab test records & file uploads'),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                            icon: Icons.calendar_month_outlined,
                            color: Color(0xFF16A34A),
                            text: 'Appointment scheduling'),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                            icon: Icons.smart_toy_outlined,
                            color: Color(0xFFF97316),
                            text: 'AI-powered health assistant'),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                            icon: Icons.picture_as_pdf_outlined,
                            color: Color(0xFFDC2626),
                            text: 'Export health data as PDF'),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                            icon: Icons.lock_outline,
                            color: Color(0xFF0891B2),
                            text: 'Secure & private by design'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Built with care for your well-being.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted(context),
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'support@careme.app',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeactivateAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 10),
            Text('Deactivate Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will deactivate your account and sign you out. Your data (medications, lab tests, files) is preserved and not deleted.\n\nYou will not be able to sign in again until you contact support to reactivate your account.',
          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.deactivateAccount();
                if (mounted) {
                  widget.onLogout();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Account deactivated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to deactivate account: $e')),
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
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
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
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: Text('Security & Privacy',
                              style: TextStyle(
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
                _buildSection('Password & Authentication', [
                  _buildNavRow(Icons.lock_outline, const Color(0xFFDC2626),
                      'Change Password', 'Verify your identity first', () {
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
                _buildSection('Privacy Controls', [
                  _buildNavRow(
                      Icons.storage_outlined,
                      const Color(0xFF7C3AED),
                      'Download My Data',
                      'Export all your information',
                      _downloadMyData),
                  _buildNavRow(
                      Icons.shield_outlined,
                      const Color(0xFFDC2626),
                      'Deactivate Account',
                      'Disable account; data is preserved',
                      _confirmDeactivateAccount),
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
                Text('Dark Mode',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: primaryTextColor,
                        fontSize: 14)),
                Text(isDark ? 'On' : 'Off',
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
          Text('Phone Number',
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
                    hintText: 'Phone number',
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
              hintText: 'Tap to select date',
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

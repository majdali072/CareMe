import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/api_service.dart';

class AccountScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onBack;

  const AccountScreen({
    super.key,
    required this.userName,
    required this.onLogout,
    required this.onBack,
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
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _fullName = widget.userName;
    _loadProfileImage();
    _loadProfile();
  }

  Future<void> _loadProfileImage() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'profile_pic.jpg'));
    if (await file.exists()) {
      setState(() => _profileImage = file);
    }
  }

  Future<void> _pickProfileImage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Change Profile Picture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF2563EB)),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB)),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  title: const Text('Remove Photo', style: TextStyle(color: Color(0xFFDC2626))),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'remove') {
      await _removeProfileImage();
      return;
    }

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 80);
    if (picked == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final savedPath = p.join(dir.path, 'profile_pic.jpg');
    final savedFile = await File(picked.path).copy(savedPath);
    setState(() => _profileImage = savedFile);
  }

  Future<void> _removeProfileImage() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'profile_pic.jpg'));
    if (await file.exists()) await file.delete();
    setState(() => _profileImage = null);
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 12),
                          const Text('Select Country', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchCtrl,
                            onChanged: (val) {
                              setSheetState(() {
                                filtered = _countries.where((c) =>
                                  c['name']!.toLowerCase().contains(val.toLowerCase()) ||
                                  c['code']!.contains(val)
                                ).toList();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search country...',
                              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          final isSelected = country['code'] == _countryCode && country['flag'] == _countryFlag;
                          return ListTile(
                            leading: Text(country['flag']!, style: const TextStyle(fontSize: 24)),
                            title: Text(country['name']!, style: const TextStyle(fontSize: 15)),
                            trailing: Text(
                              country['code']!,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFEFF6FF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: widget.onBack,
                          ),
                        ),
                        const Center(
                          child: Text('Account', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Stack(
                        children: [
                          _buildAvatar(80),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                    Text(_email, style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 13)),
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
                  _buildInfoRow(Icons.phone_outlined, 'Phone', _phone.isEmpty ? 'Not set' : _phone),
                  _buildInfoRow(Icons.cake_outlined, 'Date of Birth', _dateOfBirth.isEmpty ? 'Not set' : _dateOfBirth),
                  _buildInfoRow(Icons.location_on_outlined, 'Address', _address.isEmpty ? 'Not set' : _address),
                ]),
                const SizedBox(height: 14),
                _buildSection('Settings', [
                  _buildNavRow(Icons.person_outline, const Color(0xFF2563EB), 'Edit Profile', 'Update your personal information', () => setState(() => _showEditProfile = true)),
                  _buildNavRow(Icons.lock_outline, const Color(0xFFDC2626), 'Security & Privacy', 'Password, privacy controls', () => setState(() => _showSecurity = true)),
                ]),
                const SizedBox(height: 14),
                _buildSection('Support', [
                  _buildNavRow(Icons.help_outline, const Color(0xFF16A34A), 'Help & Support', 'FAQs and contact support', () {}),
                  _buildNavRow(Icons.description_outlined, const Color(0xFF7C3AED), 'Terms & Privacy', 'View policies', () {}),
                  _buildNavRow(Icons.info_outline, const Color(0xFF0891B2), 'About CareMe', 'Version 1.0.0', () {}),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final addrCtrl = TextEditingController(text: _address);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(left: 16, top: 14, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _showEditProfile = false))),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          children: [
                            _buildAvatar(80),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(color: const Color(0xFF1976D2), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white, width: 2)),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: const Text('Change profile picture', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12)),
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
                  _buildEditField('Address', addrCtrl),
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
                                address: addrCtrl.text,
                              );
                              setState(() {
                                _fullName = nameCtrl.text;
                                _phone = fullPhone;
                                _dateOfBirth = dobCtrl.text;
                                _address = addrCtrl.text;
                                _showEditProfile = false;
                                _isSaving = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully')),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 10),
            Text('Delete Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and all your data including medications, lab tests, and uploaded files.\n\nThis action cannot be undone.',
          style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.deleteAccount();
                if (mounted) {
                  widget.onLogout();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Forever'),
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
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1976D2), Color(0xFF0D47A1)]),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(left: 16, top: 14, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _showSecurity = false))),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Security & Privacy', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                _buildSection('Password & Authentication', [
                  _buildNavRow(Icons.lock_outline, const Color(0xFFDC2626), 'Change Password', 'Last changed 3 months ago', () {}),
                ]),
                const SizedBox(height: 14),
                _buildSection('Privacy Controls', [
                  _buildNavRow(Icons.storage_outlined, const Color(0xFF7C3AED), 'Download My Data', 'Export all your information', () {}),
                  _buildNavRow(Icons.shield_outlined, const Color(0xFFDC2626), 'Delete Account', 'Permanently remove account', _confirmDeleteAccount),
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
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: _profileImage == null
            ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)])
            : null,
        borderRadius: BorderRadius.circular(size / 2),
        image: _profileImage != null
            ? DecorationImage(
                image: FileImage(_profileImage!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _profileImage == null
          ? Center(
              child: Text(
                _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U',
                style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111418), fontSize: 15)),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
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
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF111418))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(IconData icon, Color iconBg, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconBg, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF111418), fontSize: 14)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
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
          const Text('Phone Number', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_countryFlag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(_countryCode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111418))),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            readOnly: true,
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
              fillColor: const Color(0xFFF9FAFB),
              hintText: 'Tap to select date',
              suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6B7280)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

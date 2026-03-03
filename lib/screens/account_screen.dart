import 'package:flutter/material.dart';

class AccountScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onLogout;
  final VoidCallback onBack;

  const AccountScreen({super.key, required this.userName, required this.onLogout, required this.onBack});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _showEditProfile = false;
  bool _showSecurity = false;

  // Profile fields
  late String _fullName;
  late String _email;
  String _phone = '+1 (555) 123-4567';
  String _dateOfBirth = '1990-01-15';
  String _address = '123 Main Street, City';

  @override
  void initState() {
    super.initState();
    _fullName = widget.userName;
    _email = '${widget.userName.toLowerCase()}@email.com';
  }

  @override
  Widget build(BuildContext context) {
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
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
                          left: 0, top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: widget.onBack,
                          ),
                        ),
                        const Center(child: Text('Account', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Stack(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Center(
                            child: Text(
                              _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
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
                  _buildInfoRow(Icons.phone_outlined, 'Phone', _phone),
                  _buildInfoRow(Icons.cake_outlined, 'Date of Birth', _dateOfBirth),
                  _buildInfoRow(Icons.location_on_outlined, 'Address', _address),
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
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]), borderRadius: BorderRadius.circular(40)),
                            child: Center(child: Text(_fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                          ),
                          Positioned(bottom: 0, right: 0, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: const Color(0xFF1976D2), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Change profile picture', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSection('General Information', [
                  _buildEditField('Full Name', nameCtrl),
                  _buildEditField('Email Address', emailCtrl, keyboardType: TextInputType.emailAddress),
                  _buildEditField('Phone Number', phoneCtrl, keyboardType: TextInputType.phone),
                  _buildEditField('Date of Birth', dobCtrl),
                  _buildEditField('Address', addrCtrl),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _fullName = nameCtrl.text;
                        _email = emailCtrl.text;
                        _phone = phoneCtrl.text;
                        _dateOfBirth = dobCtrl.text;
                        _address = addrCtrl.text;
                        _showEditProfile = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
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
              child: Stack(children: [
                Positioned(left: 16, top: 14, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _showSecurity = false))),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Security & Privacy', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))),
              ]),
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
                  _buildNavRow(Icons.shield_outlined, const Color(0xFFDC2626), 'Delete Account', 'Permanently remove account', () {}),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
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
              decoration: BoxDecoration(color: iconBg.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
}

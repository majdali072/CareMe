import 'package:flutter/material.dart';

class AdminSettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const AdminSettingsScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Admin Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildSection('System Configuration', [
                  _buildRow(Icons.notifications_outlined, const Color(0xFF0891B2), 'Notification Settings', 'Push & email alerts'),
                  _buildRow(Icons.security, const Color(0xFF7C3AED), 'Security Config', 'Authentication settings'),
                  _buildRow(Icons.storage_outlined, const Color(0xFFD97706), 'Database Management', 'Backups & exports'),
                ]),
                const SizedBox(height: 14),
                _buildSection('Account', [
                  _buildRow(Icons.person_outline, const Color(0xFF2563EB), 'Admin Profile', 'Edit admin details'),
                  _buildRow(Icons.history, const Color(0xFF16A34A), 'Audit Logs', 'System activity history'),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
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

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111418)))),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, Color color, String title, String subtitle) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
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
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

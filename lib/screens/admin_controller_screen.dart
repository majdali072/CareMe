import 'package:flutter/material.dart';

class AdminControllerScreen extends StatelessWidget {
  const AdminControllerScreen({super.key});

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Healthcare System Controller', style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Stats Row
                Row(
                  children: [
                    Expanded(child: _statCard('Total Users', '1,248', Icons.people_outline, const Color(0xFF2563EB))),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Active Today', '342', Icons.trending_up, const Color(0xFF16A34A))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _statCard('Medications', '4,891', Icons.medication_outlined, const Color(0xFFD97706))),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Appointments', '627', Icons.calendar_today_outlined, const Color(0xFF7C3AED))),
                  ],
                ),
                const SizedBox(height: 20),

                // Management Section
                _buildSectionCard('User Management', [
                  _buildActionRow(Icons.group_outlined, const Color(0xFF2563EB), 'Manage Users', 'View, edit, suspend users'),
                  _buildActionRow(Icons.person_add_outlined, const Color(0xFF16A34A), 'Add New User', 'Create healthcare account'),
                  _buildActionRow(Icons.bar_chart, const Color(0xFFD97706), 'Usage Analytics', 'View usage statistics'),
                ]),
                const SizedBox(height: 14),
                _buildSectionCard('System', [
                  _buildActionRow(Icons.medication_outlined, const Color(0xFF7C3AED), 'Drug Database', 'Manage drug interactions'),
                  _buildActionRow(Icons.notifications_outlined, const Color(0xFF0891B2), 'Notifications', 'System-wide alerts'),
                  _buildActionRow(Icons.backup_outlined, const Color(0xFF16A34A), 'Backup & Restore', 'Data management'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF111418))),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, Color color, String title, String subtitle) {
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

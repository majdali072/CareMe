import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  final String currentPage;
  final void Function(String) onNavigate;

  const BottomNav({super.key, required this.currentPage, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = [
      ['home', 'Home'],
      ['medications', 'Health'],
      ['calendar', 'Appointments'],
      ['account', 'Account'],
    ];
    final icons = [
      Icons.home_rounded,
      Icons.medication_rounded,
      Icons.calendar_month_rounded,
      Icons.person_rounded,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context).withOpacity(0.95),
        border: Border(top: BorderSide(color: AppColors.border(context), width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(items.length, (i) {
              final id = items[i][0];
              final label = items[i][1];
              final isActive = currentPage == id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onNavigate(id),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                              : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icons[i], color: isActive ? Colors.white : AppColors.textSecondary(context), size: 24),
                      ),
                      const SizedBox(height: 2),
                      Text(label, style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF2563EB) : AppColors.textSecondary(context), fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

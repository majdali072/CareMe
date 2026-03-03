import 'package:flutter/material.dart';

class FloatingButtons extends StatefulWidget {
  final String currentPage;
  final VoidCallback onAddMedication;
  final VoidCallback onAddLabTest;
  final VoidCallback onAddSchedule;
  final VoidCallback onOpenChatbot;

  const FloatingButtons({
    super.key,
    required this.currentPage,
    required this.onAddMedication,
    required this.onAddLabTest,
    required this.onAddSchedule,
    required this.onOpenChatbot,
  });

  @override
  State<FloatingButtons> createState() => _FloatingButtonsState();
}

class _FloatingButtonsState extends State<FloatingButtons> with SingleTickerProviderStateMixin {
  bool _showMenu = false;
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
    if (_showMenu) _animCtrl.forward(); else _animCtrl.reverse();
  }

  List<_AddOption> _getOptions() {
    switch (widget.currentPage) {
      case 'home':
        return [
          _AddOption('Medication', Icons.medication, widget.onAddMedication),
          _AddOption('Lab Test', Icons.description_outlined, widget.onAddLabTest),
          _AddOption('Appointment', Icons.calendar_today, widget.onAddSchedule),
        ];
      case 'medications':
        return [
          _AddOption('Medication', Icons.medication, widget.onAddMedication),
          _AddOption('Lab Test', Icons.description_outlined, widget.onAddLabTest),
        ];
      case 'calendar':
        return [_AddOption('Appointment', Icons.calendar_today, widget.onAddSchedule)];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _getOptions();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded options
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => ClipRect(
            child: Align(
              heightFactor: _anim.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: options.map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
                        ),
                        child: Text(opt.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111418))),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () { opt.onTap(); _toggleMenu(); },
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Icon(opt.icon, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        ),

        // Chatbot button
        if (widget.currentPage != 'chatbot') ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onOpenChatbot,
            child: Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF9333EA).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
            ),
          ),
        ],

        // Add FAB
        if (options.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _toggleMenu,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: _showMenu
                    ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: AnimatedRotation(
                turns: _showMenu ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddOption {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _AddOption(this.label, this.icon, this.onTap);
}

import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ChatbotScreen({super.key, required this.onBack});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  int _nextId = 2;

  List<ChatMessage> _messages = [
    ChatMessage(
      id: 1,
      text: "Hello! I'm CareAI, your intelligent health assistant. I can help you with medications, appointments, lab results, and health questions. How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  final List<String> _quickActions = [
    'Show my medications',
    'Next appointment',
    'Latest lab results',
    'Set a reminder',
  ];

  List<Map<String, dynamic>> _buildHistory() {
    // Send previous messages (skip the initial greeting) as context
    return _messages.skip(1).map((m) => {
      'text': m.text,
      'isUser': m.isUser,
    }).toList();
  }

  void _sendMessage([String? text]) async {
    final content = text ?? _inputCtrl.text.trim();
    if (content.isEmpty) return;
    _inputCtrl.clear();

    final userMsg = ChatMessage(id: _nextId++, text: content, isUser: true, timestamp: DateTime.now());
    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final reply = await ApiService.sendChatMessage(content, _buildHistory());
      if (!mounted) return;
      final botMsg = ChatMessage(id: _nextId++, text: reply, isUser: false, timestamp: DateTime.now());
      setState(() {
        _messages.add(botMsg);
        _isTyping = false;
      });
    } catch (e) {
      if (!mounted) return;
      String errorText;
      if (e.toString().contains('TimeoutException') || e.toString().contains('timed out')) {
        errorText = "The request timed out. The AI server may be busy — please try again in a moment.";
      } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        errorText = "Could not reach the server. Please check your internet connection and try again.";
      } else {
        errorText = "Something went wrong: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e}. Please try again.";
      }
      final errorMsg = ChatMessage(
        id: _nextId++,
        text: errorText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMsg);
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
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
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CareAI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      Text('Always here to help', style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _messages.length + (_isTyping ? 1 : 0) + (_messages.length == 1 ? 1 : 0),
            itemBuilder: (ctx, i) {
              // Quick actions row after first message
              if (_messages.length == 1 && i == 1) {
                return _buildQuickActions();
              }
              final msgIndex = _messages.length == 1 && i > 1 ? i - 1 : i;
              if (_isTyping && msgIndex == _messages.length) {
                return _buildTypingIndicator();
              }
              if (msgIndex >= _messages.length) return const SizedBox.shrink();
              return _buildMessage(_messages[msgIndex]);
            },
          ),
        ),

        // Input Area
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          color: const Color(0xFFF8FAFC),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    onSubmitted: _sendMessage,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(5),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Space for bottom nav
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMessage(ChatMessage msg) {
    final timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: msg.isUser
                    ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: msg.isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg.text, style: TextStyle(fontSize: 14, color: msg.isUser ? Colors.white : const Color(0xFF111418), height: 1.4)),
                  const SizedBox(height: 4),
                  Text(timeStr, style: TextStyle(fontSize: 11, color: msg.isUser ? Colors.white70 : const Color(0xFF9CA3AF))),
                ],
              ),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_outline, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
            ),
            child: Row(
              children: List.generate(3, (i) => _dot(i * 200)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (ctx, val, _) => Container(
        width: 8, height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFF9CA3AF), const Color(0xFF3B82F6), val),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _quickActions.map((action) => GestureDetector(
              onTap: () => _sendMessage(action),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: Text(action, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatbotScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Uint8List? profilePhoto;
  const ChatbotScreen({super.key, required this.onBack, this.profilePhoto});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatAttachment {
  final Uint8List bytes;
  final String name;
  final String mimeType;
  _ChatAttachment({required this.bytes, required this.name, required this.mimeType});
  bool get isImage => mimeType.startsWith('image/');
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  int _nextId = 2;
  _ChatAttachment? _attachment;

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
  ];

  // Cap history sent to the backend to the last N turns so token count
  // and request latency stay bounded as the conversation grows.
  static const int _historyLimit = 10;

  List<Map<String, dynamic>> _buildHistory() {
    // Skip the initial greeting, then keep only the last `_historyLimit` turns.
    final prior = _messages.skip(1).toList();
    final start = prior.length > _historyLimit ? prior.length - _historyLimit : 0;
    return prior.sublist(start).map((m) => {
      'text': m.text,
      'isUser': m.isUser,
    }).toList();
  }

  void _sendMessage([String? text]) async {
    final content = text ?? _inputCtrl.text.trim();
    final attachment = _attachment;
    if (content.isEmpty && attachment == null) return;
    _inputCtrl.clear();

    final history = _buildHistory();
    // Describe the attachment in the visible user-message bubble so there's
    // a record of what was sent.
    String visibleText = content;
    if (attachment != null) {
      final tag = attachment.isImage
          ? '[Image attached: ${attachment.name}]'
          : '[File attached: ${attachment.name}]';
      visibleText = content.isEmpty ? tag : '$tag\n$content';
    }

    final Map<String, String>? wirePayload = attachment == null
        ? null
        : {
            'mimeType': attachment.mimeType,
            'data': base64Encode(attachment.bytes),
          };

    final userMsg = ChatMessage(
        id: _nextId++,
        text: visibleText,
        isUser: true,
        timestamp: DateTime.now());
    final botId = _nextId++;
    final botTimestamp = DateTime.now();

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
      _attachment = null; // clear after sending
    });
    _scrollToBottom();

    final buffer = StringBuffer();
    var botInserted = false;

    void upsertBotMessage(String newText) {
      final msg = ChatMessage(
        id: botId,
        text: newText,
        isUser: false,
        timestamp: botTimestamp,
      );
      if (!botInserted) {
        _messages.add(msg);
        botInserted = true;
      } else {
        final idx = _messages.indexWhere((m) => m.id == botId);
        if (idx != -1) _messages[idx] = msg;
      }
    }

    try {
      await for (final chunk
          in ApiService.streamChatMessage(content, history, attachment: wirePayload)) {
        if (!mounted) return;
        buffer.write(chunk);
        setState(() {
          _isTyping = false;
          upsertBotMessage(buffer.toString());
        });
        _scrollToBottom();
      }
      if (!botInserted && mounted) {
        // Stream closed without any content.
        setState(() {
          _isTyping = false;
          upsertBotMessage("I didn't catch that — could you ask again?");
        });
      }
    } catch (e) {
      if (!mounted) return;
      String errorText;
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timed out')) {
        errorText =
            "The request timed out. The AI server may be busy — please try again in a moment.";
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        errorText =
            "Could not reach the server. Please check your internet connection and try again.";
      } else {
        final msg = e.toString();
        errorText =
            "Something went wrong: ${msg.length > 100 ? msg.substring(0, 100) : msg}. Please try again.";
      }
      setState(() {
        _isTyping = false;
        upsertBotMessage(errorText);
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
          color: AppColors.background(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_attachment != null) _buildAttachmentPreview(_attachment!),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: AppColors.accent(context), size: 26),
                      onPressed: _showAttachmentSheet,
                      tooltip: 'Attach a file or photo',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        onSubmitted: _sendMessage,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: _attachment == null
                              ? 'Type your message...'
                              : 'Ask a question about this file...',
                          hintStyle: TextStyle(color: AppColors.textMuted(context)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            ],
          ),
        ),
        // Reserve space for the bottom nav + the device's gesture-bar
        // inset so the chat input doesn't slide under the nav on phones
        // with a system home-bar at the bottom.
        SizedBox(height: 68 + MediaQuery.of(context).padding.bottom),
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
                color: msg.isUser ? null : AppColors.surface(context),
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
                  msg.isUser
                      ? Text(
                          msg.text,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              height: 1.4),
                        )
                      : _buildMessageContent(msg),
                  const SizedBox(height: 4),
                  Text(timeStr, style: TextStyle(fontSize: 11, color: msg.isUser ? Colors.white70 : AppColors.textMuted(context))),
                ],
              ),
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: widget.profilePhoto == null
                    ? const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                borderRadius: BorderRadius.circular(16),
                image: widget.profilePhoto != null
                    ? DecorationImage(image: MemoryImage(widget.profilePhoto!), fit: BoxFit.cover)
                    : null,
              ),
              child: widget.profilePhoto == null
                  ? const Icon(Icons.person_outline, color: Colors.white, size: 18)
                  : null,
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
              color: AppColors.surface(context),
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

  // ── Attachment ────────────────────────────────────────────────────────────

  // ── Markdown rendering ───────────────────────────────────────────────────

  Widget _buildMessageContent(ChatMessage msg) {
    final textColor = msg.isUser
        ? Colors.white
        : AppColors.textPrimary(context);
    final mutedColor = msg.isUser
        ? Colors.white70
        : AppColors.textMuted(context);
    return MarkdownBody(
      data: msg.text,
      selectable: true,
      onTapLink: (text, href, title) async {
        // No URL launcher wired up — just ignore for now.
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 14, color: textColor, height: 1.4),
        strong: TextStyle(
            fontSize: 14, color: textColor, fontWeight: FontWeight.w700),
        em: TextStyle(
            fontSize: 14, color: textColor, fontStyle: FontStyle.italic),
        del: TextStyle(
            fontSize: 14,
            color: textColor,
            decoration: TextDecoration.lineThrough),
        listBullet: TextStyle(fontSize: 14, color: textColor),
        a: TextStyle(
            color: msg.isUser ? Colors.white : const Color(0xFF2563EB),
            decoration: TextDecoration.underline),
        code: TextStyle(
            fontSize: 13,
            color: textColor,
            backgroundColor: msg.isUser
                ? Colors.white.withOpacity(0.18)
                : AppColors.surfaceAlt(context)),
        codeblockDecoration: BoxDecoration(
          color: msg.isUser
              ? Colors.white.withOpacity(0.18)
              : AppColors.surfaceAlt(context),
          borderRadius: BorderRadius.circular(8),
        ),
        h1: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.w700),
        h2: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w700),
        h3: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w600),
        blockquote: TextStyle(fontSize: 14, color: mutedColor),
      ),
    );
  }

  Widget _buildAttachmentPreview(_ChatAttachment att) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: att.isImage
                ? Image.memory(att.bytes, width: 48, height: 48, fit: BoxFit.cover)
                : Container(
                    width: 48,
                    height: 48,
                    color: AppColors.tint(context),
                    child: Icon(Icons.description_outlined,
                        color: AppColors.accent(context)),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(att.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context)),
                    overflow: TextOverflow.ellipsis),
                Text(att.mimeType,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted(context))),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.textMuted(context)),
            onPressed: () => setState(() => _attachment = null),
          ),
        ],
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile(Icons.camera_alt_outlined, 'Take photo', () async {
              Navigator.pop(ctx);
              await _pickFromCamera();
            }),
            _sheetTile(Icons.photo_library_outlined, 'Choose from gallery',
                () async {
              Navigator.pop(ctx);
              await _pickFromGallery();
            }),
            _sheetTile(Icons.attach_file_outlined, 'Choose a file', () async {
              Navigator.pop(ctx);
              await _pickFile();
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent(context)),
      title: Text(label,
          style: TextStyle(color: AppColors.textPrimary(context))),
      onTap: onTap,
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _setAttachment(bytes, picked.name, _imageMime(picked.name));
    } catch (e) {
      _showSnack('Could not open camera: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _setAttachment(bytes, picked.name, _imageMime(picked.name));
    } catch (e) {
      _showSnack('Could not open gallery: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes ??
          (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) return;
      _setAttachment(bytes, f.name, _fileMime(f.name));
    } catch (e) {
      _showSnack('Could not pick file: $e');
    }
  }

  void _setAttachment(Uint8List bytes, String name, String mimeType) {
    // Gemini inline_data is limited to ~20 MB. Bail out early on huge files.
    if (bytes.length > 15 * 1024 * 1024) {
      _showSnack('File too large. Pick something under 15 MB.');
      return;
    }
    setState(() {
      _attachment = _ChatAttachment(
          bytes: bytes, name: name, mimeType: mimeType);
    });
  }

  String _imageMime(String name) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  String _fileMime(String name) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: TextStyle(fontSize: 11, color: AppColors.textMuted(context), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _quickActions.map((action) => GestureDetector(
              onTap: () => _sendMessage(action),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: Text(action, style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

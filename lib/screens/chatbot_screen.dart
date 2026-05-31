import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatbotScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Uint8List? profilePhoto;
  // Called when CareAI emits a `careme-action` block to add a medication.
  // The host saves the medication directly (no popup) and refreshes its UI.
  // The AI's natural-language reply is the rundown the user sees; this
  // callback is purely for the data-side persist + state refresh.
  final void Function(Medication med)? onSaveMedicationFromAi;
  // Same for appointments.
  final void Function(Appointment apt)? onSaveAppointmentFromAi;
  // Delete a medication by name (case-insensitive match against the user's
  // active medications). Host resolves the name to an id and calls the API.
  final void Function(String name)? onDeleteMedicationFromAi;
  // Update a medication. Host finds the existing medication by `name`
  // (or `originalName` if a rename was requested) and merges the supplied
  // fields onto it before persisting.
  final void Function(Map<String, dynamic> fields)? onUpdateMedicationFromAi;
  // Delete an appointment by title + optional date.
  final void Function(String title, DateTime? date)? onDeleteAppointmentFromAi;
  // Update an appointment. Host finds it by `title` + optional `date` and
  // merges the supplied changes.
  final void Function(Map<String, dynamic> fields)? onUpdateAppointmentFromAi;

  const ChatbotScreen({
    super.key,
    required this.onBack,
    this.profilePhoto,
    this.onSaveMedicationFromAi,
    this.onSaveAppointmentFromAi,
    this.onDeleteMedicationFromAi,
    this.onUpdateMedicationFromAi,
    this.onDeleteAppointmentFromAi,
    this.onUpdateAppointmentFromAi,
  });

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
  // `_isTyping` shows the 3-dot bubble while we wait for the FIRST chunk.
  // `_isStreaming` shows a small "generating..." pill under the latest bot
  // message for the rest of the stream so the user knows tokens are still
  // arriving even after some text has appeared.
  bool _isTyping = false;
  bool _isStreaming = false;
  // Held while a response is streaming so the user can cancel via the stop
  // button. Cancelling drops further chunks; the partial text already in the
  // bot bubble stays visible.
  StreamSubscription<String>? _chatSub;
  int _nextId = 2;
  _ChatAttachment? _attachment;

  // All non-expired chat sessions, oldest first. The session at
  // `_currentSessionIdx` is the one the user is currently in; older ones are
  // browsable from the history sheet.
  final List<ChatSession> _sessions = [];
  int _currentSessionIdx = 0;

  // Per-session user-message count at which we last (re)generated the title,
  // so we refresh the title as the conversation grows without calling the
  // backend on every single turn.
  final Map<String, int> _titledAtUserCount = {};

  // Inline-completion state. `_suggestions` holds up to 3 phrases shown as
  // chips above the input; refreshed via a debounce timer as the user types.
  List<String> _suggestions = const [];
  Timer? _suggestDebounce;
  // Token used to discard stale completion responses. Each fetch grabs the
  // current value, then ignores its result if `_suggestToken` has moved on.
  int _suggestToken = 0;

  /// Convenience pointer at the current session's message list. The build
  /// methods read from this so the rest of the screen doesn't have to know
  /// sessions exist.
  List<ChatMessage> get _messages => _currentSession.messages;

  ChatSession get _currentSession {
    if (_sessions.isEmpty || _currentSessionIdx >= _sessions.length) {
      _sessions.add(_makeEmptySession());
      _currentSessionIdx = _sessions.length - 1;
    }
    return _sessions[_currentSessionIdx];
  }

  ChatSession _makeEmptySession() => ChatSession(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt: DateTime.now(),
        messages: [],
      );

  // Banner shown to the user explaining the 7-day retention policy. Built
  // dynamically each render so it picks up the current locale.
  String _retentionBanner(BuildContext context) =>
      AppLocalizations.of(context).t('chat_retention_banner');

  List<String> _quickActions(BuildContext context) {
    final t = AppLocalizations.of(context);
    return [
      t.t('chat_qa_medications'),
      t.t('chat_qa_next_appointment'),
      t.t('chat_qa_latest_labs'),
    ];
  }

  // Cap history sent to the backend to the last N turns so token count
  // and request latency stay bounded as the conversation grows.
  static const int _historyLimit = 10;

  // SharedPreferences key for the persisted multi-session chat log. Scoped
  // per logged-in user so two accounts on the same device don't see each
  // other's chats.
  String get _storageKey {
    final email = ApiService.userEmail ?? 'anon';
    return 'chat_sessions::$email';
  }

  // Legacy single-thread key used before we introduced sessions. Read once
  // on first launch to migrate the old chat into the new sessions list.
  String get _legacyStorageKey {
    final email = ApiService.userEmail ?? 'anon';
    return 'chat_history::$email';
  }

  static const Duration _retentionWindow = Duration(days: 7);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Read persisted sessions, drop anything older than the 7-day window,
  /// then start a new empty session for this entry into the screen so each
  /// visit is its own chat. The user can still browse older sessions via
  /// the history sheet.
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <ChatSession>[];
    final cutoff = DateTime.now().subtract(_retentionWindow);

    final rawSessions = prefs.getString(_storageKey);
    if (rawSessions != null && rawSessions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSessions);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map) continue;
            final session = _decodeSession(entry, cutoff);
            if (session != null) loaded.add(session);
          }
        }
      } catch (_) {
        // Corrupt sessions blob — start fresh.
      }
    } else {
      // First run after upgrade: pull any flat-list legacy chat into a
      // single migrated session, so the user doesn't lose history.
      final rawLegacy = prefs.getString(_legacyStorageKey);
      if (rawLegacy != null && rawLegacy.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawLegacy);
          if (decoded is List) {
            final messages = <ChatMessage>[];
            for (final entry in decoded) {
              if (entry is! Map) continue;
              final ts = DateTime.tryParse((entry['timestamp'] ?? '').toString());
              if (ts == null || ts.isBefore(cutoff)) continue;
              messages.add(ChatMessage(
                id: _nextId++,
                text: (entry['text'] ?? '').toString(),
                isUser: entry['isUser'] == true,
                timestamp: ts,
              ));
            }
            if (messages.isNotEmpty) {
              loaded.add(ChatSession(
                id: 'legacy-${messages.first.timestamp.microsecondsSinceEpoch}',
                startedAt: messages.first.timestamp,
                messages: messages,
              ));
            }
          }
        } catch (_) {
          // ignore migration errors
        }
        // Don't try to migrate again on subsequent loads.
        await prefs.remove(_legacyStorageKey);
      }
    }

    // Sort oldest first so the most recent ends up last (current session goes
    // after that). This matches the order the history sheet expects.
    loaded.sort((a, b) => a.lastActivity.compareTo(b.lastActivity));

    if (!mounted) return;
    setState(() {
      _sessions
        ..clear()
        ..addAll(loaded)
        ..add(_makeEmptySession());
      _currentSessionIdx = _sessions.length - 1;
      // Insert the localized banner into every loaded session and the new
      // empty one so the welcome card always shows above the messages.
      for (final s in _sessions) {
        _ensureBanner(s);
      }
    });
    // Re-save so any pruned entries get written out and the new empty
    // session has a slot on disk.
    await _saveSessions();
  }

  /// Make sure [s] starts with the localized retention banner (id=1). Banner
  /// is in-memory only — `_saveSessions` filters it out before persisting.
  void _ensureBanner(ChatSession s) {
    if (s.messages.isNotEmpty && s.messages.first.id == 1) return;
    s.messages.insert(
      0,
      ChatMessage(
        id: 1,
        text: _retentionBanner(context),
        isUser: false,
        timestamp: s.startedAt,
      ),
    );
  }

  /// Open a new empty chat session. The current session (if non-empty) stays
  /// in `_sessions` so the user can revisit it from the history sheet.
  void _startNewSession() {
    setState(() {
      _sessions.add(_makeEmptySession());
      _currentSessionIdx = _sessions.length - 1;
      _ensureBanner(_currentSession);
      _suggestions = const [];
      _inputCtrl.clear();
    });
    _scrollToBottom();
  }

  /// Jump to a previous session from the history sheet.
  void _switchToSession(int idx) {
    if (idx < 0 || idx >= _sessions.length) return;
    setState(() {
      _currentSessionIdx = idx;
      _ensureBanner(_currentSession);
      _suggestions = const [];
      _inputCtrl.clear();
    });
    _scrollToBottom();
  }

  /// Parse one persisted session and drop it if every message is past the
  /// retention cutoff. Returns null when the session would be empty post-prune.
  ChatSession? _decodeSession(Map entry, DateTime cutoff) {
    final id = (entry['id'] ?? '').toString();
    final startedAt = DateTime.tryParse((entry['startedAt'] ?? '').toString());
    final rawMessages = entry['messages'];
    if (rawMessages is! List) return null;
    final messages = <ChatMessage>[];
    for (final m in rawMessages) {
      if (m is! Map) continue;
      final ts = DateTime.tryParse((m['timestamp'] ?? '').toString());
      if (ts == null || ts.isBefore(cutoff)) continue;
      messages.add(ChatMessage(
        id: _nextId++,
        text: (m['text'] ?? '').toString(),
        isUser: m['isUser'] == true,
        timestamp: ts,
      ));
    }
    // If every message expired, drop the whole session.
    if (messages.isEmpty) return null;
    final rawTitle = (entry['title'] ?? '').toString().trim();
    return ChatSession(
      id: id.isNotEmpty ? id : DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: startedAt ?? messages.first.timestamp,
      messages: messages,
      title: rawTitle.isEmpty ? null : rawTitle,
    );
  }

  /// Persist every session. Empty sessions (only the banner, never any user
  /// turn) are skipped so we don't accumulate ghost entries on every visit.
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <Map<String, dynamic>>[];
    for (final s in _sessions) {
      if (s.isEmpty) continue;
      payload.add({
        'id': s.id,
        'startedAt': s.startedAt.toIso8601String(),
        'title': s.title,
        'messages': s.messages
            // Drop the banner — it's regenerated on every load and isn't part
            // of the actual conversational record.
            .where((m) => m.id != 1)
            .map((m) => {
                  'text': m.text,
                  'isUser': m.isUser,
                  'timestamp': m.timestamp.toIso8601String(),
                })
            .toList(),
      });
    }
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  /// Convenience for places that used to call `_saveHistory`.
  Future<void> _saveHistory() => _saveSessions();

  List<Map<String, dynamic>> _buildHistory() {
    // Skip the initial greeting, then keep only the last `_historyLimit` turns.
    final prior = _messages.skip(1).toList();
    final start = prior.length > _historyLimit ? prior.length - _historyLimit : 0;
    return prior.sublist(start).map((m) => {
      'text': m.text,
      'isUser': m.isUser,
    }).toList();
  }

  /// Compact transcript of [session] (excluding the banner) for title
  /// generation. Caps to the most recent turns to keep the request small.
  List<Map<String, dynamic>> _historyForTitle(ChatSession session) {
    final msgs = session.messages.where((m) => m.id != 1).toList();
    const limit = 12;
    final start = msgs.length > limit ? msgs.length - limit : 0;
    return msgs
        .sublist(start)
        .map((m) => {'text': m.text, 'isUser': m.isUser})
        .toList();
  }

  /// Ask the backend for a short title summarizing [session] and store it.
  /// Runs after an AI reply completes. Regenerates while the conversation is
  /// young (so the title reflects the emerging topic, not just the first
  /// message) and then refreshes every few turns as it grows.
  Future<void> _maybeGenerateTitle(ChatSession session) async {
    final userCount = session.messages.where((m) => m.isUser).length;
    if (userCount == 0) return;

    final hasTitle = (session.title?.trim().isNotEmpty ?? false);
    final lastTitled = _titledAtUserCount[session.id] ?? 0;
    final shouldTitle = !hasTitle || userCount <= 3 || (userCount - lastTitled) >= 4;
    if (!shouldTitle) return;

    _titledAtUserCount[session.id] = userCount;
    final title = await ApiService.generateChatTitle(_historyForTitle(session));
    if (!mounted || title.trim().isEmpty) return;
    if (!_sessions.contains(session)) return;
    setState(() => session.title = title.trim());
    _saveSessions();
  }

  void _sendMessage([String? text]) {
    final content = text ?? _inputCtrl.text.trim();
    final attachment = _attachment;
    if (content.isEmpty && attachment == null) return;
    // Block submitting another question while one is still streaming —
    // the same button position is now showing Stop, so the user has to
    // explicitly cancel before sending the next.
    if (_isStreaming) return;
    _inputCtrl.clear();

    final t = AppLocalizations.of(context);
    final history = _buildHistory();
    // Capture the session this turn belongs to so a late-arriving title
    // update lands on the right chat even if the user switched sessions.
    final targetSession = _currentSession;
    // Describe the attachment in the visible user-message bubble so there's
    // a record of what was sent.
    String visibleText = content;
    if (attachment != null) {
      final tag = attachment.isImage
          ? t.t('chat_image_attached', {'name': attachment.name})
          : t.t('chat_file_attached', {'name': attachment.name});
      visibleText = content.isEmpty ? tag : '$tag\n$content';
    }

    final Map<String, String>? wirePayload = attachment == null
        ? null
        : {
            'name': attachment.name,
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
      _isStreaming = true;
      _attachment = null; // clear after sending
    });
    _scrollToBottom();
    _saveHistory();

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

    void finalizeStream() {
      if (!mounted) return;
      setState(() {
        _isStreaming = false;
        _isTyping = false;
      });
      _chatSub = null;
    }

    _chatSub = ApiService
        .streamChatMessage(content, history, attachment: wirePayload)
        .listen(
      (chunk) {
        if (!mounted) return;
        buffer.write(chunk);
        setState(() {
          _isTyping = false;
          upsertBotMessage(buffer.toString());
        });
        _scrollToBottom();
      },
      onError: (e) {
        if (!mounted) return;
        String errorText;
        final s = e.toString();
        if (s.contains('TimeoutException') || s.contains('timed out')) {
          errorText = t.t('chat_error_timeout');
        } else if (s.contains('SocketException') ||
            s.contains('Connection refused')) {
          errorText = t.t('chat_error_no_connection');
        } else {
          errorText = t.t('chat_error_unknown',
              {'error': s.length > 100 ? s.substring(0, 100) : s});
        }
        setState(() {
          _isTyping = false;
          upsertBotMessage(errorText);
        });
        _saveHistory();
        finalizeStream();
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) {
          finalizeStream();
          return;
        }
        if (!botInserted) {
          setState(() {
            _isTyping = false;
            upsertBotMessage(t.t('chat_no_reply'));
          });
        } else {
          final raw = buffer.toString();
          final stripped = _stripAndHandleActionBlock(raw);
          if (stripped != null && stripped != raw) {
            setState(() => upsertBotMessage(stripped));
          }
        }
        _saveHistory();
        finalizeStream();
        _scrollToBottom();
        // Give the chat an AI-generated title based on the whole conversation.
        _maybeGenerateTitle(targetSession);
      },
      cancelOnError: true,
    );
  }

  /// Stop the in-flight response. Cancels the stream subscription (so no
  /// more chunks render) and finalizes whatever the AI managed to say.
  void _stopGeneration() {
    final sub = _chatSub;
    _chatSub = null;
    sub?.cancel();
    if (!mounted) return;
    setState(() {
      _isStreaming = false;
      _isTyping = false;
    });
    _saveHistory();
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _suggestDebounce?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Called from the input's `onChanged`. Debounces the request so we don't
  /// hammer the backend on every keystroke, then fires a fresh suggestion
  /// fetch. Cancels in-flight stale fetches via `_suggestToken`.
  void _onInputChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      // Too short — clear chips immediately so the row collapses.
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      _suggestDebounce?.cancel();
      return;
    }
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String partial) async {
    final token = ++_suggestToken;
    final history = _buildHistory();
    final results = await ApiService.chatSuggest(partial, history);
    if (!mounted) return;
    // Drop the response if the user has typed since we sent it.
    if (token != _suggestToken) return;
    setState(() => _suggestions = results);
  }

  /// Look for a single `careme-action` fenced JSON block in the bot's reply.
  /// If we find one, parse it, build the typed object, and ask the host to
  /// save it directly (no dialog). Returns the reply text with the block
  /// removed; null when there's no block.
  String? _stripAndHandleActionBlock(String text) {
    final regex = RegExp(
      r'```\s*careme-action\s*\n([\s\S]*?)\n```',
      multiLine: true,
    );
    final match = regex.firstMatch(text);
    if (match == null) return null;

    final jsonStr = match.group(1)?.trim() ?? '';
    Map<String, dynamic>? action;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) action = decoded;
    } catch (_) {
      // Malformed JSON: still strip it from the visible text so the user
      // doesn't see the noise, but don't take any action.
    }

    final stripped = text.replaceFirst(regex, '').trimRight();

    if (action != null) {
      final type = (action['action'] ?? '').toString();
      final fieldsRaw = action['fields'];
      final fields = fieldsRaw is Map
          ? Map<String, dynamic>.from(fieldsRaw)
          : <String, dynamic>{};

      // Defer one frame so we don't kick off a save while setState from the
      // streaming text update is still settling.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (type) {
          case 'add_medication':
            final med = _medicationFromAction(fields);
            if (med != null && widget.onSaveMedicationFromAi != null) {
              widget.onSaveMedicationFromAi!(med);
            }
            break;
          case 'add_appointment':
            final apt = _appointmentFromAction(fields);
            if (apt != null && widget.onSaveAppointmentFromAi != null) {
              widget.onSaveAppointmentFromAi!(apt);
            }
            break;
          case 'delete_medication':
            final name = (fields['name'] ?? '').toString().trim();
            if (name.isNotEmpty &&
                widget.onDeleteMedicationFromAi != null) {
              widget.onDeleteMedicationFromAi!(name);
            }
            break;
          case 'update_medication':
            if (widget.onUpdateMedicationFromAi != null) {
              widget.onUpdateMedicationFromAi!(fields);
            }
            break;
          case 'delete_appointment':
            final title = (fields['title'] ?? '').toString().trim();
            final dateStr = (fields['date'] ?? '').toString().trim();
            final date = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;
            if (title.isNotEmpty &&
                widget.onDeleteAppointmentFromAi != null) {
              widget.onDeleteAppointmentFromAi!(title, date);
            }
            break;
          case 'update_appointment':
            if (widget.onUpdateAppointmentFromAi != null) {
              widget.onUpdateAppointmentFromAi!(fields);
            }
            break;
        }
      });
    }

    return stripped;
  }

  /// Build a Medication from the action's `fields` map. Returns null if the
  /// AI omitted the name (only required field client-side; everything else
  /// has a sensible default or is left empty for the user to fill later).
  Medication? _medicationFromAction(Map<String, dynamic> f) {
    final name = (f['name'] ?? '').toString().trim();
    if (name.isEmpty) return null;

    final isPrn = _asBool(f['prn']) || _asBool(f['isPrn']);
    final isLifetime = _asBool(f['lifetime']) || _asBool(f['isLifetime']);

    DateTime? parseDate(Object? v) {
      final s = (v ?? '').toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    List<MedScheduleEntry>? schedule;
    final rawSched = f['schedule'];
    if (rawSched is List && rawSched.isNotEmpty) {
      schedule = <MedScheduleEntry>[];
      for (final entry in rawSched) {
        if (entry is! Map) continue;
        final day = (entry['day'] ?? '').toString().trim();
        final times = entry['times'];
        if (day.isEmpty || times is! List) continue;
        schedule.add(MedScheduleEntry(
          day: day,
          times: times.map((t) => t.toString()).toList(),
        ));
      }
      if (schedule.isEmpty) schedule = null;
    }

    // Pull out the first scheduled time as the legacy single-time field —
    // some older display code reads `time` directly.
    String firstTime = '';
    if (schedule != null && schedule.isNotEmpty) {
      final t = schedule.first.times;
      if (t.isNotEmpty) firstTime = t.first;
    }

    // Default start date to today when the AI didn't supply one and this
    // isn't a PRN med (PRN has no schedule, no dates).
    DateTime? startDate = parseDate(f['startDate']);
    if (!isPrn && startDate == null) {
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, now.day);
    }

    return Medication(
      name: name,
      dosage: (f['dosage'] ?? '').toString(),
      frequency: (f['frequency'] ?? '').toString(),
      time: firstTime,
      purpose: (f['purpose'] ?? '').toString(),
      sideEffects: (f['sideEffects'] ?? '').toString(),
      schedule: isPrn ? null : schedule,
      startDate: isPrn ? null : startDate,
      endDate: isPrn ? null : parseDate(f['endDate']),
      isLifetime: isPrn ? false : isLifetime,
      isPrn: isPrn,
    );
  }

  /// Build an Appointment from the action's `fields` map. Returns null when
  /// the AI omitted the date — without a date we can't add a useful entry.
  Appointment? _appointmentFromAction(Map<String, dynamic> f) {
    final dateStr = (f['date'] ?? '').toString().trim();
    final fullDate = DateTime.tryParse(dateStr);
    if (fullDate == null) return null;
    return Appointment(
      date: fullDate.day,
      fullDate: fullDate,
      title: (f['title'] ?? '').toString(),
      time: (f['time'] ?? '').toString(),
      type: (f['type'] ?? '').toString(),
      location: (f['location'] ?? '').toString(),
    );
  }

  bool _asBool(Object? v) {
    if (v is bool) return v;
    final s = (v ?? '').toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).t('chat_ai_name'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(AppLocalizations.of(context).t('chat_header_subtitle'),
                            style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white),
                    tooltip: AppLocalizations.of(context).t('chat_history_tooltip'),
                    onPressed: _showHistorySheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_square, color: Colors.white),
                    tooltip: AppLocalizations.of(context).t('chat_new_session_tooltip'),
                    onPressed: _startNewSession,
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
            itemCount: _messages.length
                + (_isTyping ? 1 : 0)
                + (_isStreaming && !_isTyping ? 1 : 0)
                + (_messages.length == 1 ? 1 : 0),
            itemBuilder: (ctx, i) {
              // Quick actions row after first message
              if (_messages.length == 1 && i == 1) {
                return _buildQuickActions();
              }
              final msgIndex = _messages.length == 1 && i > 1 ? i - 1 : i;
              if (_isTyping && msgIndex == _messages.length) {
                return _buildTypingIndicator();
              }
              // After the last bot bubble, show the inline "generating..."
              // pill while tokens are still arriving.
              if (_isStreaming && !_isTyping && msgIndex == _messages.length) {
                return _buildGeneratingPill();
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
              if (_suggestions.isNotEmpty) _buildSuggestionStrip(),
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
                      tooltip: AppLocalizations.of(context).t('chat_attach_tooltip'),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        onSubmitted: _sendMessage,
                        onChanged: _onInputChanged,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: _attachment == null
                              ? AppLocalizations.of(context).t('chat_input_hint')
                              : AppLocalizations.of(context).t('chat_input_hint_attachment'),
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
                        icon: Icon(
                          _isStreaming ? Icons.stop_rounded : Icons.send_rounded,
                          // Stop button flips its icon based on the active
                          // theme so the square is visible against the blue
                          // background in both light and dark modes; the
                          // send icon stays plain white.
                          color: _isStreaming
                              ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white)
                              : Colors.white,
                          size: 20,
                        ),
                        tooltip: _isStreaming
                            ? AppLocalizations.of(context).t('chat_stop_tooltip')
                            : AppLocalizations.of(context).t('chat_send_tooltip'),
                        onPressed: _isStreaming ? _stopGeneration : _sendMessage,
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

  Widget _buildGeneratingPill() {
    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 0, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accent(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).t('chat_generating'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
      builder: (ctx) {
        final t = AppLocalizations.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetTile(Icons.camera_alt_outlined, t.t('chat_attach_take_photo'),
                  () async {
                Navigator.pop(ctx);
                await _pickFromCamera();
              }),
              _sheetTile(Icons.photo_library_outlined,
                  t.t('chat_attach_from_gallery'), () async {
                Navigator.pop(ctx);
                await _pickFromGallery();
              }),
              _sheetTile(Icons.attach_file_outlined, t.t('chat_attach_from_file'),
                  () async {
                Navigator.pop(ctx);
                await _pickFile();
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
      _showSnack(AppLocalizations.of(context)
          .t('chat_attach_camera_error', {'error': e.toString()}));
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
      _showSnack(AppLocalizations.of(context)
          .t('chat_attach_gallery_error', {'error': e.toString()}));
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
      _showSnack(AppLocalizations.of(context)
          .t('chat_attach_file_error', {'error': e.toString()}));
    }
  }

  void _setAttachment(Uint8List bytes, String name, String mimeType) {
    // Gemini inline_data is limited to ~20 MB. Bail out early on huge files.
    if (bytes.length > 15 * 1024 * 1024) {
      _showSnack(AppLocalizations.of(context).t('chat_attach_too_large'));
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

  /// Horizontal row of AI-suggested completions, shown above the input as
  /// chips. Tapping a chip sends that suggestion as the next user message.
  Widget _buildSuggestionStrip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final s = _suggestions[i];
          return GestureDetector(
            onTap: () {
              setState(() => _suggestions = const []);
              _suggestDebounce?.cancel();
              _sendMessage(s);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 14, color: AppColors.accent(context)),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary(context)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bottom-sheet list of all retained sessions (oldest first), letting the
  /// user jump back into a previous chat. The current session is highlighted.
  void _showHistorySheet() {
    final t = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // Show newest first so the most recent chats are at the top.
        final entries = List<int>.generate(_sessions.length, (i) => i)
          ..sort((a, b) =>
              _sessions[b].lastActivity.compareTo(_sessions[a].lastActivity));
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(t.t('chat_history_title'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context))),
              const SizedBox(height: 4),
              Text(t.t('chat_history_subtitle'),
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted(context))),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (lctx, i) {
                    final idx = entries[i];
                    final session = _sessions[idx];
                    final isCurrent = idx == _currentSessionIdx;
                    final preview = session.displayTitle();
                    return ListTile(
                      leading: Icon(
                        isCurrent ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                        color: isCurrent
                            ? AppColors.accent(context)
                            : AppColors.textMuted(context),
                      ),
                      title: Text(
                        preview.isNotEmpty
                            ? preview
                            : t.t('chat_history_empty_session'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textPrimary(context),
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500),
                      ),
                      subtitle: Text(
                        _formatRelative(session.lastActivity),
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted(context)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: AppColors.textMuted(context)),
                        tooltip: t.t('chat_history_delete_tooltip'),
                        onPressed: () =>
                            _confirmDeleteSession(ctx, idx),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _switchToSession(idx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Confirm + delete a chat session from the history sheet. If the user
  /// deletes the session they're currently in, we switch them to the most
  /// recent remaining one (or open a fresh empty session when none are left)
  /// so the screen doesn't end up in an inconsistent state.
  Future<void> _confirmDeleteSession(BuildContext sheetCtx, int idx) async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.t('chat_history_delete_title')),
        content: Text(t.t('chat_history_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(t.t('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: Text(t.t('common_delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final wasCurrent = idx == _currentSessionIdx;
    setState(() {
      _sessions.removeAt(idx);
      if (_sessions.isEmpty) {
        _sessions.add(_makeEmptySession());
        _currentSessionIdx = 0;
      } else if (wasCurrent) {
        // Jump to the last (most recent) remaining session.
        _currentSessionIdx = _sessions.length - 1;
      } else if (idx < _currentSessionIdx) {
        // Removing an entry before the current one shifts the index down.
        _currentSessionIdx -= 1;
      }
      _ensureBanner(_currentSession);
    });
    await _saveSessions();
    // Close the open sheet so the user sees the updated list with the row gone.
    if (mounted && Navigator.canPop(sheetCtx)) {
      Navigator.pop(sheetCtx);
    }
  }

  /// Cheap relative-time formatter for the history list ("2h ago", "Yesterday",
  /// "Mon"). Uses the message's local timestamp; we don't bother with i18n
  /// month names since the same row already shows the chat preview.
  String _formatRelative(DateTime dt) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return t.t('chat_history_just_now');
    if (diff.inMinutes < 60) {
      return t.t('chat_history_minutes_ago', {'n': diff.inMinutes.toString()});
    }
    if (diff.inHours < 24) {
      return t.t('chat_history_hours_ago', {'n': diff.inHours.toString()});
    }
    if (diff.inDays < 2) return t.t('chat_history_yesterday');
    return t.t('chat_history_days_ago', {'n': diff.inDays.toString()});
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).t('chat_quick_actions_header'), style: TextStyle(fontSize: 11, color: AppColors.textMuted(context), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _quickActions(context).map((action) => GestureDetector(
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

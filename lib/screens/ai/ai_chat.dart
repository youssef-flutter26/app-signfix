import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AI Chat with persistent history (like ChatGPT)
//  - Conversations saved to SharedPreferences
//  - Multiple sessions: new chat any time
//  - Swipe or tap to switch/delete past conversations
// ─────────────────────────────────────────────────────────────────────────────

class AiChat extends StatefulWidget {
  const AiChat({super.key, required this.api});
  final ApiClient api;
  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  // All conversations: each is a Map with 'id', 'title', 'messages', 'createdAt'
  List<Map<String, dynamic>> _conversations = [];
  int _activeIdx = 0; // index into _conversations
  bool _showHistory = false;
  bool _sending = false;

  final _input = TextEditingController();
  final _scrollCtrl = ScrollController();

  static const _prefsKey = 'ai_chat_history_v1';
  static const _greeting = {
    'role': 'ai',
    'text':
        'Hi! I\'m the SignFix AI Assistant 🤖\n\nI can help you with sign board types, pricing, materials, and service requests. What would you like to know?',
    'time': '',
  };

  static const _suggestions = [
    'What sign board types do you offer?',
    'How is the price calculated?',
    'How long does delivery take?',
    'How do I track my order?',
  ];

  List<Map<String, dynamic>> get _activeMessages => (_conversations.isNotEmpty)
      ? List<Map<String, dynamic>>.from(
          _conversations[_activeIdx]['messages'] as List)
      : [Map<String, dynamic>.from(_greeting)];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        setState(() {
          _conversations =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _activeIdx = 0;
        });
        return;
      } catch (_) {}
    }
    // First time — create default conversation
    _newChat(save: false);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_conversations));
  }

  // ── Chat management ──────────────────────────────────────────────────────────
  void _newChat({bool save = true}) {
    final now = DateTime.now();
    final conv = {
      'id': now.millisecondsSinceEpoch.toString(),
      'title': 'New Chat',
      'createdAt': now.toIso8601String(),
      'messages': [Map<String, dynamic>.from(_greeting)],
    };
    setState(() {
      _conversations.insert(0, conv);
      _activeIdx = 0;
      _showHistory = false;
    });
    if (save) _saveHistory();
  }

  void _switchChat(int idx) {
    setState(() {
      _activeIdx = idx;
      _showHistory = false;
    });
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _deleteChat(int idx) async {
    if (_conversations.length == 1) {
      // Can't delete last — reset it
      setState(() {
        _conversations[0] = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': 'New Chat',
          'createdAt': DateTime.now().toIso8601String(),
          'messages': [Map<String, dynamic>.from(_greeting)],
        };
      });
    } else {
      setState(() {
        _conversations.removeAt(idx);
        if (_activeIdx >= _conversations.length) {
          _activeIdx = _conversations.length - 1;
        }
      });
    }
    await _saveHistory();
  }

  void _addMessage(Map<String, dynamic> msg) {
    final msgs = List<Map<String, dynamic>>.from(
        _conversations[_activeIdx]['messages'] as List);
    msgs.add(msg);
    _conversations[_activeIdx]['messages'] = msgs;

    // Update title from first user message
    if (msg['role'] == 'you' &&
        (_conversations[_activeIdx]['title'] == 'New Chat')) {
      final txt = msg['text']?.toString() ?? '';
      _conversations[_activeIdx]['title'] =
          txt.length > 30 ? '${txt.substring(0, 30)}…' : txt;
    }
    _saveHistory();
  }

  // ── Send ─────────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final now = _timeNow();
    _input.clear();
    setState(() {
      _sending = true;
    });
    _addMessage({'role': 'you', 'text': text, 'time': now});
    setState(() {});
    _scrollToBottom();

    try {
      final result = await widget.api.chat(text);
      final reply = result['reply']?.toString() ??
          'I could not generate a response right now.';
      _addMessage({'role': 'ai', 'text': reply, 'time': _timeNow()});
    } catch (_) {
      _addMessage({
        'role': 'ai',
        'text': 'Support is unavailable right now. Please use the Service tab.',
        'time': _timeNow(),
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  String _timeNow() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_showHistory) return _buildHistoryPanel();
    return _buildChatScreen();
  }

  // ── Chat Screen ───────────────────────────────────────────────────────────────
  Widget _buildChatScreen() {
    final msgs = _activeMessages;
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(children: [
          // History button
          GestureDetector(
            onTap: () => setState(() => _showHistory = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.softGray,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: const Icon(Icons.history_rounded,
                  color: AppColors.gold, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('SignFix AI Assistant',
                    style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                Text(
                  _conversations.isNotEmpty
                      ? _conversations[_activeIdx]['title']?.toString() ??
                          'Chat'
                      : 'Chat',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ])),
          // New chat button
          GestureDetector(
            onTap: _newChat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: AppColors.gold, size: 16),
                SizedBox(width: 4),
                Text('New',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),

      // Messages
      Expanded(
        child: Container(
          color: AppColors.softGray,
          child: msgs.isEmpty
              ? const Center(
                  child: Text('Start a conversation',
                      style: TextStyle(color: AppColors.textMuted)))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) => _buildBubble(msgs[i]),
                ),
        ),
      ),

      // Suggestions (only first message + idle)
      if (msgs.length == 1 && !_sending)
        Container(
          color: AppColors.softGray,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: _suggestions
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            _input.text = s;
                            _send();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: .3)),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    color: AppColors.charcoal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),

      // Typing indicator
      if (_sending)
        Container(
          color: AppColors.softGray,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold)),
                SizedBox(width: 8),
                Text('AI is typing…',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              ]),
            ),
          ]),
        ),

      // Input
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                onSubmitted: (_) => _send(),
                textInputAction: TextInputAction.send,
                maxLines: 1,
                style: const TextStyle(color: AppColors.charcoal, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask about signs, pricing, service…',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: AppColors.gold.withValues(alpha: .5)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: _sending
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.gold, AppColors.goldDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _sending ? AppColors.softGray : null,
                  shape: BoxShape.circle,
                  boxShadow: _sending
                      ? []
                      : [BoxShadow(color: AppColors.gold.withValues(alpha: .3), blurRadius: 10)],
                ),
                child: Icon(Icons.send_rounded,
                    color: _sending ? AppColors.textMuted : AppColors.navyDeep,
                    size: 18),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ── Bubble ────────────────────────────────────────────────────────────────────
  Widget _buildBubble(Map<String, dynamic> m) {
    final isMe = m['role'] == 'you';
    final time = m['time']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.gold, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [AppColors.gold, AppColors.goldDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border:
                        isMe ? null : Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    m['text'] ?? '',
                    style: TextStyle(
                      color: isMe ? AppColors.navyDeep : AppColors.charcoal,
                      height: 1.45,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(time,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.softGray,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.navy, size: 14),
            ),
          ],
        ],
      ),
    );
  }

  // ── History Panel ─────────────────────────────────────────────────────────────
  Widget _buildHistoryPanel() => Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.white,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.gold, size: 18),
              onPressed: () => setState(() => _showHistory = false),
            ),
            const Expanded(
              child: Text('Chat History',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
            GestureDetector(
              onTap: _newChat,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: .3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: AppColors.gold, size: 16),
                  SizedBox(width: 4),
                  Text('New Chat',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),

        // List
        Expanded(
          child: Container(
            color: AppColors.softGray,
            child: _conversations.isEmpty
                ? const Center(
                    child: Text('No chat history yet.',
                        style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = _conversations[i];
                      final isActive = i == _activeIdx;
                      final msgs = (c['messages'] as List?) ?? [];
                      final preview = msgs.length > 1
                          ? msgs.last['text']?.toString() ?? ''
                          : 'No messages yet';
                      final date =
                          c['createdAt']?.toString().split('T').first ?? '';

                      return Dismissible(
                        key: Key(c['id']?.toString() ?? '$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.danger),
                        ),
                        onDismissed: (_) => _deleteChat(i),
                        child: GestureDetector(
                          onTap: () => _switchChat(i),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.softGray
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.gold.withValues(alpha: .4)
                                    : AppColors.cardBorder,
                                width: isActive ? 1.5 : 1,
                              ),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.gold.withValues(alpha: .15)
                                      : AppColors.softGray,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.chat_bubble_outline_rounded,
                                    color: isActive
                                        ? AppColors.gold
                                        : AppColors.textMuted,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                      c['title']?.toString() ?? 'Chat',
                                      style: TextStyle(
                                        color: isActive
                                            ? AppColors.navy
                                            : AppColors.textLight,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(preview,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    if (date.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(date,
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 10)),
                                    ],
                                  ])),
                              if (isActive)
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: AppColors.gold, size: 12),
                              if (!isActive)
                                GestureDetector(
                                  onTap: () => _deleteChat(i),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.delete_outline_rounded,
                                        color: AppColors.textMuted, size: 18),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]);
}

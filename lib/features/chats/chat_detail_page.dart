import 'package:flutter/material.dart';

import '../../core/theme/salo_theme.dart';
import '../../data/models/salo_user.dart';
import '../../data/repositories/salo_firebase_repository.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    required this.repository,
    required this.user,
    required this.chatId,
    required this.name,
    super.key,
  });

  final SaloFirebaseRepository repository;
  final SaloUser user;
  final String chatId;
  final String name;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = input.text.trim();
    final uid = widget.user.uid;
    if (text.isEmpty || sending || uid == null) return;
    setState(() => sending = true);
    input.clear();
    try {
      await widget.repository.sendMessage(
        widget.chatId,
        text,
        clientMessageId:
            'salo_${uid.substring(0, uid.length < 6 ? uid.length : 6)}_${DateTime.now().microsecondsSinceEpoch}',
      );
      _scrollBottom();
    } catch (_) {
      if (mounted) {
        input.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال الرسالة. حاول مجدداً.')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(widget.name), leading: const BackButton()),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.repository.watchMessages(widget.chatId, uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل الرسائل.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isNotEmpty) _scrollBottom();
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('ابدأ المحادثة برسالة جديدة.'),
                  );
                }
                return ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final sent = message['sent'] == true;
                    return Align(
                      alignment: sent
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: sent
                              ? SaloColors.cyan.withValues(alpha: .18)
                              : SaloColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sent ? SaloColors.cyan : SaloColors.border,
                          ),
                        ),
                        child: Text(
                          (message['text'] ?? 'رسالة مرفقة').toString(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

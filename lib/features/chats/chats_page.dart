import 'package:flutter/material.dart';

import '../../core/theme/salo_theme.dart';
import '../../data/models/salo_user.dart';
import '../../data/repositories/salo_firebase_repository.dart';
import 'chat_detail_page.dart';
import 'groups_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({required this.user, required this.repository, super.key});
  final SaloUser user;
  final SaloFirebaseRepository repository;

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  List<Map<String, dynamic>> conversations = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = widget.user.uid;
      if (uid == null || uid.isEmpty) throw StateError('Missing Firebase UID');
      final rows = await widget.repository.loadConversations(uid);
      if (mounted) setState(() => conversations = rows);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'تعذر تحميل المحادثات. تحقق من إعداد Firestore.',
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _startChat() async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('محادثة جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم المستخدم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.trim().isEmpty) return;
    try {
      final chatId = await widget.repository.startDirectChat(username);
      await _load();
      if (!mounted) return;
      final conversation = conversations.where(
        (item) => item['chatId'] == chatId,
      );
      final title = conversation.isEmpty
          ? username
          : (conversation.first['name'] ?? username).toString();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            repository: widget.repository,
            user: widget.user,
            chatId: chatId,
            name: title,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر بدء المحادثة. تحقق من اسم المستخدم.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    color: SaloColors.cyan,
    child: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'دردشتي',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'المجموعات',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupsPage(repository: widget.repository),
                ),
              ),
              icon: const Icon(Icons.groups_outlined, color: SaloColors.cyan),
            ),
            IconButton(
              tooltip: 'محادثة جديدة',
              onPressed: _startChat,
              icon: const Icon(
                Icons.add_comment_outlined,
                color: SaloColors.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'محادثاتك وقنواتك في مكان واحد',
          style: TextStyle(color: SaloColors.muted),
        ),
        const SizedBox(height: 18),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!loading && error != null)
          Card(
            color: SaloColors.card,
            child: ListTile(
              leading: const Icon(Icons.wifi_off, color: Colors.orange),
              title: Text(error!),
              trailing: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
        if (!loading && error == null && conversations.isEmpty)
          const _EmptyChats(),
        ...conversations.map(
          (chat) => _ChatTile(
            data: chat,
            user: widget.user,
            repository: widget.repository,
          ),
        ),
      ],
    ),
  );
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();
  @override
  Widget build(BuildContext context) => Card(
    color: SaloColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: SaloColors.border),
    ),
    child: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, color: SaloColors.cyan, size: 46),
          SizedBox(height: 10),
          Text('لا توجد محادثات بعد'),
          SizedBox(height: 5),
          Text(
            'ستظهر محادثاتك بعد إنشاء اتصال مع مستخدم آخر',
            style: TextStyle(color: SaloColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.data,
    required this.user,
    required this.repository,
  });
  final Map<String, dynamic> data;
  final SaloUser user;
  final SaloFirebaseRepository repository;

  @override
  Widget build(BuildContext context) {
    final title = (data['name'] ?? 'محادثة').toString();
    final preview = (data['lastMessage'] ?? 'لا توجد رسائل').toString();
    return Card(
      color: SaloColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: SaloColors.border),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              repository: repository,
              user: user,
              chatId: data['chatId'].toString(),
              name: title,
            ),
          ),
        ),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF0A5A7F),
          child: Icon(Icons.person, color: SaloColors.cyan),
        ),
        title: Text(title),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: SaloColors.muted),
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}

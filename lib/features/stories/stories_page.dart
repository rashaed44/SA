import 'package:flutter/material.dart';

import '../../core/theme/salo_theme.dart';
import '../../data/models/salo_user.dart';
import '../../data/repositories/salo_firebase_repository.dart';

class StoriesPage extends StatefulWidget {
  const StoriesPage({required this.user, required this.repository, super.key});
  final SaloUser user;
  final SaloFirebaseRepository repository;

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  List<Map<String, dynamic>> stories = [];
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
      final rows = await widget.repository.loadStories();
      if (mounted) setState(() => stories = rows);
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر تحميل الستوريات. تحقق من إعداد Firebase.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ستوري جديدة'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'اكتب ما تريد مشاركته...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('نشر'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;
    try {
      await widget.repository.createStory(text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم نشر الستوري')));
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر نشر الستوري')));
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await widget.repository.deleteStory(id);
      if (mounted)
        setState(() => stories.removeWhere((story) => story['id'] == id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر حذف الستوري')));
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
              'الستوري',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: _create,
              icon: const Icon(
                Icons.add_a_photo_outlined,
                color: SaloColors.cyan,
              ),
            ),
          ],
        ),
        const Text(
          'شارك لحظاتك مع أصدقائك',
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
            child: ListTile(
              title: Text(error!),
              trailing: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
        if (!loading && error == null && stories.isEmpty) const _EmptyStories(),
        ...stories.map((story) {
          final id = (story['id'] ?? '').toString();
          final canDelete = story['ownerUid'] == widget.user.uid;
          return _StoryCard(
            story: story,
            onDelete: canDelete ? () => _delete(id) : null,
          );
        }),
      ],
    ),
  );
}

class _EmptyStories extends StatelessWidget {
  const _EmptyStories();
  @override
  Widget build(BuildContext context) => const Card(
    color: SaloColors.card,
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.auto_awesome, color: SaloColors.cyan, size: 48),
          SizedBox(height: 10),
          Text('لا توجد ستوريات بعد'),
          SizedBox(height: 5),
          Text(
            'كن أول من يشارك قصة جديدة اليوم',
            style: TextStyle(color: SaloColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, required this.onDelete});
  final Map<String, dynamic> story;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    color: SaloColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: SaloColors.border),
    ),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF0A5A7F),
        child: Icon(Icons.auto_awesome, color: SaloColors.cyan),
      ),
      title: Text((story['text'] ?? 'ستوري').toString()),
      subtitle: Text(
        'مشاركة من ${(story['authorName'] ?? 'مجتمع SALO').toString()}',
        style: const TextStyle(color: SaloColors.muted),
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
    ),
  );
}

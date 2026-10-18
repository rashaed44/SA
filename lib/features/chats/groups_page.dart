import 'package:flutter/material.dart';

import '../../core/theme/salo_theme.dart';
import '../../data/repositories/salo_firebase_repository.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({required this.repository, super.key});
  final SaloFirebaseRepository repository;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  List<Map<String, dynamic>> groups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.loadGroups();
      if (mounted) setState(() => groups = rows);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر تحميل المجموعات.')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنشاء مجموعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'اسم المجموعة'),
            ),
            TextField(
              controller: description,
              maxLength: 280,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      try {
        await widget.repository.createGroup(
          name.text.trim(),
          description.text.trim(),
        );
        await _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تعذر إنشاء المجموعة.')));
        }
      }
    }
    name.dispose();
    description.dispose();
  }

  Future<void> _join(String id) async {
    try {
      await widget.repository.joinGroup(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الانضمام للمجموعة')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الانضمام للمجموعة.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('المجموعات'),
      actions: [IconButton(onPressed: _create, icon: const Icon(Icons.add))],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (groups.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('لا توجد مجموعات بعد'),
                    ),
                  ),
                ...groups.map(
                  (group) => Card(
                    color: SaloColors.card,
                    child: ListTile(
                      leading: const Icon(Icons.groups, color: SaloColors.cyan),
                      title: Text((group['name'] ?? 'مجموعة').toString()),
                      subtitle: Text(
                        (group['description'] ?? 'مجموعة عامة').toString(),
                      ),
                      trailing: TextButton(
                        onPressed: () => _join((group['id'] ?? '').toString()),
                        child: const Text('انضمام'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

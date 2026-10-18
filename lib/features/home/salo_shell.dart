import 'package:flutter/material.dart';

import '../../core/theme/salo_theme.dart';
import '../../data/models/salo_user.dart';
import '../../data/repositories/salo_firebase_repository.dart';
import '../chats/chats_page.dart';
import '../settings/settings_page.dart';
import '../stories/stories_page.dart';

class SaloShell extends StatefulWidget {
  const SaloShell({
    required this.user,
    required this.repository,
    required this.onLogout,
    super.key,
  });

  final SaloUser user;
  final SaloFirebaseRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<SaloShell> createState() => _SaloShellState();
}

class _SaloShellState extends State<SaloShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatsPage(user: widget.user, repository: widget.repository),
      StoriesPage(user: widget.user, repository: widget.repository),
      SettingsPage(
        user: widget.user,
        repository: widget.repository,
        onLogout: widget.onLogout,
      ),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.user.displayName.isEmpty ? 'SALO' : widget.user.displayName,
            style: const TextStyle(
              color: SaloColors.cyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'المحادثات',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'الستوري',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}

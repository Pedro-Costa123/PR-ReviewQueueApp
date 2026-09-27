import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme_controller.dart';
import '../queue/queue_repository.dart';

class WorkspaceShell extends StatelessWidget {
  const WorkspaceShell({
    super.key,
    required this.theme,
    required this.repository,
    required this.path,
    required this.child,
    this.teamId,
    this.connected = false,
  });
  final ThemeController theme;
  final QueueRepository repository;
  final String path;
  final String? teamId;
  final Widget child;
  final bool connected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'PR Review Queue',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: theme.mode == ThemeMode.dark
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              onPressed: theme.saving ? null : theme.toggle,
              icon: Icon(
                theme.mode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        drawer: wide || connected
            ? null
            : Drawer(
                child: SafeArea(child: _navigation(context, closeDrawer: true)),
              ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide && !connected)
              SizedBox(width: 240, child: _navigation(context)),
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: Text(
                      connected
                          ? 'PRIVATE WORKSPACE · Access is limited to your active teams.'
                          : 'READ-ONLY DEMO · These entries are fictional. Sign in with an invited account to add PRs, comment and review with your team.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (theme.warning != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        theme.warning!,
                        semanticsLabel: theme.warning,
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(path),
                      padding: EdgeInsets.all(wide ? 40 : 20),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _navigation(BuildContext context, {bool closeDrawer = false}) {
    final selectedTeam =
        repository.team(teamId ?? '')?.id ?? repository.teams.first.id;
    void navigate(String destination) {
      if (closeDrawer) Navigator.of(context).pop();
      context.go(destination);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'A place for progress',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Text(
            'DEMO WORKSPACE',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedTeam),
            initialValue: selectedTeam,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Demo team',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final team in repository.teams)
                DropdownMenuItem(value: team.id, child: Text(team.name)),
            ],
            onChanged: (value) {
              if (value != null) navigate('/teams/$value');
            },
          ),
          const SizedBox(height: 28),
          _NavItem(
            label: 'Review queue',
            icon: Icons.view_list_outlined,
            selected: path == '/teams/$selectedTeam',
            onTap: () => navigate('/teams/$selectedTeam'),
          ),
          const SizedBox(height: 8),
          _NavItem(
            label: 'Archive',
            icon: Icons.inventory_2_outlined,
            selected: path.endsWith('/archive'),
            onTap: () => navigate('/teams/$selectedTeam/archive'),
          ),
          const SizedBox(height: 8),
          _NavItem(
            label: 'Sign in',
            icon: Icons.login,
            selected: path == '/',
            onTap: () => navigate('/'),
          ),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            'Small queue.\nShared momentum.',
            style: TextStyle(fontWeight: FontWeight.w600, height: 1.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Review happens in your Git host. This space keeps the work visible.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    selected: selected,
    selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
    selectedColor: Theme.of(context).colorScheme.onPrimaryContainer,
    leading: Icon(icon, size: 20),
    title: Text(label, style: const TextStyle(fontSize: 14)),
    onTap: onTap,
  );
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets.dart';
import 'queue_repository.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key, required this.repository, required this.team});
  final QueueRepository repository;
  final DemoTeam team;
  @override
  Widget build(BuildContext context) {
    final entries = repository.entries(team.id);
    final sprint = entries.where((entry) => entry.sprintGoal).toList();
    final other = entries.where((entry) => !entry.sprintGoal).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: '${team.name} / workspace',
          title: 'Review queue',
          subtitle:
              'Make room for the next good idea. Start with the sprint goal.',
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              value: entries.length.toString().padLeft(2, '0'),
              label: 'Open entries',
              icon: Icons.account_tree_outlined,
            ),
            _Metric(
              value: sprint.length.toString().padLeft(2, '0'),
              label: 'Sprint goal',
              icon: Icons.flag_outlined,
            ),
            const _Metric(
              value: 'Manual',
              label: 'Status updates',
              icon: Icons.touch_app_outlined,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Ready for a fresh perspective',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Tag('Read-only demo'),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Sprint goal first, then priority. Sign in to manage your team’s queue.',
        ),
        const SizedBox(height: 24),
        if (entries.isEmpty)
          const SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inbox_outlined, size: 36),
                SizedBox(height: 16),
                Text('A little breathing room'),
                SizedBox(height: 8),
                Text(
                  'This fictional team has no entries yet. Sign in to add pull requests to your own team’s queue.',
                ),
              ],
            ),
          )
        else ...[
          _group(
            context,
            'Sprint goal',
            'Work that moves this sprint forward',
            sprint,
            1,
          ),
          const SizedBox(height: 28),
          _group(
            context,
            'Other work',
            'The rest of the team’s review queue',
            other,
            sprint.length + 1,
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Review signals and ages are fictional examples, not live activity or verified GitHub approvals.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    String subtitle,
    List<QueueEntry> entries,
    int start,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            title == 'Sprint goal'
                ? Icons.flag_outlined
                : Icons.layers_outlined,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(width: 8),
          Tag('${entries.length}'),
        ],
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 14),
      for (var i = 0; i < entries.length; i++) ...[
        _EntryCard(
          entry: entries[i],
          profile: repository.profile(entries[i].authorId)!,
          position: start + i,
          teamId: team.id,
        ),
        if (i < entries.length - 1) const SizedBox(height: 10),
      ],
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    child: SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.profile,
    required this.position,
    required this.teamId,
  });
  final QueueEntry entry;
  final DemoProfile profile;
  final int position;
  final String teamId;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              position.toString().padLeft(2, '0'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tag(entry.priority, accent: entry.priority == 'High'),
                  Text(
                    entry.reference,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () =>
                        context.go('/teams/$teamId/profiles/${profile.id}'),
                    child: Text(profile.name),
                  ),
                  Text(entry.age, style: Theme.of(context).textTheme.bodySmall),
                  _Signal(
                    Icons.check_circle_outline,
                    '${entry.looksGood} reviewed, looks good',
                  ),
                  _Signal(
                    Icons.close,
                    '${entry.commentsLeft} comments left on PR',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Signal extends StatelessWidget {
  const _Signal(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class DemoTeam {
  const DemoTeam(this.id, this.name);
  final String id;
  final String name;
}

class DemoProfile {
  const DemoProfile(this.id, this.name, this.username, this.initials);
  final String id;
  final String name;
  final String username;
  final String initials;
}

class QueueEntry {
  const QueueEntry({
    required this.title,
    required this.authorId,
    required this.reference,
    required this.priority,
    required this.sprintGoal,
    required this.age,
    this.looksGood = 0,
    this.commentsLeft = 0,
  });
  final String title;
  final String authorId;
  final String reference;
  final String priority;
  final bool sprintGoal;
  final String age;
  final int looksGood;
  final int commentsLeft;
}

abstract interface class QueueRepository {
  List<DemoTeam> get teams;
  DemoTeam? team(String id);
  DemoProfile? profile(String id);
  List<QueueEntry> entries(String teamId);
}

/// Public, read-only fixtures. No signed-in user or authentication bypass.
class DemoQueueRepository implements QueueRepository {
  const DemoQueueRepository();
  @override
  List<DemoTeam> get teams => const [
    DemoTeam('atlas', 'Atlas'),
    DemoTeam('orbit', 'Orbit'),
  ];
  static const _profiles = [
    DemoProfile('maya', 'Maya Chen', 'maya.demo', 'MC'),
    DemoProfile('leo', 'Leo Martins', 'leo.demo', 'LM'),
    DemoProfile('avery', 'Avery Park', 'avery.demo', 'AP'),
  ];
  @override
  DemoTeam? team(String id) {
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  @override
  DemoProfile? profile(String id) {
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  @override
  List<QueueEntry> entries(String teamId) => teamId == 'atlas'
      ? const [
          QueueEntry(
            title: 'Keep draft changes when a session expires',
            authorId: 'maya',
            reference: 'ATLAS-142',
            priority: 'High',
            sprintGoal: true,
            age: '2 hours ago',
            looksGood: 1,
            commentsLeft: 1,
          ),
          QueueEntry(
            title: 'Make workspace navigation keyboard friendly',
            authorId: 'leo',
            reference: 'ATLAS-138',
            priority: 'Normal',
            sprintGoal: true,
            age: '4 hours ago',
            looksGood: 2,
          ),
          QueueEntry(
            title: 'Clarify the empty state for new projects',
            authorId: 'avery',
            reference: 'ATLAS-129',
            priority: 'Normal',
            sprintGoal: true,
            age: 'Yesterday',
          ),
          QueueEntry(
            title: 'Simplify date formatting across the dashboard',
            authorId: 'maya',
            reference: 'ATLAS-121',
            priority: 'Normal',
            sprintGoal: false,
            age: 'Yesterday',
            commentsLeft: 1,
          ),
          QueueEntry(
            title: 'Refresh helper text in account settings',
            authorId: 'leo',
            reference: 'ATLAS-117',
            priority: 'Low',
            sprintGoal: false,
            age: '2 days ago',
            looksGood: 1,
          ),
        ]
      : const [];
}

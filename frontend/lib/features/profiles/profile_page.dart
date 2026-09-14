import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets.dart';
import '../queue/queue_repository.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.profile, required this.teamId});
  final DemoProfile profile;
  final String teamId;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        onPressed: () => context.go('/teams/$teamId'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to queue'),
      ),
      const SizedBox(height: 20),
      PageHeading(
        eyebrow: 'Fictional teammate',
        title: profile.name,
        subtitle: '@${profile.username}',
      ),
      const SizedBox(height: 28),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 28, child: Text(profile.initials)),
            const SizedBox(height: 20),
            const Text('A face behind the feedback'),
            const SizedBox(height: 10),
            const Text(
              'This profile is presentation data only. Profile editing, email visibility, and team permissions will be implemented after authentication.',
            ),
          ],
        ),
      ),
    ],
  );
}

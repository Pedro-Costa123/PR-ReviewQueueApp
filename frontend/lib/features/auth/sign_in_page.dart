import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            eyebrow: 'A little order. A better review.',
            title: 'Good work deserves\na second pair of eyes.',
            subtitle: 'A shared place for your team’s pull requests. Keep sprint work visible and know what needs a review.',
          ),
          const SizedBox(height: 32),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 32),
                const SizedBox(height: 20),
                Text(
                  'Your team, by invitation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Work-email magic links are planned. Sign-in is not connected and this preview does not collect email addresses.',
                ),
                const SizedBox(height: 24),
                const FilledButton(
                  onPressed: null,
                  child: Text('Magic-link sign-in · coming later'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.go('/teams/atlas'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Explore the demo queue'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Fictional people and entries. No account or authentication session is created.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

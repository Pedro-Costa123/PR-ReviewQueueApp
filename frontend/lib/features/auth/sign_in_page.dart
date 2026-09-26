import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets.dart';
import 'auth_controller.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, this.auth});
  final AuthController? auth;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    widget.auth?.cancelChallenge?.call();
    _email.dispose();
    super.dispose();
  }

  void _request() {
    if (_form.currentState!.validate()) widget.auth!.requestLink(_email.text);
  }

  Widget _authForm(AuthController auth) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.hasPendingLink) ...[
            const Text(
              'Continue only if you requested this sign-in link. Opening the link alone does not sign you in.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: auth.busy ? null : auth.confirmLink,
              child: const Text('Continue sign-in'),
            ),
            TextButton(
              onPressed: auth.busy ? null : auth.cancelLink,
              child: const Text('Cancel sign-in'),
            ),
          ] else if (auth.email != null) ...[
            Text('Signed in as ${auth.email}'),
            const SizedBox(height: 12),
            const Text(
              'Your session is kept in open app tabs and survives reload. The demo queue is still fictional.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: auth.busy ? null : auth.signOut,
              child: const Text('Sign out'),
            ),
          ] else ...[
            Text(
              auth.production
                  ? 'Use your invited work email. Complete verification when prompted to request your sign-in link.'
                  : auth.hostedTrial
                  ? 'Developer sign-in trial. Use an invited trial email. Complete verification when prompted to request your link.'
                  : 'Local authentication preview. Use a provisioned @example.test address; links appear in the local inbox.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              enabled: !auth.busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Work email',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid email address.',
              onFieldSubmitted: (_) {
                if (!auth.busy) _request();
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: auth.busy ? null : _request,
              child: const Text('Send sign-in link'),
            ),
          ],
          if (auth.busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(semanticsLabel: 'Signing in'),
          ],
          if (auth.message != null) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(auth.message!)),
          ],
        ],
      ),
    ),
  );
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
                if (widget.auth == null)
                  const Text(
                    'Work-email magic links are planned. Sign-in is not connected and this preview does not collect email addresses.',
                  ),
                const SizedBox(height: 24),
                if (widget.auth == null)
                  const FilledButton(
                    onPressed: null,
                    child: Text('Magic-link sign-in · coming later'),
                  ),
                if (widget.auth != null) _authForm(widget.auth!),
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
          Text(
            widget.auth == null
                ? 'Fictional people and entries. No account or authentication session is created.'
                : widget.auth!.production
                ? 'Sign in to open your teams and profile.'
                : widget.auth!.hostedTrial
                ? 'Controlled developer trial. Sign in to open your teams and profile.'
                : 'Local mail only. Sign in to open your teams and profile.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

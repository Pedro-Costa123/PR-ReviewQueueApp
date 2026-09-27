import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets.dart';
import '../queue/entry_repository.dart';
import '../queue/entry_queue.dart';
import 'onboarding_repository.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.repository,
    required this.signOut,
    this.entries,
  });
  final OnboardingRepository repository;
  final Future<void> Function() signOut;
  final EntryRepository? entries;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  List<RecordData> _teams = [], _members = [], _invites = [];
  RecordData? _me;
  String? _teamId, _message;
  bool _busy = true;
  bool _profileLoading = false;
  int _generation = 0;
  bool get _admin =>
      _teams.any((t) => t['id'] == _teamId && t['role'] == 'admin');

  @override
  void initState() {
    super.initState();
    _load(claim: true);
  }

  Future<void> _load({bool claim = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _members = [];
      _invites = [];
    });
    try {
      if (claim) await widget.repository.claimInvites();
      final me = await widget.repository.profile(widget.repository.userId);
      final teams = await widget.repository.teams();
      final selected = teams.any((t) => t['id'] == _teamId)
          ? _teamId
          : teams.firstOrNull?['id'] as String?;
      final members = selected == null
          ? <RecordData>[]
          : await widget.repository.members(selected);
      final admin = teams.any(
        (t) => t['id'] == selected && t['role'] == 'admin',
      );
      final invites = admin
          ? await widget.repository.invites(selected!)
          : <RecordData>[];
      if (!mounted || generation != _generation) return;
      setState(() {
        _me = me;
        _teams = teams;
        _teamId = selected;
        _members = members;
        _invites = invites;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _teams = [];
        _teamId = null;
        _me = null;
        _message = 'Could not load your teams. Refresh or sign in again if your access changed.';
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _act(Future<void> Function() operation, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
      if (mounted) setState(() => _message = success);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _message = error.code == '23505'
              ? 'That username is unavailable. Choose another.'
              : error.code == '23514'
              ? 'A team must keep at least one active admin. Check the entered values.'
              : 'Change could not be saved. Check your access and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'The request did not complete. The invitation may be saved; refresh and use Resend / retry after a minute.',
        );
      }
    }
    if (mounted) await _load();
  }

  Future<void> _refreshPeople() async {
    final generation = _generation;
    final team = _teamId;
    if (team == null || _busy) return;
    final teams = await widget.repository.teams();
    final selected = teams.where((t) => t['id'] == team).firstOrNull;
    final members = selected == null
        ? <RecordData>[]
        : await widget.repository.members(team);
    final invites = selected?['role'] == 'admin'
        ? await widget.repository.invites(team)
        : <RecordData>[];
    if (!mounted || generation != _generation || team != _teamId) return;
    setState(() {
      _teams = teams;
      _members = members;
      _invites = invites;
      if (selected == null) _teamId = null;
    });
  }

  Future<void> _editProfile() async {
    final value = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ProfileEditor(
        name: _me?['name'] as String? ?? '',
        username: _me?['username'] as String? ?? '',
      ),
    );
    if (value != null && mounted) {
      await _act(
        () => widget.repository.saveProfile(value[0], value[1]),
        'Profile saved.',
      );
    }
  }

  Future<void> _invite() async {
    final value = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _InviteEditor(),
    );
    if (value != null && mounted) {
      final team = _teamId!;
      await _act(
        () => widget.repository.invite(team, value[0], value[1]),
        'Invitation saved and link requested. Delivery can take a moment; check Junk too.',
      );
    }
  }

  Future<void> _confirm(String title, Future<void> Function() operation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('This changes access to the selected team.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _act(operation, 'Team access updated.');
    }
  }

  Future<void> _viewProfile(String id) async {
    if (_profileLoading) return;
    _profileLoading = true;
    final generation = _generation;
    try {
      final profile = await widget.repository
          .profile(id)
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(profile['name'] as String? ?? 'Profile not completed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${profile['username'] ?? 'not-set'}'),
              const SizedBox(height: 12),
              Semantics(
                label: 'Email: ${profile['email']}',
                child: ExcludeSemantics(
                  child: SelectableText(profile['email'] as String),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'This profile is no longer available.');
      }
    } finally {
      _profileLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageHeading(
        eyebrow: 'Your workspace',
        title: 'Teams & people',
        subtitle: 'Manage your profile and the teams you belong to.',
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () {
                    _message = null;
                    _load(claim: true);
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh teams'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : widget.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(semanticsLabel: 'Loading workspace'),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Semantics(liveRegion: true, child: Text(_message!)),
        ),
      if (_me != null) ...[
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _me!['name'] as String? ?? 'Complete your profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_me!['email'] as String),
              if (_me!['username'] != null) Text('@${_me!['username']}'),
              const SizedBox(height: 12),
              const Text(
                'Your name, username and email are visible to your active teammates.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _editProfile,
                child: Text(
                  _me!['name'] == null ? 'Complete profile' : 'Edit profile',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_teams.isEmpty && !_busy)
          const Text(
            'No active teams yet. Ask a team admin for an invitation, then refresh.',
          ),
        if (_teams.isNotEmpty && _me!['name'] != null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('team-selector-$_teamId'),
            initialValue: _teamId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Your team',
              border: OutlineInputBorder(),
            ),
            items: _teams
                .map(
                  (t) => DropdownMenuItem(
                    value: t['id'] as String,
                    child: Text(t['name'] as String),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) {
                    _teamId = value;
                    _message = null;
                    _load();
                  },
          ),
          const SizedBox(height: 16),
          if (widget.entries != null && !_busy)
            EntryQueue(
              key: ValueKey('team-queue-$_teamId'),
              repository: widget.entries!,
              teamId: _teamId!,
              admin: _admin,
              members: _members,
              viewProfile: _viewProfile,
              refreshPeople: _refreshPeople,
            ),
          const SizedBox(height: 24),
          Text('Members', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final member in _members)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (member['active'] == true)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _viewProfile(member['user_id'] as String),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${member['name'] ?? member['email']}${member['user_id'] == widget.repository.userId ? ' (you)' : ''}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${member['role']} · Active',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Text('Removed member · ${member['user_id']}'),
                      const SizedBox(height: 4),
                      Text('${member['role']} · Removed'),
                    ],
                    if (_admin) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          if (member['active'] == true)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () {
                                      final role = member['role'] == 'admin'
                                          ? 'member'
                                          : 'admin';
                                      _confirm(
                                        'Change role to $role?',
                                        () => widget.repository.setAccess(
                                          _teamId!,
                                          member['user_id'] as String,
                                          role,
                                          true,
                                        ),
                                      );
                                    },
                              child: Text(
                                member['role'] == 'admin'
                                    ? 'Make member'
                                    : 'Make admin',
                              ),
                            ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _confirm(
                                    member['active'] == true
                                        ? 'Remove member?'
                                        : 'Restore member?',
                                    () => widget.repository.setAccess(
                                      _teamId!,
                                      member['user_id'] as String,
                                      member['role'] as String,
                                      member['active'] != true,
                                    ),
                                  ),
                            child: Text(
                              member['active'] == true ? 'Remove' : 'Restore',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_admin) ...[
            const SizedBox(height: 16),
            Text('Invitations', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy ? null : _invite,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Invite teammate'),
              ),
            ),
            const SizedBox(height: 12),
            if (_invites.isEmpty) const Text('No pending invitations.'),
            for (final invitation in _invites)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation['email'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${invitation['role']} · ${invitation['provisioning_state']}',
                      ),
                      Text(
                        'Expires ${DateTime.parse(invitation['expires_at'] as String).toLocal().toString().split('.').first}',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _act(
                                    () => widget.repository.invite(
                                      _teamId!,
                                      invitation['email'] as String,
                                      invitation['role'] as String,
                                    ),
                                    'Invitation saved and link requested. Check Junk too.',
                                  ),
                            child: const Text('Resend / retry'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _confirm(
                                    'Revoke invitation?',
                                    () => widget.repository.revoke(
                                      invitation['id'] as String,
                                    ),
                                  ),
                            child: const Text('Revoke'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (_members.length == 100 ||
              _invites.length == 100 ||
              _teams.length == 100)
            const Text(
              'Showing the first 100 records. Contact the operator for larger teams.',
            ),
        ],
      ],
    ],
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.name, required this.username});
  final String name, username;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.name);
  late final username = TextEditingController(text: widget.username);
  @override
  void dispose() {
    name.dispose();
    username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Your profile'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter your name.' : null,
            ),
            TextFormField(
              controller: username,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Username',
                helperText: '3–40 letters, numbers, dots, _ or -',
                helperMaxLines: 2,
              ),
              validator: (value) =>
                  RegExp(r'^[a-z0-9][a-z0-9_.-]{2,39}$')
                      .hasMatch(value?.trim().toLowerCase() ?? '')
                  ? null
                  : 'Enter a valid username.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, [name.text, username.text]);
          }
        },
        child: const Text('Save profile'),
      ),
    ],
  );
}

class _InviteEditor extends StatefulWidget {
  const _InviteEditor();
  @override
  State<_InviteEditor> createState() => _InviteEditorState();
}

class _InviteEditorState extends State<_InviteEditor> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  String role = 'member';
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invite teammate'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Invite an exact work email. Invitations expire in 7 days. Existing invitations keep their role and expiry; revoke first to change the role.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              maxLength: 254,
              decoration: const InputDecoration(labelText: 'Work email'),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid work email.',
            ),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Team role'),
              items: const [
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) => role = value!,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, [email.text, role]);
          }
        },
        child: const Text('Invite & send link'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets.dart';
import 'entry_repository.dart';
import 'entry_activity.dart';
import 'open_link.dart';

String entryError(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      'PT409' => 'This entry changed. Your draft is kept here. Close and refresh the queue to review the latest version before editing again.',
      '23505' => 'This PR is already in this team’s active queue.',
      'PT429' => 'Too many changes. Wait a minute before trying again.',
      '22023' => 'Check the title, priority and allowed enterprise links.',
      '42501' => 'Your access changed or this entry is no longer available. Refresh the queue.',
      _ => 'Could not save. Refresh to check whether the change completed before retrying.',
    };
  }
  return 'The request did not complete. Your draft is kept. Refresh to check whether the change saved before retrying.';
}

class EntryQueue extends StatefulWidget {
  const EntryQueue({
    super.key,
    required this.repository,
    required this.teamId,
    required this.admin,
    required this.members,
    required this.viewProfile,
  });
  final EntryRepository repository;
  final String teamId;
  final bool admin;
  final List<EntryData> members;
  final void Function(String) viewProfile;
  @override
  State<EntryQueue> createState() => _EntryQueueState();
}

class _EntryQueueState extends State<EntryQueue> {
  List<EntryData> _entries = [];
  LinkHosts _hosts = const LinkHosts(pr: [], jira: []);
  bool _busy = true;
  bool _hasMore = false;
  int _revision = 0;
  final Map<String, FocusNode> _moveFocus = {};
  String? _message;
  int _generation = 0;
  @override
  void dispose() {
    for (final node in _moveFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EntryQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _entries = [];
      _hasMore = false;
      _message = null;
    });
    try {
      final hosts = await widget.repository.hosts(widget.teamId);
      final entries = await widget.repository.list(widget.teamId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _hosts = hosts;
        _entries = entries.entries;
        _revision = entries.revision;
        _hasMore = entries.hasMore;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _hosts = const LinkHosts(pr: [], jira: []);
        _message = 'Could not load the queue. Check your connection or team access, then refresh.';
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _move(List<EntryData> group, int from, int to) async {
    if (_busy || !widget.admin || from == to) return;
    final generation = _generation;
    final team = widget.teamId;
    final id = group[from]['id'] as String;
    setState(() {
      _busy = true;
      _message = null;
    });
    String message;
    try {
      await widget.repository.move(
        team,
        id,
        group[to]['id'] as String,
        after: to > from,
        revision: _revision,
      );
      message = 'Order saved.';
    } catch (error) {
      message = error is PostgrestException && error.code == 'PT409'
          ? 'The queue changed. Your move was not applied. Review the refreshed order before moving again.'
          : error is PostgrestException && error.code == '42501'
          ? 'You can no longer reorder this queue. Refresh your teams to check access.'
          : error is PostgrestException && error.code == 'PT429'
          ? 'Too many changes. Wait a minute before moving again.'
          : 'Could not confirm the move. Check the refreshed order before trying again.';
    }
    if (!mounted || generation != _generation) return;
    await _load();
    if (!mounted || widget.teamId != team) return;
    setState(
      () => _message = _message == null ? message : '$message $_message',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.teamId == team) _moveFocus[id]?.requestFocus();
    });
  }

  Widget _group(BuildContext context, bool sprint, String priority) {
    final entries = _entries
        .where((e) => e['sprint_goal'] == sprint && e['priority'] == priority)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final label =
        '${sprint ? 'Sprint goal' : 'Other work'} · ${priority[0].toUpperCase()}${priority.substring(1)}';
    Widget item(int index) {
      final entry = entries[index];
      final id = entry['id'] as String;
      final focus = _moveFocus.putIfAbsent(id, FocusNode.new);
      final card = Padding(
        key: ValueKey(id),
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.admin)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Draggable<String>(
                    data: id,
                    maxSimultaneousDrags: !_busy && entries.length > 1 ? 1 : 0,
                    feedback: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Move ${entry['title']}'),
                      ),
                    ),
                    child: Tooltip(
                      message: 'Drag ${entry['title']} within $label',
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Move ${entry['title']} up within $label',
                    child: TextButton.icon(
                      focusNode: index > 0 ? focus : null,
                      onPressed: _busy || index == 0
                          ? null
                          : () => _move(entries, index, index - 1),
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      label: const Text('Move up'),
                    ),
                  ),
                  Semantics(
                    label: 'Move ${entry['title']} down within $label',
                    child: TextButton.icon(
                      focusNode: index == 0 ? focus : null,
                      onPressed: _busy || index == entries.length - 1
                          ? null
                          : () => _move(entries, index, index + 1),
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: const Text('Move down'),
                    ),
                  ),
                ],
              ),
            _card(context, entry),
          ],
        ),
      );
      if (!widget.admin) return card;
      return DragTarget<String>(
        key: ValueKey('drop-$id'),
        onWillAcceptWithDetails: (details) =>
            !_busy &&
            details.data != id &&
            entries.any((e) => e['id'] == details.data),
        onAcceptWithDetails: (details) => _move(
          entries,
          entries.indexWhere((e) => e['id'] == details.data),
          index,
        ),
        builder: (context, candidates, rejected) => DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: candidates.isEmpty
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.primary,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: card,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(label, style: Theme.of(context).textTheme.titleLarge),
        ),
        for (var index = 0; index < entries.length; index++) item(index),
      ],
    );
  }

  Future<void> _edit([EntryData? entry]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EntryEditor(
        repository: widget.repository,
        teamId: widget.teamId,
        hosts: _hosts,
        entry: entry,
      ),
    );
    if (saved == true && mounted) {
      await _load();
      if (mounted && _message == null) {
        setState(() => _message = 'Entry saved.');
      }
    }
  }

  Future<void> _delete(EntryData entry) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          '“${entry['title']}” will be hidden from this team’s queue. The PR and Jira issue are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete entry'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    String result;
    try {
      await widget.repository.delete(widget.teamId, entry);
      result = 'Entry deleted.';
    } catch (error) {
      result = entryError(
        error,
      ).replaceFirst('Your draft is kept here. Close and refresh', 'Refresh');
    }
    if (!mounted) return;
    await _load();
    if (mounted) setState(() => _message = result);
  }

  Widget _link(String label, String url, String kind) {
    final normalized = normalizeEnterpriseLink(
      url,
      kind == 'pr' ? _hosts.pr : _hosts.jira,
      kind,
    );
    return TextButton.icon(
      onPressed: normalized == null
          ? null
          : () => openEnterpriseLink(normalized),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text('$label ↗'),
      // The label communicates the new tab without displaying private URL text.
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Review queue', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'Manually maintained · Links open in a new tab. Review happens in GitHub.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _busy || !_hosts.configured ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add entry'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh queue'),
          ),
        ],
      ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(semanticsLabel: 'Loading queue'),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(liveRegion: true, child: Text(_message!)),
        ),
      if (!_busy && !_hosts.configured && _message == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Enterprise link hosts are not configured. Ask the deployment operator to configure this team.',
          ),
        ),
      if (!_busy && _entries.isEmpty && _message == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('No entries yet. Add a PR to start the queue.'),
        ),
      if (widget.admin && _entries.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Drag the handle or use Move up / Move down within a group. Sprint goals come first, then Critical, High, Medium and Low.',
          ),
        ),
      for (final sprint in [true, false])
        for (final priority in ['critical', 'high', 'medium', 'low'])
          _group(context, sprint, priority),
      if (_hasMore)
        const Text(
          'Showing the first 100 active entries in queue order. Moves are limited to visible entries in each group.',
        ),
    ],
  );
  Widget _card(BuildContext context, EntryData entry) {
    final editable =
        widget.admin || entry['submitter_id'] == widget.repository.userId;
    final member = widget.members
        .where(
          (m) => m['user_id'] == entry['submitter_id'] && m['active'] == true,
        )
        .firstOrNull;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('${entry['priority']}'.toUpperCase()),
              if (entry['sprint_goal'] == true)
                const Tag('Sprint goal', accent: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry['title'] as String,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (member != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => widget.viewProfile(entry['submitter_id'] as String),
              child: Text(member['name'] as String? ?? 'Teammate'),
            )
          else
            const Text('Submitted by a former teammate'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _link('Open PR', entry['pr_url'] as String, 'pr'),
              _link('Open Jira', entry['jira_url'] as String, 'jira'),
              if (editable) ...[
                TextButton(
                  onPressed: _busy || !_hosts.configured
                      ? null
                      : () => _edit(entry),
                  child: const Text('Edit entry'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _delete(entry),
                  child: const Text('Delete entry'),
                ),
              ],
            ],
          ),
          EntryActivity(
            key: ValueKey('activity-${entry['id']}'),
            repository: widget.repository,
            teamId: widget.teamId,
            entryId: entry['id'] as String,
            admin: widget.admin,
            members: widget.members,
            viewProfile: widget.viewProfile,
          ),
        ],
      ),
    );
  }
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.repository,
    required this.teamId,
    required this.hosts,
    this.entry,
  });
  final EntryRepository repository;
  final String teamId;
  final LinkHosts hosts;
  final EntryData? entry;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.entry?['title'] as String? ?? '',
  );
  late final _pr = TextEditingController(
    text: widget.entry?['pr_url'] as String? ?? '',
  );
  late final _jira = TextEditingController(
    text: widget.entry?['jira_url'] as String? ?? '',
  );
  late bool _sprint = widget.entry?['sprint_goal'] as bool? ?? false;
  late String _priority = widget.entry?['priority'] as String? ?? 'medium';
  bool _saving = false, _conflict = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _pr.dispose();
    _jira.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _conflict || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(widget.teamId, {
        'title': _title.text.trim(),
        'pr_url': normalizeEnterpriseLink(_pr.text, widget.hosts.pr, 'pr'),
        'jira_url': normalizeEnterpriseLink(
          _jira.text,
          widget.hosts.jira,
          'jira',
        ),
        'sprint_goal': _sprint,
        'priority': _priority,
      }, original: widget.entry);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = entryError(error);
          _conflict = error is PostgrestException && error.code == 'PT409';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.entry == null ? 'Add entry' : 'Edit entry'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      value == null ||
                          value.trim().isEmpty ||
                          value.trim().runes.length > 160 ||
                          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)
                      ? 'Enter a title of 1–160 characters.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pr,
                  enabled: !_saving,
                  maxLength: 2048,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'PR link',
                    helperText: 'HTTPS · ${widget.hosts.pr.join(', ')}',
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                    counterText: '',
                  ),
                  validator: (value) =>
                      normalizeEnterpriseLink(
                            value ?? '',
                            widget.hosts.pr,
                            'pr',
                          ) ==
                          null
                      ? 'Use an allowed GitHub /owner/repository/pull/123 link.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _jira,
                  enabled: !_saving,
                  maxLength: 2048,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Jira link',
                    helperText: 'HTTPS · ${widget.hosts.jira.join(', ')}',
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                    counterText: '',
                  ),
                  validator: (value) =>
                      normalizeEnterpriseLink(
                            value ?? '',
                            widget.hosts.jira,
                            'jira',
                          ) ==
                          null
                      ? 'Use an allowed Jira /browse/PROJECT-123 link.'
                      : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Links are saved as resource URLs without query parameters or fragments.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(
                      value: 'critical',
                      child: Text('Critical'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _priority = value!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sprint goal'),
                  value: _sprint,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _sprint = value!),
                ),
                if (widget.entry != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Changing the PR link clears all review signals. Comments are kept.',
                    ),
                  ),
                if (_error != null)
                  Semantics(liveRegion: true, child: SelectableText(_error!)),
                if (_saving)
                  const LinearProgressIndicator(semanticsLabel: 'Saving entry'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _conflict ? null : _save,
          child: const Text('Save entry'),
        ),
      ],
    ),
  );
}

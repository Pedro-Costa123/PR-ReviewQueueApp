import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets.dart';
import 'entry_repository.dart';
import 'entry_activity.dart';
import 'open_link.dart';
import 'visible_refresh.dart';

const archiveReasons = {
  'merged': 'Merged',
  'closed': 'Closed',
  'no_longer_needed': 'No longer needed',
  'other': 'Other',
};

String entryError(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      'PT409' => 'This entry changed. Your draft is kept here. Close and refresh the queue to review the latest version before editing again.',
      '23505' => 'This PR is already in this team’s active queue.',
      'PT422' => 'This PR is archived. Open Archive and ask its submitter or a team admin to restore it.',
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
    this.refreshPeople,
  });
  final EntryRepository repository;
  final String teamId;
  final bool admin;
  final List<EntryData> members;
  final void Function(String) viewProfile;
  final Future<void> Function()? refreshPeople;
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
  String _view = 'active';
  int _offset = 0;
  int? _dataRevision;
  final _search = TextEditingController();
  String _query = '';
  String? _priority, _submitter;
  bool? _sprint;
  String? _appliedPriority, _appliedSubmitter;
  bool? _appliedSprint;
  DateTime? _updated, _checked;
  late final VisibleRefresh _refresh;
  bool _checking = false;
  final Set<String> _interacting = {};
  bool get _filtered =>
      _query.isNotEmpty ||
      _appliedPriority != null ||
      _appliedSprint != null ||
      _appliedSubmitter != null;
  final _viewFocus = FocusNode();
  final _pageFocus = FocusNode();
  @override
  void dispose() {
    _refresh.dispose();
    _search.dispose();
    _viewFocus.dispose();
    _pageFocus.dispose();
    for (final node in _moveFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refresh = VisibleRefresh(_checkRevision);
    _load();
  }

  @override
  void didUpdateWidget(EntryQueue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.repository != widget.repository) {
      _view = 'active';
      _offset = 0;
      _dataRevision = null;
      _search.clear();
      _query = '';
      _priority = _submitter = null;
      _sprint = null;
      _appliedPriority = _appliedSubmitter = null;
      _appliedSprint = null;
      _interacting.clear();
      _updated = _checked = null;
      _refresh.reset();
      _load();
    } else if (oldWidget.admin && !widget.admin && _view == 'deleted') {
      _selectView('active');
    }
  }

  Future<void> _checkRevision() async {
    if (_busy || _checking || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final generation = _generation;
    _checking = true;
    try {
      final revision = await widget.repository
          .dataRevision(widget.teamId)
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) return;
      setState(() => _checked = DateTime.now());
      if (revision != _dataRevision) {
        if (_interacting.isNotEmpty) {
          setState(
            () => _message = 'Updates available. Finish or clear your comment draft, then refresh.',
          );
          return;
        }
        await widget.refreshPeople?.call().timeout(const Duration(seconds: 15));
        if (!mounted || generation != _generation) return;
        _offset = 0;
        await _load(background: true);
      }
    } catch (error) {
      if (mounted && generation == _generation) _readFailed(error);
      rethrow;
    } finally {
      _checking = false;
    }
  }

  void _readFailed(Object error) {
    setState(() {
      _message = readError(error);
      if (readAccessError(error)) {
        _entries = [];
        _interacting.clear();
        _hosts = const LinkHosts(pr: [], jira: []);
        _dataRevision = null;
      }
    });
    if (readAccessError(error) || readQuotaError(error)) _refresh.pause();
  }

  Future<void> _load({bool background = false, bool paging = false}) async {
    final generation = ++_generation;
    if (!paging) _offset = 0;
    setState(() {
      _busy = !background;
      if (!background) {
        _entries = [];
        _interacting.clear();
      }
      if (!background) _hasMore = false;
      _message = null;
    });
    try {
      final hosts = await widget.repository
          .hosts(widget.teamId)
          .timeout(const Duration(seconds: 15));
      final page = await widget.repository
          .page(
            widget.teamId,
            view: _view,
            search: _query,
            priority: _appliedPriority,
            sprint: _appliedSprint,
            submitter: _appliedSubmitter,
            offset: _offset,
            revision: paging ? _dataRevision : null,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) return;
      setState(() {
        _hosts = hosts;
        _entries = List<EntryData>.from(page['entries']);
        _revision = page['revision'] as int? ?? 0;
        _dataRevision = page['data_revision'] as int? ?? 0;
        _hasMore = page['has_more'] as bool;
        _updated = _checked = DateTime.now();
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _readFailed(error);
      if (background) rethrow;
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _selectView(String view) async {
    if (_interacting.isNotEmpty) {
      setState(
        () => _message =
            'Finish or clear your comment draft before changing the list.',
      );
      return;
    }
    _view = view;
    _offset = 0;
    _refresh.reset();
    await _loadAndFocus(_viewFocus);
  }

  Future<void> _loadAndFocus(FocusNode node) async {
    final team = widget.teamId;
    await _load(paging: node == _pageFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && team == widget.teamId) node.requestFocus();
    });
  }

  Future<void> _changeLifecycle(EntryData entry, String action) async {
    if (_interacting.isNotEmpty) {
      setState(
        () => _message =
            'Finish or clear your comment draft before changing the list.',
      );
      return;
    }
    final team = widget.teamId;
    final generation = _generation;
    final label = switch (action) {
      'archive' => 'Archive entry',
      'restore' => 'Restore entry',
      'recover' => 'Recover entry',
      _ => 'Delete entry',
    };
    String? reason;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('$label?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('“${entry['title']}”'),
                const SizedBox(height: 12),
                Text(switch (action) {
                  'archive' => 'Keep the entry, comments and local signals in the read-only archive. Choose a manually reported reason; this does not verify or change the PR.',
                  'restore' => 'Return to the end of its current sprint and priority group. Comments and local signals are kept and may be outdated.',
                  'recover' =>
                    'Return to its previous ${entry['state'] ?? 'active'} state. Active entries append to their current group. Individually deleted comments stay deleted.',
                  _ => 'Hide this entry and its activity. Team admins can recover it from Deleted entries. No permanent purge is scheduled.',
                }),
                if (action == 'archive') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Archive reason',
                    ),
                    items: [
                      for (final item in archiveReasons.entries)
                        DropdownMenuItem(
                          value: item.key,
                          child: Text(item.value),
                        ),
                    ],
                    onChanged: (value) => update(() => reason = value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: action == 'archive' && reason == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
    if (yes != true ||
        !mounted ||
        generation != _generation ||
        team != widget.teamId) {
      return;
    }
    setState(() => _busy = true);
    String message;
    try {
      if (action == 'delete') {
        await widget.repository.delete(team, entry);
      } else {
        await widget.repository.lifecycle(team, entry, action, reason: reason);
      }
      message = switch (action) {
        'archive' => 'Entry archived.',
        'restore' => 'Entry restored.',
        'recover' => 'Entry recovered.',
        _ => 'Entry deleted.',
      };
    } catch (error) {
      message = error is PostgrestException
          ? switch (error.code) {
              '23505' => 'This PR already has an active entry. Nothing was restored or recovered. Review the active queue first.',
              'PT409' => 'This entry changed. The action was not applied. Review the refreshed list before trying again.',
              '22023' => 'The saved links no longer match this team’s allowed hosts, or the archive reason is invalid. Ask the operator to check configuration.',
              '42501' => 'Your access changed or this entry is unavailable. Refresh your teams.',
              'PT429' => 'Too many changes. Wait a minute before trying again.',
              _ => 'Could not confirm the action. Check the refreshed list before trying again.',
            }
          : 'Could not confirm the action. Check the refreshed list before trying again.';
    }
    if (!mounted || generation != _generation) return;
    await _load();
    if (!mounted || team != widget.teamId) return;
    setState(
      () => _message = _message == null ? message : '$message $_message',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewFocus.requestFocus();
    });
  }

  Future<void> _move(List<EntryData> group, int from, int to) async {
    if (_busy || !widget.admin || from == to || _interacting.isNotEmpty) return;
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
            if (widget.admin && !_filtered)
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
      if (!widget.admin || _filtered) return card;
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
    if (_interacting.isNotEmpty) {
      setState(
        () => _message =
            'Finish or clear your comment draft before changing the list.',
      );
      return;
    }
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

  Widget _link(String label, String url, String kind) {
    final normalized = normalizeEnterpriseLink(
      url,
      kind == 'pr' ? _hosts.pr : _hosts.jira,
      kind,
    );
    return TextButton.icon(
      iconAlignment: IconAlignment.end,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        minimumSize: const Size(48, 48),
      ),
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
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final view in [
            'active',
            'archived',
            if (widget.admin) 'deleted',
          ])
            ChoiceChip(
              focusNode: view == _view ? _viewFocus : null,
              label: Text(switch (view) {
                'active' => 'Active queue',
                'archived' => 'Archive',
                _ => 'Deleted entries',
              }),
              selected: _view == view,
              onSelected: _busy ? null : (_) => _selectView(view),
            ),
        ],
      ),
      const SizedBox(height: 12),
      ExpansionTile(
        title: const Text('Search and filters'),
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Search title or links',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _priority ?? 'all',
                  key: ValueKey('priority-$_priority'),
                  decoration: const InputDecoration(
                    labelText: 'Filter priority',
                  ),
                  items: [
                    for (final p in [
                      'all',
                      'critical',
                      'high',
                      'medium',
                      'low',
                    ])
                      DropdownMenuItem(
                        value: p,
                        child: Text(
                          p == 'all'
                              ? 'All priorities'
                              : '${p[0].toUpperCase()}${p.substring(1)}',
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) =>
                            setState(() => _priority = v == 'all' ? null : v),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _sprint == null ? 'all' : '$_sprint',
                  key: ValueKey('sprint-$_sprint'),
                  decoration: const InputDecoration(
                    labelText: 'Filter sprint goal',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All work')),
                    DropdownMenuItem(
                      value: 'true',
                      child: Text('Sprint goals'),
                    ),
                    DropdownMenuItem(value: 'false', child: Text('Other work')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(
                          () => _sprint = v == 'all' ? null : v == 'true',
                        ),
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  initialValue: _submitter ?? 'all',
                  key: ValueKey('submitter-$_submitter'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Filter submitter',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All submitters'),
                    ),
                    for (final m in widget.members)
                      DropdownMenuItem(
                        value: m['user_id'] as String,
                        child: Text(
                          m['name'] as String? ?? 'Teammate',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) =>
                            setState(() => _submitter = v == 'all' ? null : v),
                ),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _applyFilters,
                child: const Text('Apply filters'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        _search.clear();
                        _priority = _submitter = null;
                        _sprint = null;
                        _applyFilters();
                      },
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Visible tabs check every 60 seconds. Last updated: ${_clock(_updated)} · Last checked: ${_clock(_checked)}',
      ),
      if (_filtered)
        const Text(
          'Filters apply across all pages. Clear filters to reorder entries.',
        ),
      if (_view != 'active')
        Text(
          _view == 'archived'
              ? 'Read-only history · Archive reasons are manually reported, never provider-verified. Entries and activity are retained without automatic expiry.'
              : 'Admin recovery · Deleted entries are separate from the archive. Records and minimal audit metadata are retained; no permanent purge is scheduled.',
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          if (_view == 'active')
            FilledButton.icon(
              onPressed: _busy || !_hosts.configured ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _selectView(_view),
            icon: const Icon(Icons.refresh),
            label: Text(_view == 'active' ? 'Refresh queue' : 'Refresh list'),
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
          child: Text('No entries in this view.'),
        ),
      if (_view == 'active' &&
          widget.admin &&
          !_filtered &&
          _entries.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Drag the handle or use Move up / Move down within a group. Sprint goals come first, then Critical, High, Medium and Low.',
          ),
        ),
      if (_view == 'active')
        for (final sprint in [true, false])
          for (final priority in ['critical', 'high', 'medium', 'low'])
            _group(context, sprint, priority),
      if (_view != 'active') ...[
        for (final entry in _entries)
          Padding(
            key: ValueKey(entry['id']),
            padding: const EdgeInsets.only(top: 12),
            child: _card(context, entry),
          ),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Page ${_offset ~/ 25 + 1} · Up to 25 entries'),
          OutlinedButton(
            focusNode: _offset > 0 ? _pageFocus : null,
            onPressed: _busy || _offset == 0 || _interacting.isNotEmpty
                ? null
                : () {
                    _offset -= 25;
                    _loadAndFocus(_pageFocus);
                  },
            child: const Text('Previous page'),
          ),
          OutlinedButton(
            focusNode: _offset == 0 ? _pageFocus : null,
            onPressed: _busy || !_hasMore || _interacting.isNotEmpty
                ? null
                : () {
                    _offset += 25;
                    _loadAndFocus(_pageFocus);
                  },
            child: const Text('Next page'),
          ),
        ],
      ),
    ],
  );
  String _clock(DateTime? time) => time == null
      ? 'not yet'
      : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')} (local)';
  void _applyFilters() {
    if (_interacting.isNotEmpty) {
      setState(
        () => _message =
            'Finish or clear your comment draft before changing the list.',
      );
      return;
    }
    _query = _search.text.trim();
    _appliedPriority = _priority;
    _appliedSprint = _sprint;
    _appliedSubmitter = _submitter;
    _selectView(_view);
  }

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
          if (_view != 'active') ...[
            Text(
              _view == 'archived'
                  ? 'Manually archived: ${archiveReasons[entry['archive_reason']] ?? entry['archive_reason']}'
                  : 'Deleted · Previous state: ${entry['state']}',
            ),
            Text(
              'By ${_actorName(entry[_view == 'archived' ? 'archived_by' : 'deleted_by'])} · ${_displayTime(entry[_view == 'archived' ? 'archived_at' : 'deleted_at'])}',
            ),
            const SizedBox(height: 8),
          ],
          if (member != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(48, 48),
              ),
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
              if (_view == 'deleted' && widget.admin)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeLifecycle(entry, 'recover'),
                  child: const Text('Recover entry'),
                ),
              if (editable && _view != 'deleted') ...[
                if (_view == 'active')
                  TextButton(
                    onPressed: _busy || !_hosts.configured
                        ? null
                        : () => _edit(entry),
                    child: const Text('Edit entry'),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeLifecycle(
                          entry,
                          _view == 'active' ? 'archive' : 'restore',
                        ),
                  child: Text(
                    _view == 'active' ? 'Archive entry' : 'Restore entry',
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _changeLifecycle(entry, 'delete'),
                  child: const Text('Delete entry'),
                ),
              ],
            ],
          ),
          if (_view != 'deleted')
            EntryActivity(
              key: ValueKey('activity-${entry['id']}'),
              repository: widget.repository,
              teamId: widget.teamId,
              entryId: entry['id'] as String,
              admin: widget.admin,
              readOnly: _view != 'active',
              members: widget.members,
              viewProfile: widget.viewProfile,
              dataRevision: _dataRevision,
              onInteraction: (value) {
                final changed = value
                    ? _interacting.add(entry['id'] as String)
                    : _interacting.remove(entry['id']);
                if (changed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {});
                  });
                }
              },
            ),
        ],
      ),
    );
  }

  String _actorName(Object? id) {
    final member = widget.members.where((m) => m['user_id'] == id).firstOrNull;
    return member?['name'] as String? ?? 'Former teammate ($id)';
  }

  String _displayTime(Object? value) {
    final time = DateTime.tryParse('$value')?.toLocal();
    return time == null
        ? ''
        : '${time.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} (local time)';
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

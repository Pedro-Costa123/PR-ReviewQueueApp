import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'entry_repository.dart';
import 'visible_refresh.dart';

String activityError(Object error) => error is PostgrestException
    ? switch (error.code) {
        'PT409' => 'This comment or entry changed. Your draft is kept. Refresh to review the latest activity; cancel editing before starting again.',
        'PT429' => 'Too many changes. Wait a minute before trying again.',
        '22023' => 'Enter 1–2,000 plain-text characters.',
        '42501' => 'Your access changed or this entry is unavailable. Refresh your teams.',
        _ => 'Could not confirm the change. Refresh and check before trying again. Your draft is kept.',
      }
    : 'Could not confirm the change. Refresh and check before trying again. Your draft is kept.';

class EntryActivity extends StatefulWidget {
  const EntryActivity({
    super.key,
    required this.repository,
    required this.teamId,
    required this.entryId,
    required this.admin,
    required this.members,
    required this.viewProfile,
    this.readOnly = false,
    this.dataRevision,
    this.onInteraction,
  });
  final EntryRepository repository;
  final String teamId, entryId;
  final bool admin;
  final bool readOnly;
  final int? dataRevision;
  final void Function(bool)? onInteraction;
  final List<EntryData> members;
  final void Function(String) viewProfile;
  @override
  State<EntryActivity> createState() => _EntryActivityState();
}

class _EntryActivityState extends State<EntryActivity> {
  final _body = TextEditingController();
  final _inputFocus = FocusNode();
  EntryData? _data, _editing;
  bool _open = false, _busy = false, _blocked = false;
  String? _message;
  int _generation = 0;
  int _commentsOffset = 0, _reviewsOffset = 0;
  final _commentsFocus = FocusNode(), _reviewsFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    _body.addListener(_interaction);
  }

  void _interaction() => widget.onInteraction?.call(
    _body.text.isNotEmpty || _editing != null || _busy,
  );
  @override
  void dispose() {
    _body.dispose();
    _commentsFocus.dispose();
    _reviewsFocus.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EntryActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.entryId != widget.entryId ||
        oldWidget.repository != widget.repository) {
      _generation++;
      _data = null;
      _editing = null;
      _body.clear();
      _message = null;
      _blocked = false;
      _busy = false;
      if (_open) _load();
    } else if (oldWidget.dataRevision != widget.dataRevision) {
      if (_open && !_busy && _body.text.isEmpty && _editing == null) {
        _load(background: true);
      } else if (!_open) {
        _data = null;
      }
    }
  }

  Future<void> _load({
    String? message,
    bool paging = false,
    bool background = false,
  }) async {
    final generation = ++_generation;
    final revision = paging ? (_data?['data_revision'] as int?) : null;
    if (!paging) {
      _commentsOffset = 0;
      _reviewsOffset = 0;
    }
    setState(() {
      _busy = !background;
      if (!background) _data = null;
      _message = message;
    });
    _interaction();
    try {
      final data = await widget.repository
          .activityPage(
            widget.teamId,
            widget.entryId,
            commentsOffset: _commentsOffset,
            reviewsOffset: _reviewsOffset,
            revision: revision,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        if (_editing == null) _blocked = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _message = readError(error);
        if (readAccessError(error)) _data = null;
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
      if (mounted) _interaction();
    }
  }

  Future<void> _mutate(
    Future<void> Function() action, {
    bool comment = false,
  }) async {
    if (_busy || _data == null) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _message = null;
    });
    _interaction();
    try {
      await action();
      if (!mounted || generation != _generation) return;
      if (comment) {
        _body.clear();
        _editing = null;
      }
      await _load(message: 'Saved.');
      if (mounted && comment) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _inputFocus.requestFocus();
        });
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _busy = false;
        _message = activityError(error);
        _blocked =
            error is! PostgrestException ||
            !['PT429', '22023'].contains(error.code);
        if (error is PostgrestException && error.code == '42501') _data = null;
      });
      _interaction();
    }
  }

  void _save() {
    final body = _body.text.trim();
    if (body.isEmpty ||
        body.runes.length > 2000 ||
        RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(body)) {
      setState(() => _message = 'Enter 1–2,000 plain-text characters.');
      return;
    }
    _mutate(
      () => widget.repository.comment(
        widget.teamId,
        widget.entryId,
        body,
        original: _editing,
      ),
      comment: true,
    );
  }

  Future<void> _delete(EntryData note) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text(
          'This local comment will be hidden from the entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete comment'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _mutate(
        () => widget.repository.deleteComment(
          widget.teamId,
          widget.entryId,
          note,
        ),
      );
    }
  }

  Widget _person(String id) {
    final member = widget.members
        .where((m) => m['user_id'] == id && m['active'] == true)
        .firstOrNull;
    return member == null
        ? const Text('Former teammate')
        : TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(48, 48),
            ),
            onPressed: _busy ? null : () => widget.viewProfile(id),
            child: Text(
              '${member['name'] ?? 'Teammate'}${id == widget.repository.userId ? ' (you)' : ''}',
            ),
          );
  }

  String _time(Object? value) {
    final time = DateTime.tryParse('$value')?.toLocal();
    return time == null
        ? ''
        : '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final notes = List<EntryData>.from(data?['comments'] ?? []);
    final reviews = List<EntryData>.from(data?['reviews'] ?? []);
    final active = !widget.readOnly && data?['state'] == 'active';
    final canReview =
        active && data?['submitter_id'] != widget.repository.userId;
    final enabled = !_busy && !_blocked && data != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            iconAlignment: IconAlignment.end,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              alignment: Alignment.centerLeft,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () {
              setState(() => _open = !_open);
              if (_open && _data == null && !_busy) _load();
            },
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            label: Text(
              _open ? 'Hide comments and reviews' : 'Comments and reviews',
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh activity'),
            ),
          ),
          if (_busy)
            const LinearProgressIndicator(semanticsLabel: 'Loading activity'),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
          if (data != null) ...[
            const SizedBox(height: 24),
            Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                Text(
                  'Reviewed, looks good: ${data['looks_good_count']}',
                  style: const TextStyle(height: 1.5),
                ),
                Text(
                  'Comments left on PR: ${data['comments_left_count']}',
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (active && data['submitter_id'] == widget.repository.userId)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'You can comment, but cannot review your own entry.',
                  style: TextStyle(height: 1.5),
                ),
              ),
            if (!active)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('This entry is read-only.'),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final signal in ['looks_good', 'comments_left'])
                  FilterChip(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    avatar: Icon(
                      signal == 'looks_good' ? Icons.check : Icons.close,
                      size: 18,
                    ),
                    label: Text(
                      signal == 'looks_good'
                          ? 'Reviewed, looks good'
                          : 'Comments left on PR',
                    ),
                    selected: data['my_signal'] == signal,
                    onSelected: enabled && canReview
                        ? (_) => _mutate(
                            () => widget.repository.review(
                              widget.teamId,
                              widget.entryId,
                              data['entry_version'] as int,
                              signal,
                            ),
                          )
                        : null,
                  ),
                TextButton(
                  onPressed: enabled && active && data['my_signal'] != null
                      ? () => _mutate(
                          () => widget.repository.review(
                            widget.teamId,
                            widget.entryId,
                            data['entry_version'] as int,
                            null,
                          ),
                        )
                      : null,
                  child: const Text('Clear my signal'),
                ),
              ],
            ),
            for (final review in reviews)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _person(review['user_id'] as String),
                    Text(
                      review['signal'] == 'looks_good'
                          ? 'Reviewed, looks good'
                          : 'Comments left on PR',
                    ),
                    Text(_time(review['updated_at'])),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _pages(
              false,
              (data['looks_good_count'] as int) +
                  (data['comments_left_count'] as int),
            ),
            const Divider(height: 40),
            Text(
              'Comments (${data['comments_count']})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (active) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _body,
                focusNode: _inputFocus,
                enabled: !_busy,
                minLines: 2,
                maxLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: _editing == null
                      ? 'Add a comment'
                      : 'Edit your comment',
                  helperText: 'Plain text · stays in this app',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: enabled ? _save : null,
                    child: Text(
                      _editing == null ? 'Post comment' : 'Save comment',
                    ),
                  ),
                  if (_editing != null || _blocked)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _editing = null;
                                _body.clear();
                                _blocked = false;
                                _message = null;
                              });
                            },
                      child: const Text('Cancel editing'),
                    ),
                ],
              ),
            ],
            if (notes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No comments yet.'),
              ),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _person(note['author_id'] as String),
                        Text(
                          '${_time(note['updated_at'])}${note['version'] == 1 ? '' : ' · edited'}',
                        ),
                      ],
                    ),
                    // Text widgets never parse HTML or Markdown or fetch embedded URLs.
                    Text(note['body'] as String),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 16,
                      children: [
                        if (note['author_id'] == widget.repository.userId)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: enabled && active
                                ? () {
                                    setState(() {
                                      _editing = note;
                                      _body.text = note['body'] as String;
                                      _message = null;
                                    });
                                    _interaction();
                                    _inputFocus.requestFocus();
                                  }
                                : null,
                            child: const Text('Edit comment'),
                          ),
                        if (note['author_id'] == widget.repository.userId ||
                            widget.admin)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: enabled && active
                                ? () => _delete(note)
                                : null,
                            child: Text(
                              note['author_id'] == widget.repository.userId
                                  ? 'Delete comment'
                                  : 'Remove comment (admin)',
                            ),
                          ),
                      ],
                    ),
                    const Divider(),
                  ],
                ),
              ),
            _pages(true, data['comments_count'] as int),
          ],
        ],
      ],
    );
  }

  Widget _pages(bool comments, int total) {
    final offset = comments ? _commentsOffset : _reviewsOffset;
    final label = comments ? 'comments' : 'reviewers';
    final focus = comments ? _commentsFocus : _reviewsFocus;
    Future<void> move(int delta) async {
      if (comments) {
        _commentsOffset += delta;
      } else {
        _reviewsOffset += delta;
      }
      await _load(paging: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${comments ? 'Comments' : 'Reviewers'} page ${offset ~/ 25 + 1} · $total total',
        ),
        TextButton(
          focusNode: offset > 0 ? focus : null,
          onPressed: _busy || offset == 0 ? null : () => move(-25),
          child: Text('Previous $label'),
        ),
        TextButton(
          focusNode: offset == 0 ? focus : null,
          onPressed: _busy || offset + 25 >= total ? null : () => move(25),
          child: Text('Next $label'),
        ),
      ],
    );
  }
}

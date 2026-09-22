import 'package:supabase_flutter/supabase_flutter.dart';

typedef EntryData = Map<String, dynamic>;

class QueueSnapshot {
  const QueueSnapshot(this.entries, this.revision, {this.hasMore = false});
  final List<EntryData> entries;
  final int revision;
  final bool hasMore;
}

class LinkHosts {
  const LinkHosts({required this.pr, required this.jira});
  final List<String> pr, jira;
  bool get configured => pr.isNotEmpty && jira.isNotEmpty;
}

/// Matches the database's narrow enterprise resource grammar. No URL fetching.
String? normalizeEnterpriseLink(String value, List<String> hosts, String kind) {
  if (value.length > 2048 ||
      RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(value) ||
      RegExp(
        r'%(0[0-9a-f]|1[0-9a-f]|7f|5c)',
        caseSensitive: false,
      ).hasMatch(value)) {
    return null;
  }
  final parts = RegExp(
    r'^https://([A-Za-z0-9.-]+)(:443)?(/[^?#]*)([?#][A-Za-z0-9._~!$&()*+,;=:@/?%#-]*)?$',
    caseSensitive: false,
  ).firstMatch(value);
  if (parts == null) return null;
  final host = parts[1]!.toLowerCase();
  if (!hosts.contains(host)) return null;
  final path = parts[3]!;
  if (kind == 'pr') {
    final match = RegExp(
      r'^/([A-Za-z0-9_-]+)/([A-Za-z0-9_.-]+)/pull/([1-9][0-9]*)(/(files|commits|checks))?/?$',
    ).firstMatch(path);
    if (match == null || ['.', '..'].contains(match[2])) return null;
    return 'https://$host/${match[1]!.toLowerCase()}/${match[2]!.toLowerCase()}/pull/${match[3]}';
  }
  if (kind == 'jira') {
    final match = RegExp(
      r'^(/([A-Za-z0-9_-]+/)*browse/)([A-Za-z][A-Za-z0-9_]*-[1-9][0-9]*)/?$',
    ).firstMatch(path);
    if (match == null) return null;
    return 'https://$host${match[1]}${match[3]!.toUpperCase()}';
  }
  return null;
}

abstract interface class EntryRepository {
  String get userId;
  Future<LinkHosts> hosts(String teamId);
  Future<QueueSnapshot> list(String teamId);
  Future<void> move(
    String teamId,
    String entryId,
    String targetId, {
    required bool after,
    required int revision,
  });
  Future<void> save(String teamId, EntryData fields, {EntryData? original});
  Future<void> delete(String teamId, EntryData entry);
}

class SupabaseEntryRepository implements EntryRepository {
  SupabaseEntryRepository(this.client);
  final SupabaseClient client;
  @override
  String get userId => client.auth.currentUser!.id;
  @override
  Future<LinkHosts> hosts(String teamId) async {
    final result = await client.rpc(
      'queue_link_hosts',
      params: {'p_team_id': teamId},
    );
    return LinkHosts(
      pr: List<String>.from(result['pr']),
      jira: List<String>.from(result['jira']),
    );
  }

  @override
  Future<QueueSnapshot> list(String teamId) async {
    final result = await client.rpc(
      'queue_snapshot',
      params: {'p_team_id': teamId},
    );
    return QueueSnapshot(
      List<EntryData>.from(result['entries']),
      result['revision'] as int,
      hasMore: result['has_more'] as bool,
    );
  }

  @override
  Future<void> move(
    String teamId,
    String entryId,
    String targetId, {
    required bool after,
    required int revision,
  }) async {
    await client.rpc(
      'move_entry',
      params: {
        'p_team_id': teamId,
        'p_entry_id': entryId,
        'p_target_id': targetId,
        'p_after': after,
        'p_expected_revision': revision,
      },
    );
  }

  @override
  Future<void> save(
    String teamId,
    EntryData fields, {
    EntryData? original,
  }) async {
    await client.rpc(
      original == null ? 'create_entry' : 'update_entry',
      params: {
        'p_team_id': teamId,
        if (original != null) ...{
          'p_entry_id': original['id'],
          'p_expected_version': original['version'],
        },
        for (final key in [
          'title',
          'pr_url',
          'jira_url',
          'sprint_goal',
          'priority',
        ])
          'p_$key': fields[key],
      },
    );
  }

  @override
  Future<void> delete(String teamId, EntryData entry) async {
    await client.rpc(
      'delete_entry',
      params: {
        'p_team_id': teamId,
        'p_entry_id': entry['id'],
        'p_expected_version': entry['version'],
      },
    );
  }
}

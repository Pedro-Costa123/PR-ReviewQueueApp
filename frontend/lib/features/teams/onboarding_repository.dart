import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';

typedef RecordData = Map<String, dynamic>;

abstract interface class OnboardingRepository {
  String get userId;
  Future<void> claimInvites();
  Future<List<RecordData>> teams();
  Future<RecordData> profile(String id);
  Future<void> saveProfile(String name, String username);
  Future<List<RecordData>> members(String teamId);
  Future<List<RecordData>> invites(String teamId);
  Future<void> invite(String teamId, String email, String role);
  Future<void> revoke(String invitationId);
  Future<void> setAccess(
    String teamId,
    String userId,
    String role,
    bool active,
  );
}

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this.client, this.auth);
  final SupabaseClient client;
  final AuthRepository auth;

  @override
  String get userId => client.auth.currentUser!.id;
  @override
  Future<void> claimInvites() async => await client.rpc('claim_invites');
  @override
  Future<List<RecordData>> teams() async {
    final rows = await client
        .from('team_memberships')
        .select('team_id,role,teams(id,name)')
        .eq('user_id', userId)
        .eq('active', true)
        .order('team_id')
        .limit(100);
    return rows
        .map(
          (row) => <String, dynamic>{
            ...row['teams'] as Map<String, dynamic>,
            'role': row['role'],
          },
        )
        .toList();
  }

  @override
  Future<RecordData> profile(String id) async => Map<String, dynamic>.from(
    await client.rpc('profile_details', params: {'p_user_id': id}),
  );
  @override
  Future<void> saveProfile(String name, String username) async {
    await client.rpc(
      'save_profile',
      params: {'p_name': name, 'p_username': username},
    );
  }

  @override
  Future<List<RecordData>> members(String teamId) async {
    final rows = await client
        .from('team_memberships')
        .select('user_id,role,active')
        .eq('team_id', teamId)
        .order('user_id')
        .limit(100);
    return Future.wait(
      rows.map(
        (row) async => <String, dynamic>{
          ...row,
          // Inactive members do not disclose an email/profile through this roster.
          if (row['active'] == true) ...await profile(row['user_id'] as String),
        },
      ),
    );
  }

  @override
  Future<List<RecordData>> invites(String teamId) async => await client
      .from('team_invites')
      .select('id,email,role,expires_at,provisioning_state')
      .eq('team_id', teamId)
      .isFilter('claimed_at', null)
      .isFilter('revoked_at', null)
      .order('created_at', ascending: false)
      .limit(100);
  @override
  Future<void> invite(String teamId, String email, String role) async {
    final result = await client.functions.invoke(
      'invite-member',
      body: {
        'team_id': teamId,
        'email': email.trim().toLowerCase(),
        'role': role,
      },
    );
    if (result.status != 200 || result.data['state'] != 'provisioned') {
      throw StateError('Provisioning incomplete');
    }
    // Every delivery attempt keeps the existing fresh CAPTCHA and signed hook.
    await auth.requestLink(result.data['email'] as String);
  }

  @override
  Future<void> revoke(String invitationId) async {
    await client.rpc('revoke_invite', params: {'p_invite_id': invitationId});
  }

  @override
  Future<void> setAccess(
    String teamId,
    String userId,
    String role,
    bool active,
  ) async {
    await client.rpc(
      'set_member_access',
      params: {
        'p_team_id': teamId,
        'p_user_id': userId,
        'p_role': role,
        'p_active': active,
      },
    );
  }
}

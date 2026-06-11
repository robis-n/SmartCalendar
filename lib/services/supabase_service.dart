import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/time_utils.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ── Tasks ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTodayTasks() async {
    return getTasksForDate(DateTime.now());
  }

  static Future<List<Map<String, dynamic>>> getTasksForDate(DateTime date) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final start = tsToDb(DateTime(date.year, date.month, date.day));
    final end = tsToDb(DateTime(date.year, date.month, date.day, 23, 59, 59));
    final res = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .gte('scheduled_time', start)
        .lte('scheduled_time', end)
        .order('scheduled_time');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getTasksForMonth(int year, int month) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final start = tsToDb(DateTime(year, month, 1));
    final end = tsToDb(DateTime(year, month + 1, 0, 23, 59, 59));
    final res = await client
        .from('tasks')
        .select('id, scheduled_time, status')
        .eq('user_id', userId)
        .gte('scheduled_time', start)
        .lte('scheduled_time', end);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getUpcomingPendingTasks() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final now = tsToDb(DateTime.now());
    // 14 days, not 24h: rescheduleAll cancels everything on app open and
    // re-arms only what this returns — a narrow window silently disarmed
    // any task scheduled further out. iOS's 64-pending cap is enforced
    // downstream (rescheduleAll stops at 56).
    final future = tsToDb(DateTime.now().add(const Duration(days: 14)));
    final res = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('scheduled_time', now)
        .lte('scheduled_time', future)
        .order('scheduled_time');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>?> getTaskById(String taskId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await client
        .from('tasks')
        .select()
        .eq('id', taskId)
        .eq('user_id', userId)
        .maybeSingle();
    return res;
  }

  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> task) async {
    final res = await client.from('tasks').insert(task).select().single();
    return res;
  }

  static Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    await client.from('tasks').update(data).eq('id', taskId);
  }

  static Future<void> updateTaskStatus(String taskId, String status) async {
    await client.from('tasks').update({
      'status': status,
      if (status == 'verified' || status == 'failed')
        'completed_at': tsToDb(DateTime.now()),
    }).eq('id', taskId);
  }

  static Future<void> deleteTask(String taskId) async {
    // Clear dependents first (FK constraints would otherwise block the delete).
    await client.from('task_verifications').delete().eq('task_id', taskId);
    await client.from('collaborations').delete().eq('task_id', taskId);
    await client.from('tasks').delete().eq('id', taskId);
  }

  // ── Analytics ──────────────────────────────────────────

  static Future<Map<String, dynamic>> getAnalyticsSummary() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return {};
    final tasks = List<Map<String, dynamic>>.from(
      await client.from('tasks').select().eq('user_id', userId),
    );
    final total = tasks.length;
    final done = tasks.where((t) => t['status'] == 'verified').length;
    final failed = tasks.where((t) => t['status'] == 'failed').length;
    final pending = tasks.where((t) => t['status'] == 'pending').length;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekTasks = tasks.where((t) {
      if (t['scheduled_time'] == null) return false;
      final d = tsTryFromDb(t['scheduled_time']);
      return d != null && d.isAfter(weekStart);
    }).toList();

    return {
      'total': total,
      'done': done,
      'failed': failed,
      'pending': pending,
      'rate': total == 0 ? 0.0 : done / total,
      'week_total': weekTasks.length,
      'week_done': weekTasks.where((t) => t['status'] == 'verified').length,
      'high_priority': tasks.where((t) => t['priority'] == 'high').length,
    };
  }

  // ── Verifications ──────────────────────────────────────

  static Future<void> saveVerification(Map<String, dynamic> verification) async {
    await client.from('task_verifications').insert(verification);
  }

  // ── User profile ───────────────────────────────────────

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await client.from('users').select().eq('id', userId).maybeSingle();
    return res;
  }

  static Future<void> upsertUserProfile(Map<String, dynamic> data) async {
    await client.from('users').upsert(data);
  }

  static Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await getUserProfile();
    final current = Map<String, dynamic>.from(
      (profile?['preferences'] as Map?) ?? {},
    );
    current.addAll(prefs);
    await client.from('users').update({'preferences': current}).eq('id', userId);
  }

  static Future<void> updatePrivacySettings(Map<String, dynamic> settings) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await getUserProfile();
    final current = Map<String, dynamic>.from(
      (profile?['privacy_settings'] as Map?) ?? {},
    );
    current.addAll(settings);
    await client.from('users').update({'privacy_settings': current}).eq('id', userId);
  }

  static Future<void> deleteAllUserData() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    // Delete task verifications first (FK dependency)
    final taskRows = List<Map<String, dynamic>>.from(
      await client.from('tasks').select('id').eq('user_id', userId),
    );
    final taskIds = taskRows.map((t) => t['id'] as String).toList();
    if (taskIds.isNotEmpty) {
      await client.from('task_verifications').delete().inFilter('task_id', taskIds);
    }
    await client.from('collaborations').delete().eq('owner_id', userId);
    await client.from('tasks').delete().eq('user_id', userId);
    await client.from('friendships').delete().or('requester_id.eq.$userId,addressee_id.eq.$userId');
    await client.from('challenges').delete().or('creator_id.eq.$userId,partner_id.eq.$userId');
    await client.from('users').update({
      'preferences': <String, dynamic>{},
      'privacy_settings': <String, dynamic>{},
    }).eq('id', userId);
  }

  // ── Storage ────────────────────────────────────────────

  static Future<String> uploadVerificationPhoto(
      String taskId, Uint8List bytes, String ext) async {
    final userId = client.auth.currentUser?.id ?? 'unknown';
    final path = '$userId/$taskId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from('verification-photos').uploadBinary(path, bytes);
    return client.storage
        .from('verification-photos')
        .createSignedUrl(path, 3600 * 24);
  }

  // ── Users / search ─────────────────────────────────────

  /// True iff this username can be claimed at signup. Server-side RPC so the
  /// rule (lowercased, stripped to a-z0-9_) matches what the DB actually stores.
  static Future<bool> isUsernameAvailable(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.length < 3 || clean.length > 24) return false;
    try {
      final res = await client.rpc('username_available', params: {'p': clean});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Find someone by @username (preferred) — falls back to email if it
  /// contains an @ (so existing email-based flows still work).
  static Future<Map<String, dynamic>?> searchUserByHandle(String handle) async {
    final myId = client.auth.currentUser?.id;
    final q = handle.toLowerCase().trim().replaceFirst(RegExp(r'^@'), '');
    if (q.isEmpty) return null;
    final byUsername = await client
        .from('users')
        .select('id, email, username')
        .eq('username', q)
        .maybeSingle();
    if (byUsername != null && byUsername['id'] != myId) return byUsername;
    if (q.contains('@')) {
      final byEmail = await client
          .from('users')
          .select('id, email, username')
          .eq('email', q)
          .maybeSingle();
      if (byEmail != null && byEmail['id'] != myId) return byEmail;
    }
    return null;
  }

  /// Backwards-compat alias for the older code paths still calling this name.
  static Future<Map<String, dynamic>?> searchUserByEmail(String email) =>
      searchUserByHandle(email);

  /// Resolve a username → email so the user can sign in with either.
  /// Returns null if no such user (caller treats input as email already).
  static Future<String?> emailForUsername(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.isEmpty || clean.contains('@')) return null;
    final res = await client
        .from('users')
        .select('email')
        .eq('username', clean)
        .maybeSingle();
    return res?['email'] as String?;
  }

  /// Random "you might know…" friend suggestions — people I'm not already
  /// connected to (no friendship row in either direction) and aren't me.
  /// Capped at [limit]; deliberately lightweight (UI sugar, not a graph algo).
  static Future<List<Map<String, dynamic>>> getFriendSuggestions({int limit = 6}) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];

    // IDs I'm already tied to (any status).
    final mine = await client
        .from('friendships')
        .select('requester_id, addressee_id')
        .or('requester_id.eq.$me,addressee_id.eq.$me');
    final excluded = <String>{me};
    for (final row in (mine as List)) {
      excluded.add(row['requester_id'] as String);
      excluded.add(row['addressee_id'] as String);
    }

    final all = List<Map<String, dynamic>>.from(
      await client.from('users').select('id, username, email').limit(40),
    );
    final candidates = all.where((u) => !excluded.contains(u['id'])).toList();
    candidates.shuffle();
    return candidates.take(limit).toList();
  }

  // ── Friends ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getFriendships() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final res = await client
        .from('friendships')
        .select('id, status, created_at, requester_id, addressee_id, requester:users!friendships_requester_id_fkey(id, email, username), addressee:users!friendships_addressee_id_fkey(id, email, username)')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> sendFriendRequest(String addresseeId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('friendships').insert({
      'requester_id': userId,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
  }

  static Future<void> acceptFriendRequest(String friendshipId) async {
    await client.from('friendships').update({'status': 'accepted'}).eq('id', friendshipId);
  }

  static Future<void> declineFriendRequest(String friendshipId) async {
    await client.from('friendships').delete().eq('id', friendshipId);
  }

  // ── Challenges ─────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getChallenges() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final res = await client
        .from('challenges')
        .select('id, title, status, created_at, creator_id, partner_id, creator_done, partner_done, completed_at, creator:users!challenges_creator_id_fkey(id, email, username), partner:users!challenges_partner_id_fkey(id, email, username)')
        .or('creator_id.eq.$userId,partner_id.eq.$userId')
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createChallenge({
    required String partnerId,
    required String title,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    await client.from('challenges').insert({
      'creator_id': userId,
      'partner_id': partnerId,
      'title': title,
      'status': 'active',
    });
  }

  static Future<void> abandonChallenge(String challengeId) async {
    await client.from('challenges').update({'status': 'abandoned'}).eq('id', challengeId);
  }

  /// Mark MY side of this challenge done. The DB trigger flips status to
  /// 'completed' when both sides are done — we don't decide that client-side.
  static Future<void> markChallengeSideDone(Map<String, dynamic> c) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    final isCreator = c['creator_id'] == me;
    final field = isCreator ? 'creator_done' : 'partner_done';
    final stampField = isCreator ? 'creator_completed_at' : 'partner_completed_at';
    await client.from('challenges').update({
      field: true,
      stampField: tsToDb(DateTime.now()),
    }).eq('id', c['id']);
  }

  /// Send the other side a nudge. The DB rate-limit (1/hour) is authoritative;
  /// surface its error so the UI can show a friendly message.
  static Future<String?> nudgeChallengePartner(Map<String, dynamic> c) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return 'Not signed in';
    final other = c['creator_id'] == me ? c['partner_id'] : c['creator_id'];
    try {
      await client.from('nudges').insert({
        'challenge_id': c['id'],
        'from_user_id': me,
        'to_user_id': other,
        'message': "Don't forget your challenge — '${c['title']}'",
      });
      return null;
    } catch (e) {
      final s = e.toString();
      if (s.contains('NUDGE_RATE_LIMITED')) return 'You just nudged — wait a bit.';
      return 'Could not nudge right now';
    }
  }

  /// Unread nudges for me (used to badge the Friends entry).
  static Future<int> unseenNudgeCount() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return 0;
    final res = await client.from('nudges')
        .select('id')
        .eq('to_user_id', me)
        .eq('seen', false);
    return (res as List).length;
  }

  /// Latest nudges to me (for an inbox view).
  static Future<List<Map<String, dynamic>>> getNudges() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];
    return List<Map<String, dynamic>>.from(
      await client.from('nudges')
          .select('id, message, seen, created_at, challenge_id, from_user_id, from:users!nudges_from_user_id_fkey(username, email)')
          .eq('to_user_id', me)
          .order('created_at', ascending: false)
          .limit(20),
    );
  }

  static Future<void> markNudgesSeen() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    await client.from('nudges').update({'seen': true})
        .eq('to_user_id', me).eq('seen', false);
  }

  // ── Collaboration ──────────────────────────────────────

  /// Accepted friends as [{id, email}] — used by the New Task collaborator picker.
  static Future<List<Map<String, dynamic>>> getAcceptedFriends() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];
    final fs = await getFriendships();
    final out = <Map<String, dynamic>>[];
    for (final f in fs) {
      if (f['status'] != 'accepted') continue;
      final other = (f['requester_id'] == me ? f['addressee'] : f['requester']) as Map?;
      if (other != null && other['id'] != null) {
        out.add({'id': other['id'], 'email': other['email'] ?? '?'});
      }
    }
    return out;
  }

  /// Share an existing task with friends (creates a collaboration row).
  static Future<void> addCollaborators(String taskId, List<String> invitedIds) async {
    final me = client.auth.currentUser?.id;
    if (me == null || invitedIds.isEmpty) return;
    await client.from('collaborations').insert({
      'owner_id': me,
      'task_id': taskId,
      'invited_user_ids': invitedIds,
      'status': 'active',
    });
  }

  /// Tasks other people have shared with me, scheduled on [date].
  /// Each row gets a `_shared_by` email for display.
  static Future<List<Map<String, dynamic>>> getSharedTasksForDate(DateTime date) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];
    final collabs = List<Map<String, dynamic>>.from(
      await client.from('collaborations')
          .select('task_id, owner_id')
          .contains('invited_user_ids', [me]),
    );
    if (collabs.isEmpty) return [];

    final ownerOf = {for (final c in collabs) c['task_id']: c['owner_id']};
    final taskIds = collabs.map((c) => c['task_id']).whereType<String>().toList();
    if (taskIds.isEmpty) return [];

    final start = tsToDb(DateTime(date.year, date.month, date.day));
    final end = tsToDb(DateTime(date.year, date.month, date.day, 23, 59, 59));
    final tasks = List<Map<String, dynamic>>.from(
      await client.from('tasks').select()
          .inFilter('id', taskIds)
          .gte('scheduled_time', start)
          .lte('scheduled_time', end)
          .order('scheduled_time'),
    );
    if (tasks.isEmpty) return [];

    // Resolve owner emails.
    final ownerIds = ownerOf.values.whereType<String>().toSet().toList();
    final ownerRows = ownerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await client.from('users').select('id, email').inFilter('id', ownerIds));
    final emailOf = {for (final r in ownerRows) r['id']: r['email']};

    for (final t in tasks) {
      t['_shared_by'] = emailOf[ownerOf[t['id']]] ?? 'a friend';
    }
    return tasks;
  }
}

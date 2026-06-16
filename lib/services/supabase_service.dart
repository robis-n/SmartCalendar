import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/time_utils.dart';
import '../core/utils/recurrence.dart';
import '../core/utils/app_events.dart';

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
        .neq('status', 'archived')
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
        .select('id, title, scheduled_time, status')
        .eq('user_id', userId)
        .neq('status', 'archived')
        .gte('scheduled_time', start)
        .lte('scheduled_time', end);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Timeless reminders — tasks created without a deadline (bucket-list items).
  /// These never become "overdue" and live in a dedicated ANYTIME section.
  static Future<List<Map<String, dynamic>>> getGlobalReminders() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final res = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .neq('status', 'verified')
        .neq('status', 'archived')
        .filter('scheduled_time', 'is', null)
        .order('created_at', ascending: false);
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

  /// Tasks the user never completed and whose time has already passed.
  /// Powers the "unfinished" button and the home fallback shown when today
  /// is empty. Newest-overdue first so the most recent slip is on top.
  static Future<List<Map<String, dynamic>>> getUndoneTasks({int limit = 60}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final now = tsToDb(DateTime.now());
    final res = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .neq('status', 'verified')
        .neq('status', 'archived')
        .lt('scheduled_time', now)
        .order('scheduled_time', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Which days of the given week (Mon-anchored) carry at least one task.
  /// Returns day-offsets 0..6 (Mon=0) for the home week strip's dots.
  static Future<Set<int>> getTaskDayOffsetsForWeek(DateTime weekStart) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return {};
    final monday = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final start = tsToDb(monday);
    final end = tsToDb(monday.add(const Duration(days: 7)));
    final res = await client
        .from('tasks')
        .select('scheduled_time')
        .eq('user_id', userId)
        .neq('status', 'archived')
        .gte('scheduled_time', start)
        .lt('scheduled_time', end);
    final offsets = <int>{};
    for (final r in res) {
      final d = tsTryFromDb(r['scheduled_time'] as String?);
      if (d == null) continue;
      final off = DateTime(d.year, d.month, d.day).difference(monday).inDays;
      if (off >= 0 && off < 7) offsets.add(off);
    }
    return offsets;
  }

  /// All of the current user's tasks in the given Mon-anchored week,
  /// ordered by time — powers the home "this week" agenda.
  static Future<List<Map<String, dynamic>>> getTasksForWeek(DateTime weekStart) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final monday = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final start = tsToDb(monday);
    final end = tsToDb(monday.add(const Duration(days: 7)));
    final res = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .neq('status', 'archived')
        .gte('scheduled_time', start)
        .lt('scheduled_time', end)
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

  /// Fetch a task by id WITHOUT the owner filter — RLS still guards it, so this
  /// resolves to a row only if I own it OR I'm a collaborator (invited). This
  /// is what makes a shared task openable instead of showing "Not found".
  /// Returns the row plus `_is_owner` and, when shared, `_shared_by` email.
  static Future<Map<String, dynamic>?> getAnyTaskById(String taskId) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return null;
    final res = await client
        .from('tasks')
        .select()
        .eq('id', taskId)
        .maybeSingle();
    if (res == null) return null;
    final isOwner = res['user_id'] == me;
    res['_is_owner'] = isOwner;
    if (!isOwner) {
      // Resolve who shared it (best-effort; never blocks the open).
      try {
        final owner = await client
            .from('users')
            .select('email, username')
            .eq('id', res['user_id'])
            .maybeSingle();
        res['_shared_by'] = (owner?['username'] as String?)?.isNotEmpty == true
            ? '@${owner!['username']}'
            : (owner?['email'] as String? ?? 'a friend');
      } catch (_) {
        res['_shared_by'] = 'a friend';
      }
    }
    return res;
  }

  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> task) async {
    final res = await client.from('tasks').insert(task).select().single();
    bumpData();
    return res;
  }

  static Future<void> updateTask(String taskId, Map<String, dynamic> data) async {
    await client.from('tasks').update(data).eq('id', taskId);
    bumpData();
  }

  static Future<void> updateTaskStatus(String taskId, String status) async {
    await client.from('tasks').update({
      'status': status,
      if (status == 'verified' || status == 'failed')
        'completed_at': tsToDb(DateTime.now()),
    }).eq('id', taskId);
    bumpData();
  }

  /// Hide a task without deleting it (swipe → Archive). Excluded from all the
  /// list queries above.
  static Future<void> archiveTask(String taskId) async {
    await client.from('tasks').update({'status': 'archived'}).eq('id', taskId);
    bumpData();
  }

  /// Permanently remove every completed (verified) task for the current user —
  /// the "Clear completed" action. Clears FK dependents first.
  static Future<int> clearCompletedTasks() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return 0;
    final done = List<Map<String, dynamic>>.from(
      await client.from('tasks').select('id')
          .eq('user_id', userId).eq('status', 'verified'),
    );
    final ids = done.map((t) => t['id'] as String).toList();
    if (ids.isEmpty) return 0;
    await client.from('task_verifications').delete().inFilter('task_id', ids);
    await client.from('collaborations').delete().inFilter('task_id', ids);
    await client.from('tasks').delete().inFilter('id', ids);
    bumpData();
    return ids.length;
  }

  /// When a repeating task is completed, create its next occurrence so it
  /// "repeats". Returns the new task row, or null if it doesn't recur / has no
  /// scheduled time to advance. Notifications are armed by the caller.
  static Future<Map<String, dynamic>?> spawnNextOccurrence(
      Map<String, dynamic> task) async {
    final rule = (task['recurrence'] as Map?)?.cast<String, dynamic>();
    final sched = tsTryFromDb(task['scheduled_time'] as String?);
    if (sched == null) return null; // global tasks don't auto-repeat
    final next = Recurrence.nextOccurrence(sched, rule);
    if (next == null) return null;
    final uid = client.auth.currentUser?.id;
    return createTask({
      'user_id': uid,
      'title': task['title'],
      'description': task['description'],
      'scheduled_time': tsToDb(next),
      'all_day': task['all_day'] ?? false,
      'status': 'pending',
      'ai_generated': false,
      'priority': task['priority'] ?? 'medium',
      'verification_required': task['verification_required'] ?? true,
      'recurrence': rule,
    });
  }

  /// Read a task's linked device-calendar events (and optionally clear the
  /// link). Lets the caller delete the synced Apple/Google copies when a
  /// reminder is completed.
  static Future<List<dynamic>> linkedCalendarEvents(String taskId,
      {bool clear = false}) async {
    final t = await getTaskById(taskId);
    final list = List<dynamic>.from((t?['device_events'] as List?) ?? const []);
    if (clear && list.isNotEmpty) {
      await client.from('tasks').update({'device_events': []}).eq('id', taskId);
    }
    return list;
  }

  static Future<void> deleteTask(String taskId) async {
    // Clear dependents first (FK constraints would otherwise block the delete).
    await client.from('task_verifications').delete().eq('task_id', taskId);
    await client.from('collaborations').delete().eq('task_id', taskId);
    await client.from('tasks').delete().eq('id', taskId);
    bumpData();
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

  /// Find someone by @username or email. Routed through a SECURITY DEFINER
  /// RPC that returns only {id, username} — the users table itself is no
  /// longer broadly readable, so strangers' emails never leave the server.
  static Future<Map<String, dynamic>?> searchUserByHandle(String handle) async {
    final q = handle.trim().replaceFirst(RegExp(r'^@'), '');
    if (q.isEmpty) return null;
    try {
      final res = await client.rpc('search_user', params: {'p': q});
      final list = List<Map<String, dynamic>>.from((res as List?) ?? const []);
      return list.isEmpty ? null : list.first; // {id, username}
    } catch (_) {
      return null;
    }
  }

  /// Backwards-compat alias for the older code paths still calling this name.
  static Future<Map<String, dynamic>?> searchUserByEmail(String email) =>
      searchUserByHandle(email);

  /// Resolve a username → email so the user can sign in with either.
  /// Server-side RPC (callable pre-auth); returns null if no such user.
  static Future<String?> emailForUsername(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.isEmpty || clean.contains('@')) return null;
    try {
      final res = await client.rpc('email_for_username', params: {'p': clean});
      return res as String?;
    } catch (_) {
      return null;
    }
  }

  /// Random "you might know…" friend suggestions — people I'm not already
  /// connected to (no friendship row in either direction) and aren't me.
  /// Capped at [limit]; deliberately lightweight (UI sugar, not a graph algo).
  static Future<List<Map<String, dynamic>>> getFriendSuggestions({int limit = 6}) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];
    // Server-side RPC: returns only {id, username} of non-friends, never email.
    try {
      final res = await client.rpc('friend_suggestions', params: {'lim': limit});
      return List<Map<String, dynamic>>.from((res as List?) ?? const []);
    } catch (_) {
      return [];
    }
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
        out.add({
          'id': other['id'],
          'email': other['email'] ?? '?',
          'username': other['username'] ?? '',
        });
      }
    }
    return out;
  }

  /// Share an existing task with friends — creates a collaboration row that's
  /// PENDING until each invitee accepts. Never appears in their task list on
  /// its own; see [getPendingTaskInvites] / [acceptTaskInvite].
  static Future<void> addCollaborators(String taskId, List<String> invitedIds) async {
    final me = client.auth.currentUser?.id;
    if (me == null || invitedIds.isEmpty) return;
    await client.from('collaborations').insert({
      'owner_id': me,
      'task_id': taskId,
      'invited_user_ids': invitedIds,
      'accepted_user_ids': <String>[],
      'status': 'active',
    });
  }

  /// Task invites waiting on MY response — invited but not yet accepted.
  /// Each row gets `_owner` (handle) + `_task` (title/time) for display.
  static Future<List<Map<String, dynamic>>> getPendingTaskInvites() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];
    final collabs = List<Map<String, dynamic>>.from(
      await client.from('collaborations')
          .select('id, task_id, owner_id')
          .contains('invited_user_ids', [me]),
    );
    // Filter to "invited but not accepted" client-side — Postgrest can't
    // express "NOT in array" against a uuid[] column cleanly.
    final pending = <Map<String, dynamic>>[];
    for (final c in collabs) {
      final accepted =
          List<String>.from((c['accepted_user_ids'] as List?) ?? const []);
      if (!accepted.contains(me)) pending.add(c);
    }
    if (pending.isEmpty) return [];

    final taskIds = pending.map((c) => c['task_id']).whereType<String>().toList();
    final ownerIds = pending.map((c) => c['owner_id']).whereType<String>().toSet().toList();
    final tasks = taskIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await client.from('tasks').select('id, title, scheduled_time')
                .inFilter('id', taskIds));
    final taskById = {for (final t in tasks) t['id']: t};
    final owners = ownerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await client.from('users').select('id, email, username')
                .inFilter('id', ownerIds));
    final ownerById = {for (final o in owners) o['id']: o};

    final out = <Map<String, dynamic>>[];
    for (final c in pending) {
      final task = taskById[c['task_id']];
      if (task == null) continue; // task deleted — nothing to show
      final owner = ownerById[c['owner_id']];
      final handle = (owner?['username'] as String?)?.isNotEmpty == true
          ? '@${owner!['username']}'
          : (owner?['email'] as String? ?? 'a friend');
      out.add({...c, '_task': task, '_owner': handle});
    }
    return out;
  }

  static Future<int> pendingTaskInviteCount() async =>
      (await getPendingTaskInvites()).length;

  /// Accept a task invite — only now does it join my active task list.
  static Future<void> acceptTaskInvite(String collaborationId) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    final row = await client.from('collaborations')
        .select('accepted_user_ids').eq('id', collaborationId).maybeSingle();
    final accepted = List<String>.from((row?['accepted_user_ids'] as List?) ?? const []);
    if (!accepted.contains(me)) accepted.add(me);
    await client.from('collaborations')
        .update({'accepted_user_ids': accepted}).eq('id', collaborationId);
    bumpData();
  }

  /// Decline a task invite — removes me from it entirely; it never resurfaces.
  static Future<void> declineTaskInvite(String collaborationId) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    final row = await client.from('collaborations')
        .select('invited_user_ids').eq('id', collaborationId).maybeSingle();
    final invited = List<String>.from((row?['invited_user_ids'] as List?) ?? const []);
    invited.remove(me);
    await client.from('collaborations')
        .update({'invited_user_ids': invited}).eq('id', collaborationId);
  }

  /// Tasks other people have shared with me AND I've accepted, scheduled on
  /// [date]. Each row gets a `_shared_by` email for display.
  static Future<List<Map<String, dynamic>>> getSharedTasksForDate(DateTime date) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];
    final collabs = List<Map<String, dynamic>>.from(
      await client.from('collaborations')
          .select('task_id, owner_id')
          .contains('accepted_user_ids', [me]),
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

  // ── Friend groups ──────────────────────────────────────
  // Named groups (e.g. "Family") so a whole set of friends can be invited to a
  // task at once. Owner-only (RLS); member_ids are friend user ids.

  static Future<List<Map<String, dynamic>>> getFriendGroups() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return [];
    final res = await client
        .from('friend_groups')
        .select()
        .eq('owner_id', me)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> createFriendGroup(
      String name, List<String> memberIds) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return;
    await client.from('friend_groups').insert({
      'owner_id': me,
      'name': name,
      'member_ids': memberIds,
    });
  }

  static Future<void> updateFriendGroup(
      String groupId, {String? name, List<String>? memberIds}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (memberIds != null) data['member_ids'] = memberIds;
    if (data.isEmpty) return;
    await client.from('friend_groups').update(data).eq('id', groupId);
  }

  static Future<void> deleteFriendGroup(String groupId) async {
    await client.from('friend_groups').delete().eq('id', groupId);
  }
}

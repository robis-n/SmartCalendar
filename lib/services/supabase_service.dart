import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ── Tasks ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTodayTasks() async {
    return getTasksForDate(DateTime.now());
  }

  static Future<List<Map<String, dynamic>>> getTasksForDate(DateTime date) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
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
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();
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
    final now = DateTime.now().toIso8601String();
    final future = DateTime.now().add(const Duration(hours: 24)).toIso8601String();
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
        'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  static Future<void> deleteTask(String taskId) async {
    await client.from('task_verifications').delete().eq('task_id', taskId);
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
      final d = DateTime.tryParse(t['scheduled_time']);
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

  // ── Friends ────────────────────────────────────────────

  static Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    final myId = client.auth.currentUser?.id;
    final res = await client
        .from('users')
        .select('id, email')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();
    if (res == null) return null;
    if (res['id'] == myId) return null; // can't add yourself
    return res;
  }

  static Future<List<Map<String, dynamic>>> getFriendships() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final res = await client
        .from('friendships')
        .select('id, status, created_at, requester_id, addressee_id, requester:users!friendships_requester_id_fkey(id, email), addressee:users!friendships_addressee_id_fkey(id, email)')
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
        .select('id, title, status, created_at, creator_id, partner_id, creator:users!challenges_creator_id_fkey(id, email), partner:users!challenges_partner_id_fkey(id, email)')
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
}

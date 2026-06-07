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

  /// Returns all tasks for a given month — used by calendar to show dots
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

  /// Returns all upcoming pending tasks (for notification scheduling)
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

  static Future<void> updateTaskStatus(String taskId, String status) async {
    await client.from('tasks').update({
      'status': status,
      if (status == 'verified' || status == 'failed')
        'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
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
}

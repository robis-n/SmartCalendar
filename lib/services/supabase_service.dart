import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // Tasks
  static Future<List<Map<String, dynamic>>> getTodayTasks() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final res = await client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .gte('scheduled_time', startOfDay)
        .lte('scheduled_time', endOfDay)
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
      if (status == 'verified') 'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  // Verifications
  static Future<void> saveVerification(Map<String, dynamic> verification) async {
    await client.from('task_verifications').insert(verification);
  }

  // User profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    final res = await client.from('users').select().eq('id', userId).maybeSingle();
    return res;
  }

  static Future<void> upsertUserProfile(Map<String, dynamic> data) async {
    await client.from('users').upsert(data);
  }

  // Storage — upload verification photo
  static Future<String> uploadVerificationPhoto(String taskId, List<int> bytes, String ext) async {
    final path = 'verifications/$taskId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from('verification-photos').uploadBinary(path, bytes);
    return client.storage.from('verification-photos').createSignedUrl(path, 3600);
  }
}

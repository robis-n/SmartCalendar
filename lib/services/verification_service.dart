import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_verification_service.dart';

/// Hybrid photo verification.
///
/// 1. **Claude vision** via the `verify-photo` Supabase Edge Function — real
///    image understanding. Requires the ANTHROPIC_API_KEY secret to be set on
///    the Supabase project; until then the function answers 503/no_key.
/// 2. **On-device ML Kit** fallback — keyword/label matching. Used whenever
///    the edge function is unavailable, errors, or has no key.
class VerificationService {
  final _local = LocalVerificationService();

  Future<Map<String, dynamic>> verifyPhoto({
    required String taskTitle,
    String? taskDescription,
    required String imagePath,
    required Uint8List imageBytes,
  }) async {
    final ai = await _tryCloudVerify(
        taskTitle: taskTitle, taskDescription: taskDescription, bytes: imageBytes);
    if (ai != null) return ai;
    return _local.verifyPhoto(
        taskTitle: taskTitle, taskDescription: taskDescription, imagePath: imagePath);
  }

  Future<Map<String, dynamic>?> _tryCloudVerify({
    required String taskTitle,
    String? taskDescription,
    required Uint8List bytes,
  }) async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke('verify-photo', body: {
        'task_title': taskTitle,
        if (taskDescription != null && taskDescription.isNotEmpty)
          'task_description': taskDescription,
        'image_base64': base64Encode(bytes),
        'media_type': 'image/jpeg',
      });
      final data = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : Map<String, dynamic>.from(jsonDecode(res.data as String) as Map);
      if (data['verified'] is! bool) return null; // no_key / error shape
      return {
        'verified': data['verified'],
        'confidence': (data['confidence'] as num?)?.toDouble() ?? 0.0,
        'feedback': data['feedback'] ?? '',
        'labels': 'ai',
        'source': 'ai',
      };
    } catch (_) {
      // Function missing, no key, network issue — fall through to local.
      return null;
    }
  }
}

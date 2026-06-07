import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/constants/app_constants.dart';

class ClaudeService {
  static final ClaudeService _instance = ClaudeService._internal();
  factory ClaudeService() => _instance;
  ClaudeService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.anthropic.com/v1',
    headers: {
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
  ));

  String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  // Schedule a task using Claude
  Future<Map<String, dynamic>> scheduleTask({
    required String title,
    required String description,
    required int estimatedMinutes,
    required List<Map<String, dynamic>> existingTasks,
  }) async {
    final prompt = '''
Existing schedule (next 7 days): ${jsonEncode(existingTasks)}
New task: "$title" — ${description.isNotEmpty ? description : 'no description'} — estimated ${estimatedMinutes}min
Return JSON only: { "scheduled_time": "ISO8601", "reasoning": "max 20 words" }
''';

    final response = await _dio.post('/messages',
      options: Options(headers: {'x-api-key': _apiKey}),
      data: {
        'model': AppConstants.claudeModel,
        'max_tokens': 256,
        'system': 'You are a scheduling AI. Return JSON only. No markdown. No explanation.',
        'messages': [{'role': 'user', 'content': prompt}],
      },
    );

    final text = response.data['content'][0]['text'] as String;
    return jsonDecode(text.trim());
  }

  // Verify task completion from photo (base64)
  Future<Map<String, dynamic>> verifyPhoto({
    required String taskTitle,
    required String base64Image,
    required String mediaType,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(headers: {'x-api-key': _apiKey}),
      data: {
        'model': AppConstants.claudeModel,
        'max_tokens': 256,
        'system': 'You are a task verification AI. Return JSON only. No markdown.',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': base64Image,
                },
              },
              {
                'type': 'text',
                'text': 'Task: "$taskTitle". Is the user performing or has completed this task? Return JSON: { "verified": bool, "confidence": 0.0-1.0, "feedback": "max 15 words" }',
              },
            ],
          }
        ],
      },
    );

    final text = response.data['content'][0]['text'] as String;
    return jsonDecode(text.trim());
  }

  // Get AI task suggestions for free time gaps
  Future<List<Map<String, dynamic>>> suggestTasks({
    required String userPreferences,
    required List<Map<String, dynamic>> freeGaps,
  }) async {
    final response = await _dio.post('/messages',
      options: Options(headers: {'x-api-key': _apiKey}),
      data: {
        'model': AppConstants.claudeModel,
        'max_tokens': 512,
        'system': 'You are a productivity AI. Return JSON array only.',
        'messages': [
          {
            'role': 'user',
            'content': 'Free time gaps today: ${jsonEncode(freeGaps)}\nUser preferences: $userPreferences\nSuggest 1-3 tasks. Return: [{"title": str, "duration_min": int, "category": str}]',
          }
        ],
      },
    );

    final text = response.data['content'][0]['text'] as String;
    return List<Map<String, dynamic>>.from(jsonDecode(text.trim()));
  }
}

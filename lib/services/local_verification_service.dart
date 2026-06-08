import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// On-device photo verification using Google ML Kit image labeling.
/// No API key required — runs 100% locally on the device.
class LocalVerificationService {
  // ── Synonym map ───────────────────────────────────────────────────────────
  // Maps task-title keywords → ML Kit label words they might match.
  static const Map<String, List<String>> _synonyms = {
    // ── Fitness / exercise ────────────────
    'run':       ['running', 'jogging', 'athletics', 'road', 'track', 'exercise', 'sport', 'outdoor'],
    'running':   ['running', 'jogging', 'athletics', 'road', 'track', 'exercise'],
    'jog':       ['running', 'jogging', 'exercise', 'road', 'outdoor'],
    'gym':       ['gym', 'workout', 'dumbbell', 'weight', 'fitness', 'exercise', 'physical fitness'],
    'workout':   ['gym', 'exercise', 'dumbbell', 'weight', 'fitness', 'physical fitness'],
    'exercise':  ['exercise', 'sport', 'gym', 'fitness', 'running', 'yoga', 'weight'],
    'yoga':      ['yoga', 'exercise', 'fitness', 'stretching', 'mat'],
    'swim':      ['swimming', 'pool', 'water', 'sport', 'exercise'],
    'swimming':  ['swimming', 'pool', 'water', 'sport'],
    'walk':      ['walking', 'road', 'outdoor', 'path', 'nature', 'footwear', 'street'],
    'bike':      ['cycling', 'bicycle', 'bike', 'outdoor', 'road', 'sport'],
    'cycling':   ['cycling', 'bicycle', 'bike', 'outdoor', 'road'],
    'hike':      ['hiking', 'mountain', 'outdoor', 'nature', 'trail', 'forest'],
    'stretch':   ['stretching', 'yoga', 'exercise', 'fitness'],
    'pushup':    ['exercise', 'physical fitness', 'gym', 'floor', 'workout'],
    'squat':     ['exercise', 'physical fitness', 'gym', 'workout'],

    // ── Food / cooking ────────────────────
    'cook':      ['cooking', 'food', 'kitchen', 'meal', 'ingredient', 'recipe', 'dish', 'cuisine'],
    'cooking':   ['cooking', 'food', 'kitchen', 'meal', 'ingredient', 'recipe'],
    'bake':      ['baking', 'food', 'kitchen', 'bread', 'cake', 'pastry', 'oven'],
    'baking':    ['baking', 'food', 'kitchen', 'bread', 'cake', 'pastry', 'oven'],
    'eat':       ['food', 'meal', 'eating', 'dish', 'restaurant', 'table'],
    'dinner':    ['food', 'meal', 'dish', 'cooking', 'table', 'plate'],
    'lunch':     ['food', 'meal', 'dish', 'eating', 'plate'],
    'breakfast': ['food', 'meal', 'morning', 'plate', 'egg', 'bread'],
    'meal':      ['food', 'meal', 'dish', 'plate', 'cooking'],
    'grocery':   ['grocery', 'supermarket', 'shopping', 'food', 'store'],

    // ── Study / work ──────────────────────
    'study':     ['book', 'studying', 'reading', 'education', 'desk', 'notes', 'pen', 'paper', 'textbook'],
    'read':      ['book', 'reading', 'literature', 'text', 'library', 'page'],
    'reading':   ['book', 'reading', 'literature', 'text', 'library', 'page'],
    'book':      ['book', 'reading', 'literature', 'textbook'],
    'work':      ['computer', 'desk', 'office', 'laptop', 'technology', 'document'],
    'code':      ['computer', 'technology', 'programming', 'laptop', 'screen', 'software'],
    'coding':    ['computer', 'technology', 'programming', 'laptop', 'screen'],
    'write':     ['writing', 'pen', 'notebook', 'paper', 'desk', 'laptop', 'computer'],
    'writing':   ['writing', 'pen', 'notebook', 'paper', 'desk'],
    'meeting':   ['conference', 'meeting', 'office', 'desk', 'computer', 'people'],
    'present':   ['presentation', 'screen', 'projector', 'conference', 'people'],

    // ── Clean / tidy ──────────────────────
    'clean':     ['cleaning', 'floor', 'room', 'vacuum', 'broom', 'mop', 'housekeeping'],
    'cleaning':  ['cleaning', 'floor', 'room', 'vacuum', 'broom', 'mop'],
    'wash':      ['washing', 'water', 'sink', 'laundry', 'dishes', 'soap'],
    'laundry':   ['laundry', 'washing machine', 'clothes', 'washing', 'detergent'],
    'dishes':    ['dishes', 'sink', 'washing', 'kitchen', 'water', 'dishwasher'],
    'tidy':      ['room', 'floor', 'furniture', 'house', 'cleaning'],
    'organise':  ['room', 'shelf', 'furniture', 'desk', 'box', 'storage'],
    'organize':  ['room', 'shelf', 'furniture', 'desk', 'box', 'storage'],

    // ── Sleep / rest / mental ─────────────
    'sleep':     ['sleeping', 'bed', 'bedroom', 'pillow', 'rest', 'room'],
    'nap':       ['bed', 'sleeping', 'pillow', 'room', 'rest'],
    'meditate':  ['meditation', 'yoga', 'mindfulness', 'relaxation', 'sitting', 'mat'],
    'relax':     ['relaxation', 'rest', 'couch', 'bed', 'room'],

    // ── Social / outside ──────────────────
    'meet':      ['people', 'friends', 'social', 'meeting', 'group', 'smile', 'event'],
    'friends':   ['people', 'friends', 'social', 'group', 'smile', 'outdoor'],
    'shopping':  ['shopping', 'store', 'mall', 'retail', 'bag', 'product'],
    'drive':     ['car', 'driving', 'road', 'vehicle', 'automotive'],
    'travel':    ['travel', 'airport', 'airplane', 'suitcase', 'hotel', 'outdoor', 'city'],

    // ── General ───────────────────────────
    'photo':     [],  // generic — any photo counts
    'picture':   [],
    'selfie':    ['person', 'face', 'selfie'],
    'outside':   ['outdoor', 'nature', 'sky', 'road', 'plant'],
    'outdoor':   ['outdoor', 'nature', 'sky', 'road', 'plant'],
  };

  // ── Stop words (ignored when parsing title) ────────────────────────────────
  static const _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to',
    'for', 'of', 'with', 'my', 'your', 'i', 'me', 'it', 'is', 'do',
    'go', 'get', 'make', 'take', 'have', 'has', 'be', 'are', 'was',
    'some', 'this', 'that', 'by', 'up', 'out', 'new', 'all',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Verify a photo against [taskTitle].
  /// Returns: { verified, confidence (0–1), feedback, labels (comma list) }
  Future<Map<String, dynamic>> verifyPhoto({
    required String taskTitle,
    required String imagePath,
  }) async {
    // Web: ML Kit is not supported — auto-approve so the flow still works
    if (kIsWeb) {
      return {
        'verified': true,
        'confidence': 1.0,
        'feedback': 'Photo accepted (web preview mode)',
        'labels': 'web',
      };
    }

    // Guard: file must exist
    if (!File(imagePath).existsSync()) {
      return {
        'verified': false,
        'confidence': 0.0,
        'feedback': 'Could not read photo file.',
        'labels': '',
      };
    }

    // ── Run ML Kit image labeling ──────────────────────────────────────────
    final inputImage = InputImage.fromFilePath(imagePath);
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.4),
    );

    List<ImageLabel> rawLabels = [];
    try {
      rawLabels = await labeler.processImage(inputImage);
    } finally {
      await labeler.close();
    }

    if (rawLabels.isEmpty) {
      return {
        'verified': false,
        'confidence': 0.0,
        'feedback': 'No objects detected in photo.',
        'labels': '',
      };
    }

    // Sort by confidence descending
    rawLabels.sort((a, b) => b.confidence.compareTo(a.confidence));

    final topLabels = rawLabels.take(6).map((l) => l.label).join(', ');

    // ── Keyword extraction from task title ────────────────────────────────
    final keywords = _extractKeywords(taskTitle);

    // ── Match labels against keywords ─────────────────────────────────────
    double bestScore = 0.0;
    String bestLabelText  = '';
    String bestKeyword    = '';

    for (final label in rawLabels) {
      final lText = label.label.toLowerCase();
      for (final kw in keywords) {
        if (_isMatch(lText, kw)) {
          if (label.confidence > bestScore) {
            bestScore     = label.confidence;
            bestLabelText = label.label;
            bestKeyword   = kw;
          }
        }
      }
    }

    // ── Decision ──────────────────────────────────────────────────────────
    const threshold = 0.50; // minimum confidence to auto-verify

    if (bestScore >= threshold) {
      return {
        'verified':   true,
        'confidence': bestScore,
        'feedback':   'Detected "$bestLabelText" — matches "$bestKeyword" ✓',
        'labels':     topLabels,
      };
    }

    // Softer pass: multiple weak matches
    final weakScore = _weakMatchScore(rawLabels, keywords);
    if (weakScore >= 0.45) {
      return {
        'verified':   true,
        'confidence': weakScore,
        'feedback':   'Task confirmed from context. Detected: $topLabels',
        'labels':     topLabels,
      };
    }

    // Failed — show what was detected so user can retake
    return {
      'verified':   false,
      'confidence': bestScore,
      'feedback':   'Could not confirm task. Detected: $topLabels. Try a clearer photo.',
      'labels':     topLabels,
    };
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Extract meaningful lowercase tokens from the task title.
  Set<String> _extractKeywords(String title) {
    final words = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();

    // Expand with synonyms
    final expanded = <String>{};
    for (final w in words) {
      expanded.add(w);
      if (_synonyms.containsKey(w)) {
        expanded.addAll(_synonyms[w]!);
      }
    }
    return expanded;
  }

  /// True if [labelText] contains or equals [keyword] (or vice-versa).
  bool _isMatch(String labelText, String keyword) {
    if (keyword.isEmpty) return false;
    if (labelText == keyword) return true;
    if (labelText.contains(keyword)) return true;
    if (keyword.contains(labelText)) return true;
    return false;
  }

  /// Accumulate weak signal: sum of (confidence × partial match) across labels.
  double _weakMatchScore(List<ImageLabel> labels, Set<String> keywords) {
    double sum = 0.0;
    for (final label in labels) {
      final lText = label.label.toLowerCase();
      for (final kw in keywords) {
        if (_isMatch(lText, kw)) {
          sum += label.confidence * 0.5; // partial credit
        }
      }
    }
    return sum.clamp(0.0, 1.0);
  }
}

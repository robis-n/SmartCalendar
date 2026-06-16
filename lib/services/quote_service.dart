import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/theme/theme_provider.dart' show kSettingsBox, quoteOfTheDay;

/// Fetches a real "quote of the day" from a free, keyless API (ZenQuotes —
/// the same quote for everyone each day) instead of picking from a fixed
/// local list. The result is cached in Hive for the rest of the day, so Home
/// only hits the network once daily, not on every rebuild. Falls back to the
/// offline rotation in [quoteOfTheDay] on any network/parse failure — a quote
/// always shows, live or not.
class QuoteService {
  QuoteService._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static const _keyDate = 'daily_quote_date';
  static const _keyText = 'daily_quote_text';

  static String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static Future<String> todayQuote() async {
    final todayKey = _dateKey(DateTime.now());
    try {
      final box = Hive.box(kSettingsBox);
      if (box.get(_keyDate) == todayKey) {
        final cached = box.get(_keyText) as String?;
        if (cached != null && cached.isNotEmpty) return cached;
      }
    } catch (_) {/* Hive unavailable — just fetch fresh below */}

    try {
      final res = await _dio.get<List<dynamic>>(
        'https://zenquotes.io/api/today',
        options: Options(responseType: ResponseType.json),
      );
      final data = res.data;
      if (data != null && data.isNotEmpty) {
        final row = data[0] as Map;
        final q = row['q'] as String?;
        final a = row['a'] as String?;
        if (q != null && q.trim().isNotEmpty) {
          final text = (a != null && a.trim().isNotEmpty)
              ? '$q — $a'
              : q;
          try {
            final box = Hive.box(kSettingsBox);
            await box.put(_keyDate, todayKey);
            await box.put(_keyText, text);
          } catch (_) {/* best-effort cache */}
          return text;
        }
      }
    } catch (_) {/* offline / API down — fall through */}

    return quoteOfTheDay();
  }
}

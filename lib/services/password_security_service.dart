import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Password hygiene checks done client-side, for free — the same protection
/// Supabase offers on its Pro plan, without the plan.
///
/// [pwnedCount] uses HaveIBeenPwned's "Pwned Passwords" range API with
/// **k-anonymity**: we hash the password with SHA-1, send only the first FIVE
/// hex characters of that hash, and match the rest locally against the
/// returned suffixes. The password itself — and even its full hash — never
/// leave the device. The call fails OPEN (returns 0) on any network/parse
/// error so a connectivity blip can never lock someone out of signing up.
class PasswordSecurity {
  PasswordSecurity._();

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  /// Local strength rule. Returns a short error message, or null if acceptable.
  static String? weakness(String pw) {
    if (pw.length < 8) return 'Use at least 8 characters';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(pw);
    final hasDigit = RegExp(r'\d').hasMatch(pw);
    if (!hasLetter || !hasDigit) return 'Mix letters and numbers';
    return null;
  }

  /// How many known breaches this password appears in (0 = not found / unknown).
  static Future<int> pwnedCount(String password) async {
    try {
      final hash =
          sha1.convert(utf8.encode(password)).toString().toUpperCase();
      final prefix = hash.substring(0, 5);
      final suffix = hash.substring(5);
      final res = await _dio.get<String>(
        'https://api.pwnedpasswords.com/range/$prefix',
        options: Options(responseType: ResponseType.plain),
      );
      final body = res.data ?? '';
      for (final line in const LineSplitter().convert(body)) {
        final i = line.indexOf(':');
        if (i <= 0) continue;
        if (line.substring(0, i).trim() == suffix) {
          return int.tryParse(line.substring(i + 1).trim()) ?? 1;
        }
      }
      return 0;
    } catch (_) {
      return 0; // fail open — never block sign-up on a network hiccup
    }
  }
}

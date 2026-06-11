import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Multi-account support: remembers every account that signs in on this
/// device so the user can switch without retyping credentials.
///
/// We never store passwords — only the latest refresh token per account.
/// Supabase rotates refresh tokens on every refresh, so [saveCurrent] is
/// called from an auth-state listener (see main.dart) to always hold the
/// newest one. Switching = `auth.setSession(storedRefreshToken)`.
class AccountManager {
  static const String kAccountsBox = 'accounts';

  static Box get _box => Hive.box(kAccountsBox);

  static SupabaseClient get _client => Supabase.instance.client;

  /// Persist (or refresh) the entry for the currently signed-in session.
  static Future<void> saveCurrent(Session session) async {
    final u = session.user;
    final token = session.refreshToken;
    if (token == null || token.isEmpty) return;
    await _box.put(u.id, {
      'id': u.id,
      'email': u.email ?? '',
      'username': (u.userMetadata?['username'] as String?) ?? '',
      'refresh_token': token,
    });
  }

  /// All remembered accounts, current one first.
  static List<Map<String, dynamic>> accounts() {
    final me = _client.auth.currentUser?.id;
    final all = _box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) => (a['id'] == me ? 0 : 1).compareTo(b['id'] == me ? 0 : 1));
    return all;
  }

  static String? currentUserId() => _client.auth.currentUser?.id;

  /// Switch to a remembered account. Returns null on success, or a
  /// user-readable error. On a dead token the entry is dropped so the UI
  /// can offer a fresh sign-in instead.
  static Future<String?> switchTo(String userId) async {
    final raw = _box.get(userId);
    if (raw == null) return 'Account not found on this device';
    final acc = Map<String, dynamic>.from(raw as Map);
    try {
      final res =
          await _client.auth.setSession(acc['refresh_token'] as String);
      if (res.session == null) throw const AuthException('No session');
      return null;
    } catch (_) {
      await _box.delete(userId);
      return 'Session expired — please sign in to that account again';
    }
  }

  /// Forget a stored account (local only; does not revoke server sessions).
  static Future<void> forget(String userId) async => _box.delete(userId);

  /// Sign out the current account properly: its refresh token is revoked by
  /// signOut, so drop the stored entry too — it would never work again.
  static Future<void> signOutCurrent() async {
    final me = _client.auth.currentUser?.id;
    if (me != null) await _box.delete(me);
    await _client.auth.signOut();
  }
}

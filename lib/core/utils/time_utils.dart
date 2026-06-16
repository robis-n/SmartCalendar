/// Canonical timestamp convention for the whole app.
///
/// Postgres columns are `timestamptz`. A zone-less ISO string (what
/// `DateTime.toIso8601String()` produces for local times) gets interpreted
/// by Postgres as UTC — which silently shifts every schedule by the device's
/// UTC offset. That bug made notifications fire hours late.
///
/// Rule: **send UTC, show local.**
///  - Everything written to the DB goes through [tsToDb].
///  - Everything read from the DB goes through [tsFromDb] / [tsTryFromDb].
library;

String tsToDb(DateTime t) => t.toUtc().toIso8601String();

DateTime tsFromDb(String s) => DateTime.parse(s).toLocal();

DateTime? tsTryFromDb(String? s) =>
    s == null ? null : DateTime.tryParse(s)?.toLocal();

/// Centralised clock-time formatting so the 12h/24h preference applies
/// everywhere from one place. [use24h] is a global flag synced from
/// `timeFormatProvider` in app.dart each frame (same pattern as AppColors).
class TimeFmt {
  TimeFmt._();
  static bool use24h = false;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "14:05" (24h) or "2:05 PM" (12h).
  static String t(DateTime d) {
    if (use24h) return '${_two(d.hour)}:${_two(d.minute)}';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${_two(d.minute)} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// Hour-only label for grids: "14" (24h) or "2 PM" (12h).
  static String hour(int h) {
    if (use24h) return _two(h);
    if (h == 0) return '12 AM';
    if (h == 12) return '12 PM';
    return h < 12 ? '$h AM' : '${h - 12} PM';
  }
}

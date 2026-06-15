import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/theme/theme_provider.dart';

/// A device-calendar event reduced to what the UI needs.
class DeviceEvent {
  final String title;
  final DateTime? start; // device-local
  final DateTime? end;
  final bool allDay;
  final String calendarName;
  final int? color; // ARGB of the owning calendar (ambient tint)
  const DeviceEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.calendarName,
    this.color,
  });
}

/// A writable calendar the user can save events into.
class WritableCalendar {
  final String id;
  final String name;
  final int? color;
  final String kind; // 'apple' | 'google' | 'other'
  const WritableCalendar({
    required this.id,
    required this.name,
    this.color,
    this.kind = 'other',
  });
}

/// One device calendar, surfaced in the visibility chooser.
class DeviceCalendarInfo {
  final String id;
  final String name;
  final bool isReadOnly;
  final bool visible;
  final int? color;
  final String kind; // 'apple' | 'google' | 'other'
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.isReadOnly,
    required this.visible,
    this.color,
    this.kind = 'other',
  });
}

/// Reads (and optionally writes) the phone's native calendars via
/// EventKit (iOS) / CalendarProvider (Android). On iOS this covers
/// Apple Calendar *and* any Google accounts synced to the phone.
class DeviceCalendarService {
  static final _plugin = DeviceCalendarPlugin();

  // Settings are scoped PER ACCOUNT (keyed by the signed-in user id) so a new
  // or switched-to account starts clean — calendars off, nothing inherited
  // from whoever was signed in before. Defaults: off / nothing hidden.
  static String _uid() =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anon';
  static String get _enabledKey => 'show_device_calendars::${_uid()}';
  static String get _hiddenKey => 'hidden_calendar_ids::${_uid()}';

  static bool get enabled =>
      !kIsWeb &&
      (Hive.box(kSettingsBox).get(_enabledKey, defaultValue: false) as bool);

  static Future<void> setEnabled(bool v) async =>
      Hive.box(kSettingsBox).put(_enabledKey, v);

  /// Calendar IDs the user has switched off in the visibility chooser.
  static Set<String> hiddenCalendarIds() {
    final raw = Hive.box(kSettingsBox)
        .get(_hiddenKey, defaultValue: const <String>[]) as List;
    return raw.map((e) => e.toString()).toSet();
  }

  static Future<void> setCalendarHidden(String id, bool hidden) async {
    final set = hiddenCalendarIds();
    if (hidden) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await Hive.box(kSettingsBox).put(_hiddenKey, set.toList());
  }

  // Classify a calendar's owning account so the UI can say "Apple"/"Google".
  // On iOS, Google accounts sync over CalDAV but carry the gmail address as
  // the account name; iCloud shows up as "iCloud".
  static String _kindOf(String? accountName, String? accountType) {
    final n = (accountName ?? '').toLowerCase();
    final t = (accountType ?? '').toLowerCase();
    if (n.contains('google') || n.contains('gmail') || t.contains('google')) {
      return 'google';
    }
    if (n.contains('icloud') ||
        n.contains('apple') ||
        t.contains('local') ||
        t.contains('caldav') ||
        t.contains('exchange') ||
        t.contains('subscribed') ||
        t.contains('birthday')) {
      return 'apple';
    }
    return 'other';
  }

  /// Every calendar on the device, each flagged with its current visibility,
  /// for the "Choose calendars" chooser. Requires permission.
  static Future<List<DeviceCalendarInfo>> allCalendars() async {
    if (kIsWeb) return [];
    try {
      final granted = await ensurePermission();
      if (!granted) return [];
      final cals = await _plugin.retrieveCalendars();
      if (!cals.isSuccess || cals.data == null) return [];
      final hidden = hiddenCalendarIds();
      return cals.data!
          .where((c) => c.id != null)
          .map((c) => DeviceCalendarInfo(
                id: c.id!,
                name: c.name ?? 'Calendar',
                isReadOnly: c.isReadOnly ?? false,
                visible: !hidden.contains(c.id),
                color: c.color,
                kind: _kindOf(c.accountName, c.accountType),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Which account kinds the user actually has writable calendars for —
  /// drives the "Add to Apple/Google Calendar" labelling.
  static Future<Set<String>> writableAccountKinds() async {
    final cals = await writableCalendars();
    return cals.map((c) => c.kind).where((k) => k != 'other').toSet();
  }

  static Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    try {
      var has = await _plugin.hasPermissions();
      if (has.isSuccess && (has.data ?? false)) return true;
      final req = await _plugin.requestPermissions();
      return req.isSuccess && (req.data ?? false);
    } catch (_) {
      return false;
    }
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  /// All events for a single day, sorted by start time.
  static Future<List<DeviceEvent>> eventsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end   = start.add(const Duration(days: 1));
    return _eventsForRange(start, end);
  }

  /// All events across a Mon-anchored week (home agenda).
  static Future<List<DeviceEvent>> eventsForWeek(DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _eventsForRange(start, start.add(const Duration(days: 7)));
  }

  /// All events across a whole calendar month (used for chip rendering).
  static Future<List<DeviceEvent>> eventsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end   = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return _eventsForRange(start, end);
  }

  static Future<List<DeviceEvent>> _eventsForRange(
      DateTime start, DateTime end) async {
    if (kIsWeb || !enabled) return [];
    try {
      final cals = await _plugin.retrieveCalendars();
      if (!cals.isSuccess || cals.data == null) return [];
      final hidden = hiddenCalendarIds();
      final out = <DeviceEvent>[];
      for (final cal in cals.data!) {
        if (cal.id == null || hidden.contains(cal.id)) continue;
        final res = await _plugin.retrieveEvents(
          cal.id,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        if (!res.isSuccess || res.data == null) continue;
        for (final e in res.data!) {
          out.add(DeviceEvent(
            title: e.title ?? '(untitled)',
            start: e.start?.toLocal(),
            end:   e.end?.toLocal(),
            allDay: e.allDay ?? false,
            calendarName: cal.name ?? '',
            color: cal.color,
          ));
        }
      }
      out.sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return (a.start ?? DateTime(0)).compareTo(b.start ?? DateTime(0));
      });
      return out;
    } catch (_) {
      return [];
    }
  }

  // ── Write ────────────────────────────────────────────────────────────────

  /// Non-read-only calendars the user can write events into.
  static Future<List<WritableCalendar>> writableCalendars() async {
    if (kIsWeb) return [];
    try {
      final granted = await ensurePermission();
      if (!granted) return [];
      final cals = await _plugin.retrieveCalendars();
      if (!cals.isSuccess || cals.data == null) return [];
      return cals.data!
          .where((c) => c.id != null && !(c.isReadOnly ?? true))
          .map((c) => WritableCalendar(
                id: c.id!,
                name: c.name ?? 'Calendar',
                color: c.color,
                kind: _kindOf(c.accountName, c.accountType),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete an event we previously created (used when a reminder is completed
  /// or deleted, so its synced copy disappears from Apple/Google). Best-effort.
  static Future<void> deleteEvent(String calendarId, String eventId) async {
    if (kIsWeb) return;
    try {
      await _plugin.deleteEvent(calendarId, eventId);
    } catch (_) {/* already gone / no permission — ignore */}
  }

  /// Delete every device event linked to a reminder (the `device_events`
  /// jsonb list of {cal, ev}). Used on completion/deletion.
  static Future<void> deleteLinkedEvents(List<dynamic> linked) async {
    for (final e in linked) {
      if (e is Map) {
        final cal = e['cal']; final ev = e['ev'];
        if (cal is String && ev is String) await deleteEvent(cal, ev);
      }
    }
  }

  /// Creates an event in [calendarId]. Returns the new event ID or null.
  static Future<String?> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    if (kIsWeb) return null;
    try {
      final event = Event(calendarId)
        ..title = title
        ..start = tz.TZDateTime.from(start, tz.local)
        ..end   = tz.TZDateTime.from(end, tz.local)
        ..description = description;
      final result = await _plugin.createOrUpdateEvent(event);
      if (result == null || !result.isSuccess) return null;
      return result.data;
    } catch (_) {
      return null;
    }
  }
}

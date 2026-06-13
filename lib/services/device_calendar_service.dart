import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/theme/theme_provider.dart';

/// A device-calendar event reduced to what the UI needs.
class DeviceEvent {
  final String title;
  final DateTime? start; // device-local
  final DateTime? end;
  final bool allDay;
  final String calendarName;
  const DeviceEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.calendarName,
  });
}

/// A writable calendar the user can save events into.
class WritableCalendar {
  final String id;
  final String name;
  const WritableCalendar({required this.id, required this.name});
}

/// One device calendar, surfaced in the visibility chooser.
class DeviceCalendarInfo {
  final String id;
  final String name;
  final bool isReadOnly;
  final bool visible;
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.isReadOnly,
    required this.visible,
  });
}

/// Reads (and optionally writes) the phone's native calendars via
/// EventKit (iOS) / CalendarProvider (Android). On iOS this covers
/// Apple Calendar *and* any Google accounts synced to the phone.
class DeviceCalendarService {
  static const String kShowDeviceCalendarsKey = 'show_device_calendars';
  // IDs the user has explicitly hidden. Anything *not* in here is shown,
  // so newly-synced calendars appear by default (matches Apple Calendar).
  static const String kHiddenCalendarsKey = 'hidden_calendar_ids';
  static final _plugin = DeviceCalendarPlugin();

  static bool get enabled =>
      !kIsWeb &&
      (Hive.box(kSettingsBox).get(kShowDeviceCalendarsKey, defaultValue: false)
          as bool);

  static Future<void> setEnabled(bool v) async =>
      Hive.box(kSettingsBox).put(kShowDeviceCalendarsKey, v);

  /// Calendar IDs the user has switched off in the visibility chooser.
  static Set<String> hiddenCalendarIds() {
    final raw = Hive.box(kSettingsBox)
        .get(kHiddenCalendarsKey, defaultValue: const <String>[]) as List;
    return raw.map((e) => e.toString()).toSet();
  }

  static Future<void> setCalendarHidden(String id, bool hidden) async {
    final set = hiddenCalendarIds();
    if (hidden) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await Hive.box(kSettingsBox).put(kHiddenCalendarsKey, set.toList());
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
              ))
          .toList();
    } catch (_) {
      return [];
    }
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
          .map((c) => WritableCalendar(id: c.id!, name: c.name ?? 'Calendar'))
          .toList();
    } catch (_) {
      return [];
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

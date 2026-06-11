import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
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

/// Reads the phone's calendars via EventKit (iOS) / CalendarProvider
/// (Android). On iOS this includes Apple Calendar *and* any Google accounts
/// the user has synced to the phone — one integration covers both.
///
/// Read-only: tasks never leak into the user's external calendars.
class DeviceCalendarService {
  static const String kShowDeviceCalendarsKey = 'show_device_calendars';

  static final _plugin = DeviceCalendarPlugin();

  /// User-facing toggle, persisted in the settings box.
  static bool get enabled =>
      !kIsWeb &&
      (Hive.box(kSettingsBox).get(kShowDeviceCalendarsKey, defaultValue: false)
          as bool);

  static Future<void> setEnabled(bool v) async =>
      Hive.box(kSettingsBox).put(kShowDeviceCalendarsKey, v);

  /// Ask for calendar permission. Returns true when granted.
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

  /// All device events overlapping [day] (device-local), across every
  /// calendar on the phone, sorted by start time.
  static Future<List<DeviceEvent>> eventsForDay(DateTime day) async {
    if (kIsWeb || !enabled) return [];
    try {
      final cals = await _plugin.retrieveCalendars();
      if (!cals.isSuccess || cals.data == null) return [];

      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final out = <DeviceEvent>[];

      for (final cal in cals.data!) {
        if (cal.id == null) continue;
        final res = await _plugin.retrieveEvents(
          cal.id,
          RetrieveEventsParams(startDate: dayStart, endDate: dayEnd),
        );
        if (!res.isSuccess || res.data == null) continue;
        for (final e in res.data!) {
          out.add(DeviceEvent(
            title: e.title ?? '(untitled)',
            start: e.start?.toLocal(),
            end: e.end?.toLocal(),
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
}

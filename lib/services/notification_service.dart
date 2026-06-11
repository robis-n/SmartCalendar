import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../core/utils/time_utils.dart';

/// Reminder engine.
///
/// Priority means *how hard the app nudges*, not abstract importance:
///   low    (Gentle)     → one quiet ping at the deadline.
///   medium (Normal)     → heads-up before + deadline + a couple follow-ups.
///   high   (Persistent) → heads-up + deadline + escalating follow-ups
///                         (+30s, +2m, +5m, +15m, +30m) until the app is opened.
///
/// Follow-ups self-destruct when the user opens the app: every dashboard load
/// calls [rescheduleAll], which cancels everything and re-arms only tasks whose
/// deadline is still in the future — so overdue follow-ups simply vanish.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Callback — set by app to open verification screen
  static void Function(String taskId, String taskTitle)? onVerificationRequired;

  // How many minutes before deadline to show the warning — updated from Settings
  static int leadMinutes = 15;

  // Per-task notification id slots: +0 warning, +1 deadline, +2.. follow-ups.
  static const int _slotsPerTask = 8;

  // Follow-up offsets after the deadline, by priority. iOS allows only 64
  // pending local notifications app-wide, so these are deliberately capped.
  static const Map<String, List<Duration>> _followUps = {
    'low': [],
    'medium': [
      Duration(seconds: 30),
      Duration(minutes: 10),
    ],
    'high': [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 5),
      Duration(minutes: 15),
      Duration(minutes: 30),
    ],
  };

  static const List<String> _followUpLines = [
    'Still there. Open the app and prove it.',
    'Your task is waiting.',
    'This one is overdue.',
    'Not letting this slide.',
    'Last call — do it now.',
  ];

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null && payload.contains('|')) {
          final parts = payload.split('|');
          if (parts.length >= 2) {
            onVerificationRequired?.call(parts[0], parts[1]);
          }
        }
      },
    );

    // Request iOS permissions
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// Arm all reminders for one task. [deadline] must be device-local time
  /// (i.e. parsed via [tsFromDb]) — it is converted to an absolute instant.
  Future<int> scheduleTaskNotifications({
    required String taskId,
    required String taskTitle,
    required DateTime deadline,
    String priority = 'medium',
  }) async {
    if (kIsWeb || !_initialized) return 0;

    final now = DateTime.now();
    await cancelTaskNotifications(taskId);

    final idBase = (taskId.hashCode.abs() % 100000) * _slotsPerTask;
    var scheduled = 0;

    Future<void> arm(int slot, DateTime at, String title, String body) async {
      if (!at.isAfter(now)) return;
      await _plugin.zonedSchedule(
        idBase + slot,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        _notifDetails(warning: slot == 0),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$taskId|$taskTitle',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      scheduled++;
    }

    // Heads-up before the deadline — only for medium/high.
    if (priority != 'low') {
      await arm(0, deadline.subtract(Duration(minutes: leadMinutes)),
          'Coming up in $leadMinutes min', taskTitle);
    }

    // The deadline itself.
    await arm(1, deadline, "Time's up — prove it", taskTitle);

    // Escalating follow-ups. They only exist while the app stays closed:
    // opening the app triggers rescheduleAll, which wipes them once the
    // deadline is in the past.
    final fups = _followUps[priority] ?? const <Duration>[];
    for (var i = 0; i < fups.length; i++) {
      await arm(2 + i, deadline.add(fups[i]),
          _followUpLines[i % _followUpLines.length], taskTitle);
    }
    return scheduled;
  }

  /// Cancel all notification slots for a specific task.
  Future<void> cancelTaskNotifications(String taskId) async {
    if (kIsWeb) return;
    final idBase = (taskId.hashCode.abs() % 100000) * _slotsPerTask;
    for (var i = 0; i < _slotsPerTask; i++) {
      await _plugin.cancel(idBase + i);
    }
  }

  /// Cancel ALL notifications
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Re-arm reminders for all upcoming pending tasks. Called on every app
  /// open / dashboard refresh — this is also what silences overdue follow-up
  /// nudges (their deadline is in the past, so they are not re-created).
  ///
  /// iOS caps pending local notifications at 64 app-wide; stop short of it.
  Future<void> rescheduleAll(List<Map<String, dynamic>> tasks) async {
    if (kIsWeb) return;
    await cancelAll();
    var total = 0;
    for (final task in tasks) {
      if (task['scheduled_time'] == null) continue;
      final deadline = tsTryFromDb(task['scheduled_time'] as String?);
      if (deadline == null || deadline.isBefore(DateTime.now())) continue;
      total += await scheduleTaskNotifications(
        taskId: task['id'],
        taskTitle: task['title'] ?? 'Task',
        deadline: deadline,
        priority: task['priority'] as String? ?? 'medium',
      );
      if (total >= 56) break;
    }
  }

  // ── Notification style ────────────────────────────────────────────────────
  // Safety: a single dismissable, polite ping. Never `ongoing`, never
  // `Importance.max` (forced alarm channel), never re-alerting on re-post.
  // "Persistent" pressure comes from *separate scheduled follow-ups*, each
  // individually dismissable — not from one un-dismissable notification.
  NotificationDetails _notifDetails({required bool warning}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        warning ? 'task_warning' : 'task_deadline',
        warning ? 'Task Warnings' : 'Task Deadlines',
        channelDescription: warning
            ? 'Reminder before a task deadline'
            : 'When a task deadline is reached',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
        autoCancel: true,
        onlyAlertOnce: true,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
        actions: warning
            ? null
            : [
                const AndroidNotificationAction('verify', 'Verify',
                    showsUserInterface: true),
              ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // `active`, not `timeSensitive` / `critical` — those bypass focus modes.
        interruptionLevel: InterruptionLevel.active,
        categoryIdentifier: 'TASK_DEADLINE',
      ),
    );
  }
}

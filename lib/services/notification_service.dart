import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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

  /// Schedule a 15-minute warning + deadline notification for a task
  Future<void> scheduleTaskNotifications({
    required String taskId,
    required String taskTitle,
    required DateTime deadline,
  }) async {
    if (kIsWeb || !_initialized) return;

    final now = DateTime.now();

    // Cancel any existing notifications for this task
    await cancelTaskNotifications(taskId);

    final idBase = taskId.hashCode.abs() % 100000;

    // Warning notification (lead time from settings)
    final warningTime = deadline.subtract(Duration(minutes: leadMinutes));
    if (warningTime.isAfter(now)) {
      await _plugin.zonedSchedule(
        idBase,
        '⏰ Task due in $leadMinutes minutes',
        taskTitle,
        tz.TZDateTime.from(warningTime, tz.local),
        _notifDetails(taskTitle, warning: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$taskId|$taskTitle',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Deadline notification — persistent, requires action
    if (deadline.isAfter(now)) {
      await _plugin.zonedSchedule(
        idBase + 1,
        '📸 Prove it! Task deadline reached',
        'Take a photo to verify: $taskTitle',
        tz.TZDateTime.from(deadline, tz.local),
        _notifDetails(taskTitle, warning: false),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$taskId|$taskTitle',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancel all notifications for a specific task
  Future<void> cancelTaskNotifications(String taskId) async {
    if (kIsWeb) return;
    final idBase = taskId.hashCode.abs() % 100000;
    await _plugin.cancel(idBase);
    await _plugin.cancel(idBase + 1);
  }

  /// Cancel ALL notifications
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Schedule notifications for all upcoming pending tasks
  Future<void> rescheduleAll(List<Map<String, dynamic>> tasks) async {
    if (kIsWeb) return;
    await cancelAll();
    for (final task in tasks) {
      if (task['scheduled_time'] == null) continue;
      final deadline = DateTime.tryParse(task['scheduled_time']);
      if (deadline == null || deadline.isBefore(DateTime.now())) continue;
      await scheduleTaskNotifications(
        taskId: task['id'],
        taskTitle: task['title'] ?? 'Task',
        deadline: deadline,
      );
    }
  }

  NotificationDetails _notifDetails(String taskTitle, {required bool warning}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        warning ? 'task_warning' : 'task_deadline',
        warning ? 'Task Warnings' : 'Task Deadlines',
        channelDescription: warning
            ? '15 minute warnings before task deadlines'
            : 'Notifications when task deadlines are reached',
        importance: warning ? Importance.high : Importance.max,
        priority: Priority.high,
        ongoing: !warning, // deadline notif is persistent
        autoCancel: warning,
        category: warning
            ? AndroidNotificationCategory.reminder
            : AndroidNotificationCategory.alarm,
        actions: warning
            ? null
            : [
                const AndroidNotificationAction('verify', 'Verify Now',
                    showsUserInterface: true),
                const AndroidNotificationAction('snooze', 'Snooze 5min'),
              ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: warning
            ? InterruptionLevel.active
            : InterruptionLevel.timeSensitive,
        categoryIdentifier: 'TASK_DEADLINE',
      ),
    );
  }
}

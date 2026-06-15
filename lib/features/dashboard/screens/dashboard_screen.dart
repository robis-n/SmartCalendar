import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_utils.dart';
import '../../../services/device_calendar_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';
import '../../tasks/screens/add_task_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../verification/screens/verification_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _tasks  = [];
  List<Map<String, dynamic>> _shared = [];
  List<Map<String, dynamic>> _undone = []; // overdue + never completed
  List<Map<String, dynamic>> _week   = []; // this week's tasks (agenda)
  List<Map<String, dynamic>> _global = []; // timeless bucket-list reminders
  Set<int> _weekTaskDays = {};             // Mon=0 offsets with ≥1 task
  String _tier    = AppConstants.tierFree;
  bool   _loading = true;

  // In-memory cache so returning to Home (the shell rebuilds the screen on
  // every tab switch) paints instantly from the last load, then refreshes
  // silently in the background — no full-screen spinner after the first time.
  static List<Map<String, dynamic>> _cTasks = [];
  static List<Map<String, dynamic>> _cShared = [];
  static List<Map<String, dynamic>> _cUndone = [];
  static List<Map<String, dynamic>> _cWeek = [];
  static List<Map<String, dynamic>> _cGlobal = [];
  static Set<int> _cWeekDays = {};
  static String _cTier = AppConstants.tierFree;
  static bool _hasCache = false;
  static String? _cUid; // which account the cache belongs to

  static DateTime get _mondayOfThisWeek {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
  }

  // ── Live clock ─────────────────────────────────────────
  String _clockTime = '';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(_refreshClock);
    });
    // Seed from cache for an instant paint, then refresh silently — but only
    // if the cache belongs to the account that's signed in now (switching
    // accounts must never show the previous user's tasks).
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (_hasCache && _cUid == uid) {
      _tasks  = _cTasks;
      _shared = _cShared;
      _undone = _cUndone;
      _week   = _cWeek;
      _global = _cGlobal;
      _weekTaskDays = _cWeekDays;
      _tier = _cTier;
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  // Coming back from background = the user "opened the app": refresh data and
  // re-arm reminders — rescheduleAll drops overdue follow-up nudges.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  void _refreshClock() {
    final n = DateTime.now();
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final m = n.minute.toString().padLeft(2, '0');
    _clockTime = '$h:$m ${n.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ── Data ───────────────────────────────────────────────

  Future<void> _load() async {
    // Spinner only when there's nothing valid to show yet; otherwise refresh
    // silently. A cache from another account doesn't count.
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (!_hasCache || _cUid != uid) {
      if (mounted) setState(() => _loading = true);
    }
    final tasks    = await SupabaseService.getTodayTasks();
    final shared   = await SupabaseService.getSharedTasksForDate(DateTime.now());
    final profile  = await SupabaseService.getUserProfile();
    final upcoming = await SupabaseService.getUpcomingPendingTasks();
    final undone   = await SupabaseService.getUndoneTasks();
    final week     = await SupabaseService.getTasksForWeek(_mondayOfThisWeek);
    final weekDays = await SupabaseService.getTaskDayOffsetsForWeek(_mondayOfThisWeek);
    final global   = await SupabaseService.getGlobalReminders();

    // Respect the Settings toggle: re-arming while disabled would undo it.
    final prefs = Map<String, dynamic>.from((profile?['preferences'] as Map?) ?? {});
    final notifsOn = prefs['notifications_enabled'] as bool? ?? true;
    NotificationService.leadMinutes =
        prefs['reminder_lead_minutes'] as int? ?? NotificationService.leadMinutes;
    if (notifsOn) {
      NotificationService().rescheduleAll(upcoming);
    } else {
      NotificationService().cancelAll();
    }
    NotificationService.onVerificationRequired = (id, title) {
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerificationScreen(taskId: id, taskTitle: title),
        ));
      }
    };

    // Refresh the cache so the next instant paint is current.
    _cTasks = tasks; _cShared = shared; _cUndone = undone; _cWeek = week;
    _cGlobal = global; _cWeekDays = weekDays;
    _cTier = profile?['subscription_tier'] ?? AppConstants.tierFree;
    _cUid = uid;
    _hasCache = true;

    if (mounted) {
      setState(() {
        _tasks        = tasks;
        _shared       = shared;
        _undone       = undone;
        _week         = week;
        _global       = global;
        _weekTaskDays = weekDays;
        _tier         = _cTier;
        _loading      = false;
      });
    }
  }

  // rootNavigator: true → these full-screen modals cover the bottom nav and
  // any sub-dialogs (e.g. time picker) sit cleanly on a sterile background.
  Future<void> _openAddTask() async {
    final r = await Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const AddTaskScreen()));
    if (r == true && mounted) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> task) async {
    final r = await Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task['id'])));
    if (r != null && mounted) _load();
  }

  // Unfinished / overdue tasks — the left-hand mirror of the + button.
  Future<void> _openUndone() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => _UndoneSheet(
        tasks: _undone,
        onOpen: (t) async {
          final r = await Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(taskId: t['id'])));
          if (r != null && mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // close sheet
            _load();
          }
        },
      ),
    );
  }

  // Tapping a day on Home "zooms in" to that day — a scale+fade reveal
  // showing exactly what's scheduled, with quick add. Reloads on return.
  // Tasks already loaded for a given day (today list + week agenda), so the
  // zoom card can paint instantly before its own fetch returns.
  List<Map<String, dynamic>> _tasksOn(DateTime day) {
    bool sameDay(DateTime a) =>
        a.year == day.year && a.month == day.month && a.day == day.day;
    final src = [..._tasks, ..._week];
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final t in src) {
      final d = tsTryFromDb(t['scheduled_time'] as String?);
      if (d == null || !sameDay(d)) continue;
      final id = t['id'] as String?;
      if (id != null && !seen.add(id)) continue;
      out.add(t);
    }
    return out;
  }

  Future<void> _openDayZoom(DateTime day) async {
    HapticFeedback.selectionClick();
    await showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'day',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1.0).animate(curved),
            child: _DayZoomCard(
              day: day,
              initialTasks: _tasksOn(day),
              onOpenTask: (t) async {
                final r = await Navigator.of(ctx, rootNavigator: true).push(
                    MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(taskId: t['id'])));
                if (r != null) { if (mounted) _load(); }
              },
              onAdd: () async {
                final r = await Navigator.of(ctx, rootNavigator: true).push(
                    MaterialPageRoute(
                        builder: (_) => AddTaskScreen(initialDate: day)));
                return r == true;
              },
            ),
          ),
        );
      },
    );
    if (mounted) _load();
  }

  Future<void> _openVerification(Map<String, dynamic> task) async {
    final canVerify = [AppConstants.tierPro, AppConstants.tierPremium, AppConstants.tierAdmin]
        .contains(_tier);
    if (!canVerify) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade to Pro to verify tasks with photos')),
      );
      return;
    }
    final r = await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(
          taskId: task['id'],
          taskTitle: task['title'],
          taskDescription: task['description'] as String?),
    ));
    if (r != null && mounted) _load();
  }

  // ── Copy ───────────────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5)  return 'Still up?';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Winding down';
  }

  String get _dateLabel {
    final n = DateTime.now();
    const wd = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const mo = ['January','February','March','April','May','June',
      'July','August','September','October','November','December'];
    return '${wd[n.weekday - 1]}, ${mo[n.month - 1]} ${n.day}';
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final done  = _tasks.where((t) => t['status'] == 'verified').length;
    final total = _tasks.length;
    final left  = total - done;          // everything not yet completed

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 92, left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left mirror of + : unfinished tasks. Hidden when nothing is
            // overdue so the home stays calm. Badge shows the count.
            if (_undone.isNotEmpty)
              _InkFAB(
                icon: Icons.history_rounded,
                filled: false,
                badge: _undone.length,
                onTap: _openUndone,
              )
            else
              const SizedBox(width: 60),
            _InkFAB(icon: Icons.add_rounded, accent: true, onTap: _openAddTask),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.label,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.label, strokeWidth: 2))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Hero — centered & personal ──────────────────
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                        child: Column(children: [
                          Text(_clockTime,
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: AppColors.label3, letterSpacing: 0.5,
                            )),
                          const SizedBox(height: 10),
                          Text(_greeting,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 40, fontWeight: FontWeight.w800,
                              color: AppColors.label, letterSpacing: -1.5,
                              height: 1.05,
                            )),
                          const SizedBox(height: 10),
                          Text(_dateLabel.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.label3, letterSpacing: 2.0,
                            )),
                        ]),
                      ),
                    ),
                  ),

                  // ── Three big numbers: TOTAL / LEFT / DONE ──────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                      child: Row(children: [
                        Expanded(child: _BigStat(value: total, label: 'TODAY')),
                        _statDivider(),
                        Expanded(child: _BigStat(value: left,  label: 'LEFT')),
                        _statDivider(),
                        Expanded(child: _BigStat(value: done,  label: 'DONE')),
                      ]),
                    ),
                  ),

                  // ── This week strip (above the tasks) ───────────
                  SliverToBoxAdapter(
                    child: _WeekStrip(
                      monday: _mondayOfThisWeek,
                      initialOffsets: _weekTaskDays,
                      onTapDay: _openDayZoom,
                    ),
                  ),

                  // ── Task list / shared / empty ──────────────────
                  if (_tasks.isEmpty && _shared.isEmpty && _undone.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else ...[
                    if (_tasks.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _sectionRule('TODAY')),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _TaskRow(
                              task: _tasks[i],
                              index: i,
                              onTap:   () => _openDetail(_tasks[i]),
                              onCheck: () => _openVerification(_tasks[i]),
                            ),
                            childCount: _tasks.length,
                          ),
                        ),
                      ),
                    ],

                    // Nothing scheduled today → surface what's still
                    // unfinished from earlier so the day doesn't feel idle.
                    if (_tasks.isEmpty && _shared.isEmpty &&
                        _undone.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _sectionRule('UNFINISHED')),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _TaskRow(
                              task: _undone[i],
                              index: i,
                              overdue: true,
                              onTap:   () => _openDetail(_undone[i]),
                              onCheck: () => _openVerification(_undone[i]),
                            ),
                            childCount: _undone.length,
                          ),
                        ),
                      ),
                    ],
                    if (_shared.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _sectionRule('SHARED WITH YOU')),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _SharedRow(task: _shared[i]),
                            childCount: _shared.length,
                          ),
                        ),
                      ),
                    ],

                    // ── Timeless bucket-list reminders ───────────
                    ..._buildGlobal(),

                    // ── Rest of this week ─────────────────────────
                    ..._buildWeekAhead(),

                    // Extra room so content scrolls above the floating FABs
                    // even at the largest text scale (FABs sit ~168px from bottom).
                    const SliverToBoxAdapter(child: SizedBox(height: 200)),
                  ],
                ],
              ),
      ),
    );
  }

  // Timeless bucket-list reminders — no deadline, just things to get to.
  List<Widget> _buildGlobal() {
    if (_global.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: _sectionRule('ANYTIME')),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _TaskRow(
              task: _global[i],
              index: i,
              onTap:   () => _openDetail(_global[i]),
              onCheck: () => _openVerification(_global[i]),
            ),
            childCount: _global.length,
          ),
        ),
      ),
    ];
  }

  Widget _statDivider() => Container(width: 0.5, height: 54, color: AppColors.separator);

  Widget _sectionRule(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
    child: Row(children: [
      Text(label,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800,
          color: AppColors.label3, letterSpacing: 2,
        )),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 0.5, color: AppColors.separator)),
    ]),
  );

  // Agenda for the rest of this week (days strictly after today) so Home
  // shows "what's up" without duplicating the TODAY list.
  List<Widget> _buildWeekAhead() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDay = <DateTime, List<Map<String, dynamic>>>{};
    for (final t in _week) {
      final d = tsTryFromDb(t['scheduled_time'] as String?);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isAfter(today)) continue; // future days within this week only
      byDay.putIfAbsent(day, () => []).add(t);
    }
    if (byDay.isEmpty) return const [];
    final days = byDay.keys.toList()..sort();
    return [
      SliverToBoxAdapter(child: _sectionRule('THIS WEEK')),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _WeekDayGroup(
              day: days[i],
              tasks: byDay[days[i]]!,
              onTapDay: () => _openDayZoom(days[i]),
              onTapTask: _openDetail,
            ),
            childCount: days.length,
          ),
        ),
      ),
    ];
  }
}

// ── Shared-with-you row (read-only) ───────────────────────────────────────────

class _SharedRow extends StatelessWidget {
  final Map<String, dynamic> task;
  const _SharedRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final by = (task['_shared_by'] as String?) ?? 'a friend';
    final time = task['scheduled_time'] != null
        ? _fmt(tsFromDb(task['scheduled_time']))
        : 'Anytime';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Icon(Icons.people_outline_rounded, size: 20, color: AppColors.label3),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task['title'] ?? '',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: AppColors.label, letterSpacing: -0.3,
              )),
            const SizedBox(height: 4),
            Text('from ${by.split('@').first} · $time',
              style: TextStyle(fontSize: 14, color: AppColors.label3)),
          ])),
        ]),
      ),
      Container(height: 0.5, color: AppColors.separator),
    ]);
  }

  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}

// ── Big stat number ───────────────────────────────────────────────────────────

class _BigStat extends StatelessWidget {
  final int value;
  final String label;
  const _BigStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$value',
      style: TextStyle(
        fontSize: 56, fontWeight: FontWeight.w800,
        color: AppColors.label, letterSpacing: -3, height: 1,
      )),
    const SizedBox(height: 6),
    Text(label,
      style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800,
        color: AppColors.label3, letterSpacing: 1.8,
      )),
  ]);
}

// ── Task row — big, clean, monochrome ─────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final int index;
  final bool overdue; // from a past day — show the date, not just the time
  final VoidCallback onTap;
  final VoidCallback onCheck;
  const _TaskRow({required this.task, required this.index,
      required this.onTap, required this.onCheck, this.overdue = false});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] as String? ?? 'pending';
    final isDone   = status == 'verified';
    final isFailed = status == 'failed';
    final when     = task['scheduled_time'] != null
        ? (overdue
            ? _fmtDate(tsFromDb(task['scheduled_time']))
            : _fmtTime(tsFromDb(task['scheduled_time'])))
        : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

            // Title + time
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task['title'] ?? '',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600,
                    color: isDone ? AppColors.label3 : AppColors.label,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.label3,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Text(
                  isDone ? 'Completed'
                      : isFailed ? 'Missed'
                      : when ?? 'Anytime',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.label3,
                    fontWeight: FontWeight.w500,
                    decoration: isFailed ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.label3,
                  ),
                ),
              ],
            )),

            const SizedBox(width: 14),

            // Check / verify control — filled when done, ring otherwise
            GestureDetector(
              onTap: isDone || isFailed ? null : onCheck,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppColors.label : Colors.transparent,
                  border: isDone
                      ? null
                      : Border.all(color: AppColors.separator, width: 1.6),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded
                      : isFailed ? Icons.close_rounded
                      : null,
                  color: isDone ? AppColors.bg : AppColors.label3,
                  size: 19,
                ),
              ),
            ),
          ]),
        ),
        Container(height: 0.5, color: AppColors.separator),
      ]),
    );
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _fmtDate(DateTime d) {
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${wd[d.weekday - 1]}, ${mo[d.month - 1]} ${d.day} · ${_fmtTime(d)}';
  }
}

// ── This-week strip ───────────────────────────────────────────────────────────

class _WeekStrip extends StatefulWidget {
  final DateTime monday;             // Monday of the *current* week
  final Set<int> initialOffsets;     // current week's task-day offsets (seed)
  final ValueChanged<DateTime> onTapDay;
  const _WeekStrip({
    required this.monday,
    required this.initialOffsets,
    required this.onTapDay,
  });

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  static const int _anchor = 1000; // page 1000 = current week
  late final PageController _ctrl = PageController(initialPage: _anchor);
  final Map<int, Set<int>> _cache = {}; // weekDelta -> day offsets
  int _page = _anchor;

  @override
  void initState() {
    super.initState();
    _cache[0] = widget.initialOffsets; // seed: no fetch flicker for this week
  }

  @override
  void didUpdateWidget(covariant _WeekStrip old) {
    super.didUpdateWidget(old);
    // Home reloaded (e.g. a reminder was just added) → refresh the current
    // week's dots so a freshly-added day lights up immediately.
    final a = old.initialOffsets, b = widget.initialOffsets;
    if (a.length != b.length || !a.containsAll(b)) {
      setState(() => _cache[0] = widget.initialOffsets);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  DateTime _mondayFor(int page) =>
      widget.monday.add(Duration(days: (page - _anchor) * 7));

  Future<void> _ensure(int page) async {
    final k = page - _anchor;
    if (_cache.containsKey(k)) return;
    final offs =
        await SupabaseService.getTaskDayOffsetsForWeek(_mondayFor(page));
    if (mounted) setState(() => _cache[k] = offs);
  }

  String _rangeLabel(DateTime monday) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final sun = monday.add(const Duration(days: 6));
    final now = DateTime.now();
    final isThisWeek = !monday.isAfter(now) && !now.isAfter(sun);
    if (isThisWeek) return 'This week';
    if (monday.month == sun.month) {
      return '${mo[monday.month - 1]} ${monday.day} – ${sun.day}';
    }
    return '${mo[monday.month - 1]} ${monday.day} – ${mo[sun.month - 1]} ${sun.day}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        child: Row(children: [
          Text(_rangeLabel(_mondayFor(_page)),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.label3,
                  letterSpacing: 1.2)),
          const Spacer(),
          Icon(Icons.swipe_outlined, size: 14, color: AppColors.label3),
        ]),
      ),
      SizedBox(
        height: 78,
        child: PageView.builder(
          controller: _ctrl,
          onPageChanged: (p) {
            setState(() => _page = p);
            _ensure(p - 1);
            _ensure(p + 1);
          },
          itemBuilder: (_, page) {
            _ensure(page);
            final monday = _mondayFor(page);
            final offs = _cache[page - _anchor] ?? const <int>{};
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: List.generate(7, (i) {
                  final day = monday.add(Duration(days: i));
                  final selected = isToday(day);
                  final hasTask = offs.contains(i);
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onTapDay(day),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(children: [
                          Text(const ['M','T','W','T','F','S','S'][i],
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.label3,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? AppColors.accent
                                  : Colors.transparent,
                              border: selected
                                  ? null
                                  : Border.all(
                                      color: AppColors.separator, width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Text('${day.day}',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected
                                        ? AppColors.bg
                                        : AppColors.label)),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasTask
                                  ? AppColors.accent.withValues(alpha: selected ? 1.0 : 0.65)
                                  : Colors.transparent,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 120),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Nothing today',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
              color: AppColors.label, letterSpacing: -1)),
        const SizedBox(height: 10),
        Text('A clear schedule.\nTap the + below to add something.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.label3, height: 1.5)),
      ]),
    ),
  );
}

// ── Ink FAB ───────────────────────────────────────────────────────────────────

class _InkFAB extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final bool filled;   // filled ink (primary +) vs. glassy outline (secondary)
  final bool accent;   // use AppColors.accent instead of pure ink (+ FAB)
  final int badge;     // small count chip; 0 = none
  const _InkFAB({
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.filled = true,
    this.accent = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = accent
        ? AppColors.accent
        : (filled ? AppColors.label : AppColors.card);
    final fab = Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: filled
            ? null
            : Border.all(color: AppColors.separator, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark ? 0.5 : 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: (filled || accent) ? AppColors.bg : AppColors.label, size: filled ? 30 : 26),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: badge > 0
          ? Stack(clipBehavior: Clip.none, children: [
              fab,
              Positioned(
                top: -2, right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.label,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.bg, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text('${badge > 99 ? '99+' : badge}',
                      style: TextStyle(
                          color: AppColors.bg,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ])
          : fab,
    );
  }
}

// ── Unfinished-tasks sheet ────────────────────────────────────────────────────

class _UndoneSheet extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final ValueChanged<Map<String, dynamic>> onOpen;
  const _UndoneSheet({required this.tasks, required this.onOpen});

  String _fmt(DateTime d) {
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final t = '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
    return '${wd[d.weekday - 1]}, ${mo[d.month - 1]} ${d.day} · $t';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      snap: true,
      snapSizes: const [0.6, 0.92],
      builder: (ctx, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          color: AppColors.card,
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
                width: 40, height: 5,
                decoration: BoxDecoration(
                    color: AppColors.separator,
                    borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(children: [
                Text('Unfinished',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.label,
                        letterSpacing: -0.8)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.label.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${tasks.length}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.label2)),
                ),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(24, 4, 24, mq.padding.bottom + 24),
                itemCount: tasks.length,
                separatorBuilder: (_, _) =>
                    Container(height: 0.5, color: AppColors.separator),
                itemBuilder: (_, i) {
                  final t = tasks[i];
                  final failed = (t['status'] as String?) == 'failed';
                  final sched = tsTryFromDb(t['scheduled_time'] as String?);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onOpen(t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.separator, width: 1.5),
                          ),
                          child: Icon(
                              failed
                                  ? Icons.close_rounded
                                  : Icons.priority_high_rounded,
                              size: 16,
                              color: AppColors.label3),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['title'] as String? ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.label,
                                        letterSpacing: -0.3)),
                                const SizedBox(height: 3),
                                Text(
                                    sched != null
                                        ? _fmt(sched)
                                        : (failed ? 'Missed' : 'Overdue'),
                                    style: TextStyle(
                                        fontSize: 13, color: AppColors.label3)),
                              ]),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.label3),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── This-week agenda day group ────────────────────────────────────────────────

class _WeekDayGroup extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> tasks;
  final VoidCallback onTapDay;
  final ValueChanged<Map<String, dynamic>> onTapTask;
  const _WeekDayGroup({
    required this.day,
    required this.tasks,
    required this.onTapDay,
    required this.onTapTask,
  });

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 1) return 'Tomorrow';
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${wd[day.weekday - 1]}, ${mo[day.month - 1]} ${day.day}';
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapDay,
          child: Row(children: [
            Text(_label(),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: -0.2)),
            const SizedBox(width: 8),
            Text('${tasks.length}',
                style: TextStyle(fontSize: 13, color: AppColors.label3)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.label3),
          ]),
        ),
        const SizedBox(height: 6),
        ...tasks.map((t) {
          final done = (t['status'] as String?) == 'verified';
          final sched = tsTryFromDb(t['scheduled_time'] as String?);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTapTask(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.label3
                        : AppColors.label.withValues(alpha: 0.7),
                  ),
                ),
                Expanded(
                  child: Text(t['title'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          color: done ? AppColors.label3 : AppColors.label,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.label3)),
                ),
                const SizedBox(width: 10),
                Text(sched != null ? _time(sched) : 'Anytime',
                    style: TextStyle(fontSize: 13, color: AppColors.label3)),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Zoom-in day card (opened from Home) ───────────────────────────────────────

class _DayZoomCard extends StatefulWidget {
  final DateTime day;
  final List<Map<String, dynamic>> initialTasks; // seeds an instant paint
  final ValueChanged<Map<String, dynamic>> onOpenTask;
  final Future<bool> Function() onAdd;
  const _DayZoomCard({
    required this.day,
    required this.initialTasks,
    required this.onOpenTask,
    required this.onAdd,
  });
  @override
  State<_DayZoomCard> createState() => _DayZoomCardState();
}

class _DayZoomCardState extends State<_DayZoomCard> {
  List<Map<String, dynamic>> _tasks = [];
  List<DeviceEvent> _events = [];

  static const _wd = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  static const _mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  void initState() {
    super.initState();
    // Seed from what Home already loaded → the card animates in with content,
    // no spinner-then-resize flash. Then refresh silently.
    _tasks = widget.initialTasks;
    _load();
  }

  Future<void> _load() async {
    final t = await SupabaseService.getTasksForDate(widget.day);
    final e = await DeviceCalendarService.eventsForDay(widget.day);
    if (mounted) setState(() { _tasks = t; _events = e; });
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final title = '${_wd[d.weekday - 1]}, ${_mo[d.month - 1]} ${d.day}';
    final mq = MediaQuery.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 20, vertical: mq.padding.top + 40),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxHeight: mq.size.height * 0.7),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: cardShadow,
              border: Border.all(color: AppColors.separator, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 12),
                child: Row(children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.label,
                            letterSpacing: -0.6)),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final added = await widget.onAdd();
                      if (added) _load();
                    },
                    child: Container(
                      width: 36, height: 36,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                          color: AppColors.label, shape: BoxShape.circle),
                      child: Icon(Icons.add_rounded, color: AppColors.bg, size: 20),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: AppColors.bg2, shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.label2, size: 18),
                    ),
                  ),
                ]),
              ),
              Flexible(
                child: (_tasks.isEmpty && _events.isEmpty)
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Nothing scheduled. Tap + to add.',
                                  style: TextStyle(
                                      fontSize: 15, color: AppColors.label3)),
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                            children: [
                              for (final t in _tasks)
                                _zoomTaskRow(t),
                              if (_events.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('FROM YOUR CALENDARS',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.label3,
                                        letterSpacing: 1.5)),
                                const SizedBox(height: 4),
                                for (final e in _events) _zoomEventRow(e),
                              ],
                            ],
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _zoomTaskRow(Map<String, dynamic> t) {
    final done = (t['status'] as String?) == 'verified';
    final sched = tsTryFromDb(t['scheduled_time'] as String?);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onOpenTask(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.label : Colors.transparent,
              border: done
                  ? null
                  : Border.all(color: AppColors.separator, width: 1.5),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 15, color: AppColors.bg)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(t['title'] as String? ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.label3 : AppColors.label,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.label3)),
          ),
          const SizedBox(width: 10),
          Text(sched != null ? _time(sched) : 'Anytime',
              style: TextStyle(fontSize: 13, color: AppColors.label3)),
        ]),
      ),
    );
  }

  Widget _zoomEventRow(DeviceEvent e) {
    final ambient = e.color != null ? Color(e.color!) : AppColors.label2;
    final when = e.allDay
        ? 'All day'
        : [if (e.start != null) _time(e.start!)].join();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        Icon(Icons.circle, size: 11, color: ambient),
        const SizedBox(width: 14),
        Expanded(
          child: Text(e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.label2)),
        ),
        const SizedBox(width: 10),
        Text(when, style: TextStyle(fontSize: 13, color: AppColors.label3)),
      ]),
    );
  }
}

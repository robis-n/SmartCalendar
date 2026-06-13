import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_utils.dart';
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
  Set<int> _weekTaskDays = {};             // Mon=0 offsets with ≥1 task
  String _tier    = AppConstants.tierFree;
  bool   _loading = true;

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
    setState(() => _loading = true);
    final tasks    = await SupabaseService.getTodayTasks();
    final shared   = await SupabaseService.getSharedTasksForDate(DateTime.now());
    final profile  = await SupabaseService.getUserProfile();
    final upcoming = await SupabaseService.getUpcomingPendingTasks();
    final undone   = await SupabaseService.getUndoneTasks();
    final weekDays = await SupabaseService.getTaskDayOffsetsForWeek(_mondayOfThisWeek);

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

    if (mounted) {
      setState(() {
        _tasks        = tasks;
        _shared       = shared;
        _undone       = undone;
        _weekTaskDays = weekDays;
        _tier         = profile?['subscription_tier'] ?? AppConstants.tierFree;
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
            _InkFAB(icon: Icons.add_rounded, onTap: _openAddTask),
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
                      taskDayOffsets: _weekTaskDays,
                      onTapDay: (_) => context.go('/calendar'),
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
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ],
              ),
      ),
    );
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

class _WeekStrip extends StatelessWidget {
  final DateTime monday;             // Monday of the current week
  final Set<int> taskDayOffsets;     // 0..6 (Mon=0) with ≥1 task
  final ValueChanged<DateTime> onTapDay;
  const _WeekStrip({
    required this.monday,
    required this.taskDayOffsets,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: List.generate(7, (i) {
          final day     = monday.add(Duration(days: i));
          final selected = isToday(day);
          final hasTask  = taskDayOffsets.contains(i);
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapDay(day),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(children: [
                  Text(const ['M','T','W','T','F','S','S'][i],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label3,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.label : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(color: AppColors.separator, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text('${day.day}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color:
                                selected ? AppColors.bg : AppColors.label)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasTask
                          ? (selected ? AppColors.label : AppColors.label2)
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
  final int badge;     // small count chip; 0 = none
  const _InkFAB({
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.filled = true,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fab = Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: filled ? AppColors.label : AppColors.card,
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
      child: Icon(icon, color: filled ? AppColors.bg : AppColors.label, size: filled ? 30 : 26),
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

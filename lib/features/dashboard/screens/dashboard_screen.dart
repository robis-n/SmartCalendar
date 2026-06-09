import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
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

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _tasks  = [];
  List<Map<String, dynamic>> _shared = [];
  String _tier    = AppConstants.tierFree;
  bool   _loading = true;

  // ── Live clock ─────────────────────────────────────────
  String _clockTime = '';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _refreshClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(_refreshClock);
    });
    _load();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
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

    NotificationService().rescheduleAll(upcoming);
    NotificationService.onVerificationRequired = (id, title) {
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerificationScreen(taskId: id, taskTitle: title),
        ));
      }
    };

    if (mounted) {
      setState(() {
        _tasks   = tasks;
        _shared  = shared;
        _tier    = profile?['subscription_tier'] ?? AppConstants.tierFree;
        _loading = false;
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
      builder: (_) => VerificationScreen(taskId: task['id'], taskTitle: task['title']),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 92),
        child: _InkFAB(onTap: _openAddTask),
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

                  // ── Task list / shared / empty ──────────────────
                  if (_tasks.isEmpty && _shared.isEmpty)
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
        ? _fmt(DateTime.parse(task['scheduled_time']))
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
  final VoidCallback onTap;
  final VoidCallback onCheck;
  const _TaskRow({required this.task, required this.index,
      required this.onTap, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] as String? ?? 'pending';
    final isDone   = status == 'verified';
    final isFailed = status == 'failed';
    final time     = task['scheduled_time'] != null
        ? _fmtTime(DateTime.parse(task['scheduled_time']))
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
                      : time ?? 'Anytime',
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
  const _InkFAB({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: AppColors.label,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark ? 0.5 : 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(Icons.add_rounded, color: AppColors.bg, size: 30),
    ),
  );
}

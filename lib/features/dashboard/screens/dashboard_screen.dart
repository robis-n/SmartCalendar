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
  List<Map<String, dynamic>> _tasks = [];
  String _tier    = AppConstants.tierFree;
  bool   _loading = true;

  // ── Live clock ─────────────────────────────────────────
  String _clockTime = '';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _refreshClock();                                   // set immediately, no setState needed in initState
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
        _tier    = profile?['subscription_tier'] ?? AppConstants.tierFree;
        _loading = false;
      });
    }
  }

  Future<void> _openAddTask() async {
    final r = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddTaskScreen()));
    if (r == true && mounted) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> task) async {
    final r = await Navigator.of(context)
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
    final r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(taskId: task['id'], taskTitle: task['title']),
    ));
    if (r != null && mounted) _load();
  }

  // ── Greeting copy ──────────────────────────────────────
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5)  return 'Night\nowl.';
    if (h < 12) return 'Good\nmorning.';
    if (h < 17) return 'Good\nafternoon.';
    if (h < 21) return 'Good\nevening.';
    return 'Late\nnight.';
  }

  // ── Date label ─────────────────────────────────────────
  String get _dateLabel {
    final n = DateTime.now();
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${wd[n.weekday - 1]}, ${mo[n.month - 1]} ${n.day}';
  }

  // ── Build ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAdmin = _tier == AppConstants.tierAdmin;
    final done    = _tasks.where((t) => t['status'] == 'verified').length;
    final failed  = _tasks.where((t) => t['status'] == 'failed').length;
    final pending = _tasks.where((t) => t['status'] == 'pending').length;
    final total   = _tasks.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // ── FAB above the floating nav bar ──────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 92),
        child: _GoldFAB(onTap: _openAddTask),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [

                  // ── Hero editorial header ──────────────────────
                  SliverToBoxAdapter(
                    child: _Header(
                      greeting: _greeting,
                      clockTime: _clockTime,
                      dateLabel: _dateLabel,
                      isAdmin: isAdmin,
                      done: done,
                      total: total,
                      progress: progress,
                    ),
                  ),

                  // ── Stats row — editorial numbers ──────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _StatsBar(
                        total: total, done: done, pending: pending, failed: failed),
                    ),
                  ),

                  // ── Empty state ───────────────────────────────
                  if (_tasks.isEmpty)
                    SliverFillRemaining(
                      child: _EmptyState(onAdd: _openAddTask),
                    )
                  else ...[
                    // Section rule
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: _SectionRule(label: 'TODAY', right: '$done / $total'),
                      ),
                    ),

                    // Task rows — editorial numbered list
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
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
                ],
              ),
      ),
    );
  }
}

// ── Editorial hero header ─────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting, clockTime, dateLabel;
  final bool isAdmin;
  final int done, total;
  final double progress;

  const _Header({
    required this.greeting, required this.clockTime, required this.dateLabel,
    required this.isAdmin, required this.done, required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Stack(clipBehavior: Clip.none, children: [

            // ── Giant watermark % in background ─────────────
            if (total > 0)
              Positioned(
                right: -16,
                top: -24,
                child: Text(
                  '${(progress * 100).round()}',
                  style: TextStyle(
                    fontSize: 168,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent.withValues(alpha: 0.05),
                    letterSpacing: -10,
                    height: 1,
                  ),
                ),
              ),

            // ── Foreground ────────────────────────────────────
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Metadata bar
              Row(children: [
                // Live clock
                Text(clockTime,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.accent, letterSpacing: 0.5,
                  )),
                const SizedBox(width: 8),
                Container(width: 1, height: 12, color: AppColors.separator),
                const SizedBox(width: 8),
                Text(dateLabel,
                  style: const TextStyle(
                    fontSize: 11, color: AppColors.label3,
                    fontWeight: FontWeight.w500,
                  )),
                const Spacer(),
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: const Text('CEO',
                      style: TextStyle(fontSize: 9, color: AppColors.accent,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ),
              ]),

              const SizedBox(height: 30),

              // Bold editorial greeting — the visual anchor of the screen
              Text(greeting,
                style: const TextStyle(
                  fontSize: 46, fontWeight: FontWeight.w900,
                  color: AppColors.label, height: 1.0,
                  letterSpacing: -2.5,
                )),

              const SizedBox(height: 8),

              // Accent underline — editorial typographic accent
              Container(width: 28, height: 2,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(1),
                )),

              const SizedBox(height: 10),

              Text(
                total == 0
                    ? 'Nothing scheduled — enjoy the day.'
                    : '$done of $total tasks complete today',
                style: const TextStyle(fontSize: 13, color: AppColors.label3, height: 1.4),
              ),

              if (total > 0) ...[
                const SizedBox(height: 20),
                // Thin progress bar with % label
                Row(children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: AppColors.separator,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  )),
                  const SizedBox(width: 14),
                  Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: AppColors.accent, letterSpacing: -0.3,
                    )),
                ]),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Stats bar — editorial numbers ─────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total, done, pending, failed;
  const _StatsBar({required this.total, required this.done,
      required this.pending, required this.failed});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: AppColors.separator, width: 0.5),
      ),
    ),
    child: Row(children: [
      _Num(value: total, label: 'TOTAL', color: AppColors.label2),
      _divider(),
      _Num(value: done, label: 'DONE', color: AppColors.success),
      _divider(),
      _Num(value: pending, label: 'PENDING', color: AppColors.warning),
      _divider(),
      _Num(value: failed, label: 'FAILED', color: AppColors.destructive),
    ]),
  );

  Widget _divider() => Container(
    width: 0.5, height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    color: AppColors.separator,
  );
}

class _Num extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _Num({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text('$value',
        style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -0.5, height: 1,
        )),
      const SizedBox(height: 2),
      Text(label,
        style: const TextStyle(
          fontSize: 8, fontWeight: FontWeight.w700,
          color: AppColors.label3, letterSpacing: 1.2,
        )),
    ]),
  );
}

// ── Section rule — editorial divider with text ────────────────────────────────

class _SectionRule extends StatelessWidget {
  final String label;
  final String? right;
  const _SectionRule({required this.label, this.right});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label,
      style: const TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700,
        color: AppColors.label3, letterSpacing: 2,
      )),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 0.5, color: AppColors.separator)),
    if (right != null) ...[
      const SizedBox(width: 12),
      Text(right!,
        style: const TextStyle(
          fontSize: 9, color: AppColors.label3,
          fontWeight: FontWeight.w600,
        )),
    ],
  ]);
}

// ── Task row — editorial numbered row ─────────────────────────────────────────

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
    final priority = task['priority'] as String? ?? 'low';
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
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [

            // ── Index number (editorial gold) ──────────────
            SizedBox(
              width: 26,
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: isDone ? AppColors.separator : AppColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Task title + time ──────────────────────────
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task['title'] ?? '',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: isDone ? AppColors.label3 : AppColors.label,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.label3,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  isDone ? 'Completed ✓'
                      : isFailed ? 'Failed'
                      : time ?? 'No time set',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDone ? AppColors.success
                        : isFailed ? AppColors.destructive
                        : AppColors.label3,
                    fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            )),

            // ── Priority badge ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isDone ? AppColors.successBg
                    : isFailed ? AppColors.destructiveBg
                    : AppColors.priorityBg(priority),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                isDone ? 'DONE'
                    : isFailed ? 'FAIL'
                    : priority.toUpperCase().substring(0, priority.length.clamp(0, 3)),
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: isDone ? AppColors.success
                      : isFailed ? AppColors.destructive
                      : AppColors.priorityColor(priority),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── Verify circle ─────────────────────────────
            GestureDetector(
              onTap: isDone || isFailed ? null : onCheck,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.success.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: isDone
                      ? null
                      : Border.all(
                          color: isFailed ? AppColors.destructive.withValues(alpha: 0.3)
                              : AppColors.separator,
                          width: 1.5,
                        ),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded
                      : isFailed ? Icons.close_rounded
                      : null,
                  color: isDone ? AppColors.success
                      : AppColors.destructive,
                  size: 16,
                ),
              ),
            ),
          ]),
        ),
        // Bottom divider
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
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Large editorial zero
        Text('00',
          style: TextStyle(
            fontSize: 96, fontWeight: FontWeight.w900,
            color: AppColors.accent.withValues(alpha: 0.08),
            letterSpacing: -6, height: 1,
          )),
        const SizedBox(height: 4),
        const Text('Clear schedule',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.label, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Nothing due today.\nAdd a task to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.label3, height: 1.5)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8C890), Color(0xFFB08040)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 18, offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Text('+ New task',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.bg, letterSpacing: 0.5)),
          ),
        ),
      ]),
    ),
  );
}

// ── Gold FAB ──────────────────────────────────────────────────────────────────

class _GoldFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _GoldFAB({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8C890), Color(0xFFB08040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),   // square-ish, not a circle — editorial
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF7A).withValues(alpha: 0.50),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.add, color: AppColors.bg, size: 26),
    ),
  );
}

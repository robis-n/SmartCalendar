import 'dart:math' as math;
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
  String _tier = AppConstants.tierFree;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

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
        _tasks  = tasks;
        _tier   = profile?['subscription_tier'] ?? AppConstants.tierFree;
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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5)  return 'Night owl';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Late night';
  }

  String get _dateLabel {
    final now = DateTime.now();
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

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
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
            : CustomScrollView(
                slivers: [
                  // ── Editorial header ─────────────────────────────
                  SliverToBoxAdapter(child: _buildHeader(isAdmin, done, total, progress)),

                  // ── Stat chips ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _StatChip(label: 'TODAY', count: total,
                              color: AppColors.accent, bg: AppColors.accentLight, selected: true),
                          const SizedBox(width: 8),
                          _StatChip(label: 'DONE', count: done,
                              color: AppColors.success, bg: AppColors.successBg),
                          const SizedBox(width: 8),
                          _StatChip(label: 'PENDING', count: pending,
                              color: AppColors.warning, bg: AppColors.warningBg),
                          const SizedBox(width: 8),
                          _StatChip(label: 'FAILED', count: failed,
                              color: AppColors.destructive, bg: AppColors.destructiveBg),
                        ]),
                      ),
                    ),
                  ),

                  // ── Section label ────────────────────────────────
                  if (_tasks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                        child: Row(children: [
                          const Text("TODAY'S TASKS",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: AppColors.label3, letterSpacing: 1.5)),
                          const Spacer(),
                          Text('$done / $total done',
                              style: const TextStyle(fontSize: 11, color: AppColors.label3,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),

                  // ── Task list ────────────────────────────────────
                  if (_tasks.isEmpty)
                    SliverFillRemaining(child: _buildEmpty())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TaskCard(
                              task: _tasks[i],
                              onTap:   () => _openDetail(_tasks[i]),
                              onCheck: () => _openVerification(_tasks[i]),
                            ),
                          ),
                          childCount: _tasks.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: _GoldFAB(onTap: _openAddTask),
    );
  }

  Widget _buildHeader(bool isAdmin, int done, int total, double progress) {
    return Container(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top bar: brand label + admin badge
            Row(children: [
              const Text('SC',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900,
                  color: AppColors.accent, letterSpacing: 2,
                )),
              const SizedBox(width: 8),
              Container(width: 1, height: 12, color: AppColors.separator),
              const SizedBox(width: 8),
              Text(_dateLabel,
                style: const TextStyle(
                  fontSize: 11, color: AppColors.label3,
                  fontWeight: FontWeight.w500, letterSpacing: 0.3,
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
                      style: TextStyle(fontSize: 10, color: AppColors.accent,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ),
            ]),
            const SizedBox(height: 28),

            // Greeting + ring side by side
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting,
                  style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w900,
                    color: AppColors.label, height: 1.0,
                    letterSpacing: -1.5,
                  )),
                const SizedBox(height: 6),
                Text(
                  total == 0 ? 'Nothing due — enjoy the day.' : '$done of $total tasks complete',
                  style: const TextStyle(fontSize: 14, color: AppColors.label3, height: 1.4),
                ),
              ])),
              const SizedBox(width: 20),
              if (total > 0)
                _GoldRing(progress: progress, done: done, total: total),
            ]),

            if (total > 0) ...[
              const SizedBox(height: 20),
              // Progress bar — gold on dark
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: AppColors.separator,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2), width: 1),
        ),
        child: const Icon(Icons.check_rounded, size: 36, color: AppColors.accent),
      ),
      const SizedBox(height: 20),
      const Text('Clear schedule', style: TextStyle(fontSize: 20,
          fontWeight: FontWeight.w800, color: AppColors.label, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      const Text('Add a task to get started',
          style: TextStyle(fontSize: 14, color: AppColors.label3)),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: _openAddTask,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8C890), Color(0xFFB08040)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Text('+ Add task',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: AppColors.bg, letterSpacing: 0.3)),
        ),
      ),
    ]),
  );
}

// ── Gold ring progress ────────────────────────────────────────────────────────

class _GoldRing extends StatelessWidget {
  final double progress;
  final int done, total;
  const _GoldRing({required this.progress, required this.done, required this.total});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64, height: 64,
    child: CustomPaint(
      painter: _GoldRingPainter(progress),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${(progress * 100).round()}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
              color: AppColors.label, height: 1, letterSpacing: -0.5)),
        const Text('%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
            color: AppColors.accent, letterSpacing: 0.5)),
      ])),
    ),
  );
}

class _GoldRingPainter extends CustomPainter {
  final double progress;
  _GoldRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width - 8) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()..color = AppColors.separator
               ..style = PaintingStyle.stroke
               ..strokeWidth = 5
               ..strokeCap = StrokeCap.round);

    // Fill — gold
    if (progress > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFFE8C890), Color(0xFFB08040)],
        ).createShader(rect);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_GoldRingPainter old) => old.progress != progress;
}

// ── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color, bg;
  final bool selected;
  const _StatChip({required this.label, required this.count,
      required this.color, required this.bg, this.selected = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: selected ? color.withValues(alpha: 0.15) : bg,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: selected ? color.withValues(alpha: 0.6) : Colors.transparent,
        width: 1,
      ),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$count',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
              color: color, letterSpacing: -0.5)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7), letterSpacing: 0.8)),
    ]),
  );
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  final VoidCallback onCheck;
  const _TaskCard({required this.task, required this.onTap, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    final status   = task['status'] as String? ?? 'pending';
    final priority = task['priority'] as String? ?? 'low';
    final isDone   = status == 'verified';
    final isFailed = status == 'failed';
    final time     = task['scheduled_time'] != null
        ? _fmtTime(DateTime.parse(task['scheduled_time']))
        : null;

    final priColor = AppColors.priorityColor(priority);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.separator, width: 0.5),
          boxShadow: cardShadow,
        ),
        child: Row(children: [
          // Priority accent bar
          Container(
            width: 3,
            height: 64,
            decoration: BoxDecoration(
              color: isDone || isFailed ? AppColors.separator : priColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Check button
          GestureDetector(
            onTap: isDone || isFailed ? null : onCheck,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  key: ValueKey(isDone),
                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isDone ? AppColors.success : AppColors.label3,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Text content
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(task['title'] ?? '',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: isDone || isFailed ? AppColors.label3 : AppColors.label,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.label3,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (time != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time_rounded, size: 11, color: AppColors.label3),
                  const SizedBox(width: 3),
                  Text(time, style: const TextStyle(fontSize: 11, color: AppColors.label3)),
                ]),
              ],
            ],
          )),

          // Status / priority chip
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? AppColors.successBg
                  : isFailed ? AppColors.destructiveBg
                  : AppColors.priorityBg(priority),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isDone ? 'Done' : isFailed ? 'Failed'
                  : priority[0].toUpperCase() + priority.substring(1),
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: isDone ? AppColors.success
                    : isFailed ? AppColors.destructive
                    : AppColors.priorityColor(priority),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}

// ── Gold FAB ──────────────────────────────────────────────────────────────────

class _GoldFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _GoldFAB({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8C890), Color(0xFFB08040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF7A).withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.add, color: AppColors.bg, size: 28),
    ),
  );
}

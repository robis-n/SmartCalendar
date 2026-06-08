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
    if (h < 5)  return 'Night owl 🦉';
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 👋';
    if (h < 21) return 'Good evening 🌙';
    return 'Late night 🌟';
  }

  // Time-of-day adaptive gradient — like the meditation app reference
  List<Color> get _headerGradient {
    final h = DateTime.now().hour;
    if (h >= 5  && h < 9)  return const [Color(0xFFFF8C42), Color(0xFFFF5C7B)]; // sunrise
    if (h >= 9  && h < 12) return const [Color(0xFFFFAB40), Color(0xFFFF6D3B)]; // morning
    if (h >= 12 && h < 15) return const [Color(0xFF4FACFE), Color(0xFF00C6FF)]; // midday
    if (h >= 15 && h < 17) return const [Color(0xFF43CBFF), Color(0xFF9708CC)]; // afternoon
    if (h >= 17 && h < 20) return const [Color(0xFF7C5CFC), Color(0xFF5B3FD9)]; // evening (violet)
    if (h >= 20 && h < 22) return const [Color(0xFF4A1C96), Color(0xFF1A0533)]; // dusk
    return const [Color(0xFF0F0C29), Color(0xFF302B63)];                         // night
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _tier == AppConstants.tierAdmin;
    final done    = _tasks.where((t) => t['status'] == 'verified').length;
    final total   = _tasks.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
            : CustomScrollView(
                slivers: [
                  // ── Header ──────────────────────────────────────
                  SliverToBoxAdapter(child: _buildHeader(isAdmin, done, total, progress)),

                  // ── Section label ───────────────────────────────
                  if (_tasks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                        child: Row(children: [
                          const Text("TODAY'S TASKS",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: AppColors.label3, letterSpacing: 0.8)),
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
      floatingActionButton: _GradientFAB(onTap: _openAddTask),
    );
  }

  Widget _buildHeader(bool isAdmin, int done, int total, double progress) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Spacer(),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('👑 CEO',
                      style: TextStyle(fontSize: 12, color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 4),
            Text(_greeting,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            Text(
              total == 0 ? 'No tasks today — enjoy the day!' : '$done of $total tasks done',
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
            ),
            if (total > 0) ...[
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${(progress * 100).round()}% complete',
                        style: TextStyle(fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7))),
                  ]),
                ),
                const SizedBox(width: 20),
                _RingProgress(progress: progress),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_outline, size: 40, color: AppColors.accent),
      ),
      const SizedBox(height: 16),
      const Text('Nothing due today', style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w700, color: AppColors.label)),
      const SizedBox(height: 6),
      const Text('Add a task to get started',
          style: TextStyle(fontSize: 14, color: AppColors.label3)),
      const SizedBox(height: 24),
      SizedBox(
        width: 160,
        child: FilledButton(
          onPressed: _openAddTask,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 46),
            backgroundColor: AppColors.accent,
          ),
          child: const Text('Add task'),
        ),
      ),
    ]),
  );
}

// ── Task card ────────────────────────────────────────────────────────────────

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow,
        ),
        child: Row(children: [
          // Priority bar
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: isDone || isFailed
                  ? AppColors.separator
                  : AppColors.priorityColor(priority),
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
                  isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isDone ? AppColors.success : AppColors.separator,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Text
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
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (time != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.access_time, size: 12, color: AppColors.label3),
                  const SizedBox(width: 3),
                  Text(time, style: const TextStyle(fontSize: 12, color: AppColors.label3)),
                ]),
              ],
            ],
          )),

          // Status chip
          if (isFailed || isDone) ...[
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDone ? AppColors.successBg : AppColors.destructiveBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDone ? 'Done' : 'Failed',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: isDone ? AppColors.success : AppColors.destructive,
                ),
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.priorityBg(priority),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                priority[0].toUpperCase() + priority.substring(1),
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.priorityColor(priority),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}

// ── Ring progress ─────────────────────────────────────────────────────────────

class _RingProgress extends StatelessWidget {
  final double progress;
  const _RingProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52, height: 52,
      child: CustomPaint(
        painter: _RingPainter(progress),
        child: Center(
          child: Text('${(progress * 100).round()}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width - 6) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()..color = Colors.white.withValues(alpha: 0.2)
               ..style = PaintingStyle.stroke
               ..strokeWidth = 5
               ..strokeCap = StrokeCap.round);

    // Fill
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false,
          Paint()..color = Colors.white
                 ..style = PaintingStyle.stroke
                 ..strokeWidth = 5
                 ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Gradient FAB ─────────────────────────────────────────────────────────────

class _GradientFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _GradientFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9B7AFF), Color(0xFF5B3FD9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

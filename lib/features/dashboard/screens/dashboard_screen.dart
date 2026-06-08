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
    final tasks   = await SupabaseService.getTodayTasks();
    final profile = await SupabaseService.getUserProfile();
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
        _tasks = tasks;
        _tier  = profile?['subscription_tier'] ?? AppConstants.tierFree;
        _loading = false;
      });
    }
  }

  Future<void> _openAddTask() async {
    final result = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddTaskScreen()));
    if (result == true && mounted) _load();
  }

  Future<void> _openDetail(Map<String, dynamic> task) async {
    final result = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task['id'])));
    if (result != null && mounted) _load();
  }

  Future<void> _openVerification(Map<String, dynamic> task) async {
    final canVerify = [
      AppConstants.tierPro,
      AppConstants.tierPremium,
      AppConstants.tierAdmin,
    ].contains(_tier);
    if (!canVerify) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade to Pro to verify tasks')),
      );
      return;
    }
    final result = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(taskId: task['id'], taskTitle: task['title']),
    ));
    if (result != null && mounted) _load();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _tier == AppConstants.tierAdmin;
    final done  = _tasks.where((t) => t['status'] == 'verified').length;
    final total = _tasks.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(children: [
          const Text('SmartCalendar'),
          if (isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('CEO',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB8860B))),
            ),
          ],
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
            : CustomScrollView(
                slivers: [
                  // Greeting + progress
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_greeting,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                        const SizedBox(height: 3),
                        Text(
                          total == 0 ? 'No tasks today' : '$done of $total done',
                          style: const TextStyle(fontSize: 14, color: AppColors.label3),
                        ),
                        if (total > 0) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: done / total,
                            minHeight: 2,
                            backgroundColor: AppColors.separator,
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),

                  // Task list
                  if (_tasks.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('No tasks today',
                              style: TextStyle(fontSize: 16, color: AppColors.label3)),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _openAddTask, child: const Text('Add one')),
                        ]),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          if (i >= _tasks.length) return const SizedBox(height: 80);
                          final t      = _tasks[i];
                          final status = t['status'] as String? ?? 'pending';
                          final isDone = status == 'verified';
                          final time   = t['scheduled_time'] != null
                              ? DateTime.parse(t['scheduled_time']).toString().substring(11, 16)
                              : null;

                          return Column(children: [
                            ListTile(
                              onTap: () => _openDetail(t),
                              leading: GestureDetector(
                                onTap: isDone ? null : () => _openVerification(t),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isDone ? Icons.check_circle : Icons.circle_outlined,
                                    color: isDone ? AppColors.success : AppColors.separator,
                                    size: 22,
                                  ),
                                ),
                              ),
                              title: Text(
                                t['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDone ? AppColors.label3 : AppColors.label,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: time != null
                                  ? Text(time,
                                      style: const TextStyle(fontSize: 13, color: AppColors.label3))
                                  : null,
                              trailing: _dot(t['priority']),
                            ),
                            if (i < _tasks.length - 1)
                              const Divider(height: 1, indent: 56),
                          ]);
                        },
                        childCount: _tasks.length + 1,
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTask,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 1,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _dot(String? p) {
    final color = switch (p) {
      'high'   => AppColors.destructive,
      'medium' => AppColors.warning,
      _        => AppColors.separator,
    };
    return Container(
      width: 7, height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

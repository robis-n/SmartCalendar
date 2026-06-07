import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../../tasks/screens/add_task_screen.dart';
import '../../verification/screens/verification_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Map<String, dynamic>> _tasks = [];
  String _tier = AppConstants.tierFree;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tasks = await SupabaseService.getTodayTasks();
    final profile = await SupabaseService.getUserProfile();
    setState(() {
      _tasks = tasks;
      _tier = profile?['subscription_tier'] ?? AppConstants.tierFree;
      _loading = false;
    });
  }

  Future<void> _openAddTask() async {
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTaskScreen()));
    if (result == true) _load();
  }

  Future<void> _openVerification(Map<String, dynamic> task) async {
    final canVerify = [AppConstants.tierPro, AppConstants.tierPremium, AppConstants.tierAdmin].contains(_tier);
    if (!canVerify) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade to Pro to verify tasks')));
      return;
    }
    final result = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(taskId: task['id'], taskTitle: task['title']),
    ));
    if (result != null) _load();
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
    final done = _tasks.where((t) => t['status'] == 'verified').length;
    final total = _tasks.length;

    return Scaffold(
      backgroundColor: AppColors.bg2,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.bg,
              surfaceTintColor: Colors.transparent,
              title: Row(children: [
                const Text('SmartCalendar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Text('CEO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB8860B))),
                  ),
                ],
              ]),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_greeting, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Text(
                    total == 0 ? 'No tasks today' : '$done of $total tasks completed',
                    style: const TextStyle(fontSize: 15, color: AppColors.label3),
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 4,
                        backgroundColor: AppColors.separator,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('TODAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.label3, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                ]),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_tasks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle_outline, size: 52, color: AppColors.separator),
                    const SizedBox(height: 12),
                    const Text('All clear', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('Add a task to get started', style: TextStyle(fontSize: 15, color: AppColors.label3)),
                    const SizedBox(height: 20),
                    TextButton(onPressed: _openAddTask, child: const Text('Add Task', style: TextStyle(color: AppColors.accent, fontSize: 17))),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i == _tasks.length) return const SizedBox(height: 80);
                      final t = _tasks[i];
                      final status = t['status'] as String? ?? 'pending';
                      final isDone = status == 'verified';
                      return Column(
                        children: [
                          Container(
                            color: AppColors.bg,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: GestureDetector(
                                onTap: isDone ? null : () => _openVerification(t),
                                child: Icon(
                                  isDone ? Icons.check_circle : Icons.circle_outlined,
                                  color: isDone ? AppColors.success : AppColors.separator,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                t['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDone ? AppColors.label3 : AppColors.label,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (t['scheduled_time'] != null)
                                  Text(
                                    DateTime.parse(t['scheduled_time']).toString().substring(11, 16),
                                    style: const TextStyle(fontSize: 13, color: AppColors.label3),
                                  ),
                                if (t['ai_reasoning'] != null && !isDone)
                                  Text('AI: ${t['ai_reasoning']}', style: const TextStyle(fontSize: 12, color: AppColors.accent)),
                              ]),
                              trailing: _priorityDot(t['priority']),
                            ),
                          ),
                          if (i < _tasks.length - 1)
                            const Divider(height: 0, indent: 56),
                        ],
                      );
                    },
                    childCount: _tasks.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTask,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _priorityDot(String? p) {
    final color = switch(p) { 'high' => AppColors.destructive, 'medium' => AppColors.warning, _ => AppColors.success };
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

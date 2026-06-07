import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
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
  void initState() {
    super.initState();
    _load();
  }

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
    final canVerify = _tier == AppConstants.tierPro || _tier == AppConstants.tierPremium || _tier == AppConstants.tierAdmin;
    if (!canVerify) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade to Pro to use photo verification')));
      return;
    }
    final result = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(taskId: task['id'], taskTitle: task['title']),
    ));
    if (result != null) _load();
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      default: return Colors.green;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'verified': return Colors.green;
      case 'failed': return Colors.red;
      case 'in_progress': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'verified': return Icons.check_circle;
      case 'failed': return Icons.cancel;
      case 'in_progress': return Icons.play_circle;
      default: return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin = _tier == AppConstants.tierAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('SmartCalendar'),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(20)),
              child: const Text('CEO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.workspace_premium), onPressed: () => context.go('/subscriptions'), tooltip: 'Subscription'),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (mounted) context.go('/login');
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        isAdmin ? 'Welcome back, CEO 👑' : 'Today\'s Tasks',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      // Stats row
                      Row(children: [
                        _statCard('Total', _tasks.length.toString(), Icons.list_alt, Colors.blue),
                        const SizedBox(width: 12),
                        _statCard('Done', _tasks.where((t) => t['status'] == 'verified').length.toString(), Icons.check_circle, Colors.green),
                        const SizedBox(width: 12),
                        _statCard('Pending', _tasks.where((t) => t['status'] == 'pending').length.toString(), Icons.pending, Colors.orange),
                      ]),
                    ]),
                  ),
                ),
                if (_tasks.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.task_alt, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No tasks for today', style: TextStyle(color: Colors.grey)),
                      Text('Tap + to add one', style: TextStyle(color: Colors.grey)),
                    ])),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final task = _tasks[i];
                          final status = task['status'] as String?;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(_statusIcon(status), color: _statusColor(status)),
                              title: Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (task['scheduled_time'] != null)
                                  Text(DateTime.parse(task['scheduled_time']).toString().substring(11, 16), style: const TextStyle(fontSize: 12)),
                                if (task['ai_reasoning'] != null)
                                  Text('AI: ${task['ai_reasoning']}', style: const TextStyle(fontSize: 11, color: Color(0xFF6C63FF))),
                              ]),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: _priorityColor(task['priority']), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                if (status == 'pending' || status == 'in_progress')
                                  IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () => _openVerification(task), tooltip: 'Verify'),
                              ]),
                            ),
                          );
                        },
                        childCount: _tasks.length,
                      ),
                    ),
                  ),
              ],
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await SupabaseService.getTodayTasks();
    setState(() { _tasks = tasks; _loading = false; });
  }

  int get _total => _tasks.length;
  int get _done => _tasks.where((t) => t['status'] == 'verified').length;
  int get _pending => _tasks.where((t) => t['status'] == 'pending').length;
  int get _failed => _tasks.where((t) => t['status'] == 'failed').length;
  double get _rate => _total == 0 ? 0 : _done / _total;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('Analytics'), backgroundColor: AppColors.bg),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('${(_rate * 100).round()}%', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, color: AppColors.accent, letterSpacing: -2)),
              const Text('Completion Rate Today', style: TextStyle(fontSize: 13, color: AppColors.label3)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _rate, minHeight: 6, backgroundColor: AppColors.separator, color: AppColors.accent),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _statTile('Total', _total.toString(), AppColors.accent),
            const SizedBox(width: 8),
            _statTile('Done', _done.toString(), AppColors.success),
            const SizedBox(width: 8),
            _statTile('Pending', _pending.toString(), AppColors.warning),
            const SizedBox(width: 8),
            _statTile('Failed', _failed.toString(), AppColors.destructive),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _row('Tasks Completed', '$_done / $_total', AppColors.success),
              const Divider(height: 0, indent: 16),
              _row('AI Scheduled', '${_tasks.where((t) => t['ai_generated'] == true).length}', AppColors.accent),
              const Divider(height: 0, indent: 16),
              _row('High Priority', '${_tasks.where((t) => t['priority'] == 'high').length}', AppColors.destructive),
              const Divider(height: 0, indent: 16),
              _row('Photo Verified', '${_tasks.where((t) => t['status'] == 'verified').length}', AppColors.success),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.label3)),
      ]),
    ),
  );

  Widget _row(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 15)),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

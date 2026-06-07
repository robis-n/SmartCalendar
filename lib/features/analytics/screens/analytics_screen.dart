import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await SupabaseService.getAnalyticsSummary();
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  int get _total => (_stats['total'] as int?) ?? 0;
  int get _done => (_stats['done'] as int?) ?? 0;
  int get _failed => (_stats['failed'] as int?) ?? 0;
  int get _pending => (_stats['pending'] as int?) ?? 0;
  double get _rate => (_stats['rate'] as num?)?.toDouble() ?? 0;
  int get _weekTotal => (_stats['week_total'] as int?) ?? 0;
  int get _weekDone => (_stats['week_done'] as int?) ?? 0;
  int get _highPriority => (_stats['high_priority'] as int?) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.bg,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Overall completion rate ─────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text(
                        '${(_rate * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: -2,
                        ),
                      ),
                      const Text(
                        'All-Time Completion Rate',
                        style: TextStyle(fontSize: 13, color: AppColors.label3),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _rate,
                          minHeight: 6,
                          backgroundColor: AppColors.separator,
                          color: AppColors.accent,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Stats row ───────────────────────────
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

                  // ── This week ───────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(children: [
                          const Text('THIS WEEK', style: TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                          const Spacer(),
                          Text(
                            '$_weekDone / $_weekTotal tasks',
                            style: const TextStyle(fontSize: 13, color: AppColors.label3),
                          ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _weekTotal == 0 ? 0 : _weekDone / _weekTotal,
                            minHeight: 8,
                            backgroundColor: AppColors.separator,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── Breakdown ───────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      _row('Tasks Verified', '$_done / $_total', AppColors.success),
                      const Divider(height: 0, indent: 16),
                      _row('Tasks Failed', '$_failed', AppColors.destructive),
                      const Divider(height: 0, indent: 16),
                      _row('High Priority', '$_highPriority', AppColors.destructive),
                      const Divider(height: 0, indent: 16),
                      _row('This Week', '$_weekTotal tasks', AppColors.accent),
                    ]),
                  ),

                  if (_total == 0) ...[
                    const SizedBox(height: 32),
                    Center(
                      child: Column(children: [
                        const Icon(Icons.bar_chart_outlined, size: 48, color: AppColors.separator),
                        const SizedBox(height: 12),
                        const Text('No data yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('Create tasks to see your analytics', style: TextStyle(fontSize: 15, color: AppColors.label3)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
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

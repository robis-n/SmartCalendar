import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _s = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await SupabaseService.getAnalyticsSummary();
    if (mounted) setState(() { _s = s; _loading = false; });
  }

  int    get total     => (_s['total']         as int?)  ?? 0;
  int    get done      => (_s['done']          as int?)  ?? 0;
  int    get failed    => (_s['failed']        as int?)  ?? 0;
  int    get pending   => (_s['pending']       as int?)  ?? 0;
  double get rate      => (_s['rate']          as num?)?.toDouble() ?? 0;
  int    get weekTotal => (_s['week_total']    as int?)  ?? 0;
  int    get weekDone  => (_s['week_done']     as int?)  ?? 0;
  int    get highPrio  => (_s['high_priority'] as int?)  ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          // Gradient header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: _loading
                      ? const SizedBox(height: 100,
                          child: Center(child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Analytics',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: -0.8)),
                          const SizedBox(height: 16),
                          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${(rate * 100).round()}%',
                                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: -3, height: 1)),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10, left: 10),
                              child: Text('completion',
                                  style: TextStyle(fontSize: 15,
                                      color: Colors.white.withValues(alpha: 0.75))),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rate, minHeight: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ]),
                ),
              ),
            ),
          ),

          if (!_loading) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate([
                  _StatCard(label: 'Total',   value: '$total',   icon: Icons.list_rounded,
                      color: AppColors.accent,      bg: AppColors.accentLight),
                  _StatCard(label: 'Done',    value: '$done',    icon: Icons.check_circle_rounded,
                      color: AppColors.success,     bg: AppColors.successBg),
                  _StatCard(label: 'Failed',  value: '$failed',  icon: Icons.cancel_rounded,
                      color: AppColors.destructive, bg: AppColors.destructiveBg),
                  _StatCard(label: 'Pending', value: '$pending', icon: Icons.pending_rounded,
                      color: AppColors.warning,     bg: AppColors.warningBg),
                ]),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(children: [
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppColors.accent, iconBg: AppColors.accentLight,
                    title: '$weekDone of $weekTotal tasks',
                    subtitle: 'completed this week',
                    trailing: weekTotal > 0
                        ? '${(weekDone / weekTotal * 100).round()}%' : null,
                  ),
                  if (highPrio > 0) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.flag_rounded,
                      iconColor: AppColors.destructive, iconBg: AppColors.destructiveBg,
                      title: '$highPrio high priority',
                      subtitle: 'tasks need attention',
                    ),
                  ],
                ]),
              ),
            ),

            if (total == 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(children: const [
                    Text('📊', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('No data yet', style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.w700, color: AppColors.label3)),
                    SizedBox(height: 4),
                    Text('Complete some tasks to see your stats',
                        style: TextStyle(fontSize: 14, color: AppColors.label3)),
                  ]),
                ),
              ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _StatCard({required this.label, required this.value,
      required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -0.5, height: 1)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.label3)),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle;
  final String? trailing;
  const _InfoRow({required this.icon, required this.iconColor, required this.iconBg,
      required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: cardShadow,
    ),
    child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
            color: AppColors.label, letterSpacing: -0.3)),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.label3)),
      ]),
      if (trailing != null) ...[
        const Spacer(),
        Text(trailing!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
            color: AppColors.accent)),
      ],
    ]),
  );
}

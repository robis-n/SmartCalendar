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
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          // ── Editorial header — no gradient, just bold type ──
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Brand label
                  const Text('ANALYTICS',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.accent, letterSpacing: 2.0,
                    )),
                  const SizedBox(height: 24),

                  if (_loading)
                    const SizedBox(height: 120,
                        child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)))
                  else ...[
                    // Giant completion number — editorial hero
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${(rate * 100).round()}',
                        style: const TextStyle(
                          fontSize: 80, fontWeight: FontWeight.w900,
                          color: AppColors.label, height: 1,
                          letterSpacing: -4,
                        )),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: Text('%',
                          style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w900,
                            color: AppColors.accent, height: 1,
                          )),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    const Text('completion rate',
                      style: TextStyle(
                        fontSize: 14, color: AppColors.label3,
                        fontWeight: FontWeight.w400,
                      )),
                    const SizedBox(height: 16),

                    // Progress bar — gold
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 3,
                        backgroundColor: AppColors.separator,
                        valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Divider line — editorial
                  Container(height: 0.5, color: AppColors.separator),
                ]),
              ),
            ),
          ),

          if (!_loading) ...[
            // ── 2×2 stat grid ─────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate([
                  _StatCard(label: 'TOTAL',   value: '$total',   color: AppColors.accent,      bg: AppColors.accentLight),
                  _StatCard(label: 'DONE',    value: '$done',    color: AppColors.success,     bg: AppColors.successBg),
                  _StatCard(label: 'FAILED',  value: '$failed',  color: AppColors.destructive, bg: AppColors.destructiveBg),
                  _StatCard(label: 'PENDING', value: '$pending', color: AppColors.warning,     bg: AppColors.warningBg),
                ]),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
              ),
            ),

            // ── Info rows ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(children: [
                  _InfoRow(
                    label: 'THIS WEEK',
                    value: '$weekDone / $weekTotal',
                    sub: 'tasks completed',
                    trailing: weekTotal > 0
                        ? '${(weekDone / weekTotal * 100).round()}%' : '—',
                    trailColor: AppColors.accent,
                  ),
                  if (highPrio > 0) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'HIGH PRIORITY',
                      value: '$highPrio',
                      sub: 'need attention',
                      trailing: '!',
                      trailColor: AppColors.destructive,
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
                    Text('No data yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                            color: AppColors.label3)),
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
  final Color color, bg;
  const _StatCard({required this.label, required this.value,
      required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.7), letterSpacing: 1.5)),
      const Spacer(),
      Text(value,
        style: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -1.5, height: 1,
        )),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value, sub, trailing;
  final Color trailColor;
  const _InfoRow({required this.label, required this.value, required this.sub,
      required this.trailing, required this.trailColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
              color: AppColors.label3, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.label, letterSpacing: -0.5)),
        Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.label3)),
      ]),
      const Spacer(),
      Text(trailing,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
            color: trailColor, letterSpacing: -1)),
    ]),
  );
}

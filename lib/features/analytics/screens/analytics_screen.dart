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
        color: AppColors.label,
        backgroundColor: AppColors.card,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Back + title
                  Row(children: [
                    _BackButton(),
                    const SizedBox(width: 14),
                    Text('Statistics',
                      style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800,
                        color: AppColors.label, letterSpacing: -1.2,
                      )),
                  ]),
                  const SizedBox(height: 28),

                  if (_loading)
                    SizedBox(height: 120,
                        child: Center(child: CircularProgressIndicator(
                            color: AppColors.label, strokeWidth: 2)))
                  else ...[
                    // Giant completion number
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${(rate * 100).round()}',
                        style: TextStyle(
                          fontSize: 96, fontWeight: FontWeight.w800,
                          color: AppColors.label, height: 1,
                          letterSpacing: -5,
                        )),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, left: 4),
                        child: Text('%',
                          style: TextStyle(
                            fontSize: 36, fontWeight: FontWeight.w800,
                            color: AppColors.label3, height: 1,
                          )),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('completion rate',
                      style: TextStyle(
                        fontSize: 15, color: AppColors.label3,
                        fontWeight: FontWeight.w400,
                      )),
                    const SizedBox(height: 18),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 4,
                        backgroundColor: AppColors.separator,
                        valueColor: AlwaysStoppedAnimation(AppColors.label),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Container(height: 0.5, color: AppColors.separator),
                ]),
              ),
            ),
          ),

          if (!_loading) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate([
                  _StatCard(label: 'TOTAL',  value: '$total'),
                  _StatCard(label: 'DONE',   value: '$done'),
                  _StatCard(label: 'MISSED', value: '$failed'),
                  _StatCard(label: 'LEFT',   value: '$pending'),
                ]),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
              ),
            ),

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
                  ),
                  if (highPrio > 0) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'HIGH PRIORITY',
                      value: '$highPrio',
                      sub: 'need attention',
                      trailing: '!',
                    ),
                  ],
                ]),
              ),
            ),

            if (total == 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(children: [
                    Text('No data yet',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                            color: AppColors.label)),
                    const SizedBox(height: 6),
                    Text('Complete some tasks to see your stats',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: AppColors.label3)),
                  ]),
                ),
              ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ]),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(context).maybePop(),
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppColors.bg2,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.separator, width: 0.8),
      ),
      child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.label),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
            color: AppColors.label3, letterSpacing: 1.5)),
      const Spacer(),
      Text(value,
        style: TextStyle(
          fontSize: 42, fontWeight: FontWeight.w800,
          color: AppColors.label, letterSpacing: -2, height: 1,
        )),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value, sub, trailing;
  const _InfoRow({required this.label, required this.value, required this.sub,
      required this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.separator, width: 0.5),
      boxShadow: cardShadow,
    ),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              color: AppColors.label3, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Text(value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
              color: AppColors.label, letterSpacing: -0.5)),
        Text(sub, style: TextStyle(fontSize: 13, color: AppColors.label3)),
      ]),
      const Spacer(),
      Text(trailing,
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
            color: AppColors.label, letterSpacing: -1)),
    ]),
  );
}

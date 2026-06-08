import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused  = DateTime.now();
  DateTime _selected = DateTime.now();
  List<Map<String, dynamic>> _dayTasks   = [];
  List<Map<String, dynamic>> _monthTasks = [];
  bool _loading = false;

  static const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _mn = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  @override
  void initState() { super.initState(); _loadMonth(_focused); _loadDay(_selected); }

  Future<void> _loadMonth(DateTime m) async {
    final t = await SupabaseService.getTasksForMonth(m.year, m.month);
    if (mounted) setState(() => _monthTasks = t);
  }

  Future<void> _loadDay(DateTime d) async {
    if (mounted) setState(() => _loading = true);
    final t = await SupabaseService.getTasksForDate(d);
    if (mounted) setState(() { _dayTasks = t; _loading = false; });
  }

  void _prev() {
    final p = DateTime(_focused.year, _focused.month - 1);
    setState(() => _focused = p);
    _loadMonth(p);
  }

  void _next() {
    final n = DateTime(_focused.year, _focused.month + 1);
    setState(() => _focused = n);
    _loadMonth(n);
  }

  void _tap(int day) {
    final d = DateTime(_focused.year, _focused.month, day);
    setState(() => _selected = d);
    _loadDay(d);
  }

  int get _days => DateTime(_focused.year, _focused.month + 1, 0).day;
  int get _start => DateTime(_focused.year, _focused.month, 1).weekday;

  bool _isToday(int d) {
    final n = DateTime.now();
    return _focused.year == n.year && _focused.month == n.month && d == n.day;
  }
  bool _isSel(int d) =>
      _focused.year == _selected.year && _focused.month == _selected.month && d == _selected.day;
  bool _hasDot(int d) => _monthTasks.any((t) {
    if (t['scheduled_time'] == null) return false;
    final dt = DateTime.tryParse(t['scheduled_time']);
    return dt != null && dt.year == _focused.year && dt.month == _focused.month && dt.day == d;
  });

  String get _dayLabel {
    final n = DateTime.now();
    if (_selected.year == n.year && _selected.month == n.month && _selected.day == n.day) return 'Today';
    return '${_mn[_selected.month - 1]} ${_selected.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // ── Gradient Header ───────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(children: [
                // Title row
                const Row(children: [
                  Text('Calendar',
                    style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.5,
                    )),
                ]),
                const SizedBox(height: 16),
                // Month nav
                Row(children: [
                  GestureDetector(
                    onTap: _prev,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_mn[_focused.month - 1]} ${_focused.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Calendar Card ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: cardShadow,
            ),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(children: [
              // Weekday labels
              Row(
                children: _wd.map((d) => Expanded(
                  child: Text(d, textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w600,
                    )),
                )).toList(),
              ),
              const SizedBox(height: 8),
              // Day grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, childAspectRatio: 1,
                ),
                itemCount: (_start - 1) + _days,
                itemBuilder: (ctx, i) {
                  if (i < _start - 1) return const SizedBox();
                  final d = i - (_start - 2);
                  final today = _isToday(d);
                  final sel   = _isSel(d);
                  final dot   = _hasDot(d);
                  return GestureDetector(
                    onTap: () => _tap(d),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: sel ? AppColors.accent : today ? AppColors.accentLight : null,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('$d', style: TextStyle(
                          fontSize: 14,
                          fontWeight: today || sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel ? Colors.white : today ? AppColors.accent : AppColors.label,
                        )),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          color: dot ? (sel ? Colors.white70 : AppColors.accent) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ]),
          ),
        ),

        const SizedBox(height: 16),

        // ── Day label ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text(_dayLabel.toUpperCase(),
              style: const TextStyle(
                fontSize: 11, color: AppColors.label3,
                fontWeight: FontWeight.w700, letterSpacing: 0.8,
              )),
            const Spacer(),
            if (_dayTasks.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_dayTasks.length}',
                  style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(height: 8),

        // ── Task list ──────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))
              : _dayTasks.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_today_outlined, size: 40, color: AppColors.label3.withValues(alpha: 0.4)),
                        const SizedBox(height: 10),
                        const Text('No tasks', style: TextStyle(fontSize: 15, color: AppColors.label3)),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: _dayTasks.length,
                      separatorBuilder: (_, sep) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final t = _dayTasks[i];
                        final status = t['status'] as String? ?? 'pending';
                        final isDone = status == 'verified';
                        final isFailed = status == 'failed';
                        final time = t['scheduled_time'] != null
                            ? DateTime.parse(t['scheduled_time']).toString().substring(11, 16)
                            : null;
                        final (statusColor, bgColor) = isDone
                            ? (AppColors.success, AppColors.successBg)
                            : isFailed
                                ? (AppColors.destructive, AppColors.destructiveBg)
                                : (AppColors.accent, AppColors.accentLight);
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: cardShadow,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(t['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDone ? AppColors.label3 : AppColors.label,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                )),
                            ),
                            if (time != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(time,
                                  style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

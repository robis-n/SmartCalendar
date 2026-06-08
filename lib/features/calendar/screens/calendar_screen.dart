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
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Calendar')),
      body: Column(children: [
        // ── Month nav ──────────────────────────────────
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.accent), onPressed: _prev),
          Expanded(child: Text(
            '${_mn[_focused.month - 1]} ${_focused.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          )),
          IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.accent), onPressed: _next),
        ]),

        // ── Weekday labels ─────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: _wd.map((d) => Expanded(
            child: Text(d, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w500)),
          )).toList()),
        ),
        const SizedBox(height: 4),

        // ── Day grid ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
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
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.accent : today ? AppColors.accent.withValues(alpha: 0.12) : null,
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
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),

        // ── Day task list ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(children: [
            Text(_dayLabel.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: AppColors.label3,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const Spacer(),
            if (_dayTasks.isNotEmpty)
              Text('${_dayTasks.length}',
                  style: const TextStyle(fontSize: 11, color: AppColors.label3)),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
              : _dayTasks.isEmpty
                  ? const Center(child: Text('No tasks', style: TextStyle(fontSize: 15, color: AppColors.label3)))
                  : ListView.separated(
                      itemCount: _dayTasks.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 20),
                      itemBuilder: (ctx, i) {
                        final t = _dayTasks[i];
                        final status = t['status'] as String? ?? 'pending';
                        final isDone = status == 'verified';
                        final time = t['scheduled_time'] != null
                            ? DateTime.parse(t['scheduled_time']).toString().substring(11, 16)
                            : null;
                        return ListTile(
                          leading: Icon(
                            isDone ? Icons.check_circle : Icons.circle_outlined,
                            color: isDone ? AppColors.success : AppColors.separator,
                            size: 20,
                          ),
                          title: Text(t['title'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDone ? AppColors.label3 : AppColors.label,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              )),
                          trailing: time != null
                              ? Text(time, style: const TextStyle(fontSize: 13, color: AppColors.label3))
                              : null,
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

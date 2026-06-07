import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  List<Map<String, dynamic>> _tasks = [];

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await SupabaseService.getTodayTasks();
    setState(() => _tasks = tasks);
  }

  int get _daysInMonth => DateTime(_focused.year, _focused.month + 1, 0).day;
  int get _firstWeekday => DateTime(_focused.year, _focused.month, 1).weekday;

  void _prevMonth() => setState(() => _focused = DateTime(_focused.year, _focused.month - 1));
  void _nextMonth() => setState(() => _focused = DateTime(_focused.year, _focused.month + 1));

  bool _isToday(int day) {
    final now = DateTime.now();
    return _focused.year == now.year && _focused.month == now.month && day == now.day;
  }

  bool _isSelected(int day) => _focused.year == _selected.year && _focused.month == _selected.month && day == _selected.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppColors.bg,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.bg,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(children: [
              // Month nav
              Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.accent), onPressed: _prevMonth),
                Expanded(child: Text('${_months[_focused.month - 1]} ${_focused.year}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.accent), onPressed: _nextMonth),
              ]),
              const SizedBox(height: 8),
              // Weekday headers
              Row(children: _weekdays.map((d) => Expanded(
                child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w500)),
              )).toList()),
              const SizedBox(height: 8),
              // Days grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
                itemCount: (_firstWeekday - 1) + _daysInMonth,
                itemBuilder: (ctx, i) {
                  if (i < _firstWeekday - 1) return const SizedBox();
                  final day = i - (_firstWeekday - 2);
                  final isToday = _isToday(day);
                  final isSel = _isSelected(day);
                  return GestureDetector(
                    onTap: () => setState(() => _selected = DateTime(_focused.year, _focused.month, day)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.accent : isToday ? AppColors.accent.withOpacity(0.1) : null,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text('$day', style: TextStyle(
                        fontSize: 15,
                        fontWeight: isToday || isSel ? FontWeight.w600 : FontWeight.w400,
                        color: isSel ? Colors.white : isToday ? AppColors.accent : AppColors.label,
                      )),
                    ),
                  );
                },
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _tasks.isEmpty
              ? const Center(child: Text('No tasks for today', style: TextStyle(color: AppColors.label3)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const Divider(indent: 16),
                  itemBuilder: (ctx, i) {
                    final t = _tasks[i];
                    return Container(
                      color: AppColors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        Container(width: 4, height: 36, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          if (t['scheduled_time'] != null)
                            Text(DateTime.parse(t['scheduled_time']).toString().substring(11, 16), style: const TextStyle(fontSize: 13, color: AppColors.label3)),
                        ])),
                        _statusDot(t['status']),
                      ]),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _statusDot(String? status) {
    Color c = switch(status) {
      'verified' => AppColors.success,
      'failed' => AppColors.destructive,
      'in_progress' => AppColors.accent,
      _ => AppColors.separator,
    };
    return Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}

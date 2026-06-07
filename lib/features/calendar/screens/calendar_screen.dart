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
  List<Map<String, dynamic>> _selectedDayTasks = [];
  List<Map<String, dynamic>> _monthTasks = [];
  bool _loading = false;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  @override
  void initState() {
    super.initState();
    _loadMonth(_focused);
    _loadDay(_selected);
  }

  Future<void> _loadMonth(DateTime month) async {
    final tasks = await SupabaseService.getTasksForMonth(month.year, month.month);
    setState(() => _monthTasks = tasks);
  }

  Future<void> _loadDay(DateTime day) async {
    setState(() => _loading = true);
    final tasks = await SupabaseService.getTasksForDate(day);
    setState(() { _selectedDayTasks = tasks; _loading = false; });
  }

  void _selectDay(int day) {
    final date = DateTime(_focused.year, _focused.month, day);
    setState(() => _selected = date);
    _loadDay(date);
  }

  void _prevMonth() {
    final prev = DateTime(_focused.year, _focused.month - 1);
    setState(() => _focused = prev);
    _loadMonth(prev);
  }

  void _nextMonth() {
    final next = DateTime(_focused.year, _focused.month + 1);
    setState(() => _focused = next);
    _loadMonth(next);
  }

  int get _daysInMonth => DateTime(_focused.year, _focused.month + 1, 0).day;
  int get _firstWeekday => DateTime(_focused.year, _focused.month, 1).weekday;

  bool _isToday(int day) {
    final now = DateTime.now();
    return _focused.year == now.year && _focused.month == now.month && day == now.day;
  }

  bool _isSelected(int day) =>
      _focused.year == _selected.year &&
      _focused.month == _selected.month &&
      day == _selected.day;

  bool _hasTask(int day) => _monthTasks.any((t) {
    if (t['scheduled_time'] == null) return false;
    final d = DateTime.tryParse(t['scheduled_time']);
    return d != null && d.year == _focused.year && d.month == _focused.month && d.day == day;
  });

  String get _selectedLabel {
    final now = DateTime.now();
    if (_selected.year == now.year && _selected.month == now.month && _selected.day == now.day) {
      return 'TODAY';
    }
    return '${_months[_selected.month - 1].toUpperCase()} ${_selected.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(title: const Text('Calendar'), backgroundColor: AppColors.bg),
      body: Column(
        children: [
          Container(
            color: AppColors.bg,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
            child: Column(children: [
              // Month nav
              Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.accent), onPressed: _prevMonth),
                Expanded(child: Text(
                  '${_months[_focused.month - 1]} ${_focused.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                )),
                IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.accent), onPressed: _nextMonth),
              ]),
              const SizedBox(height: 8),
              // Weekday headers
              Row(children: _weekdays.map((d) => Expanded(
                child: Text(d, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.label3, fontWeight: FontWeight.w500)),
              )).toList()),
              const SizedBox(height: 6),
              // Days grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, mainAxisSpacing: 2, crossAxisSpacing: 2, childAspectRatio: 1),
                itemCount: (_firstWeekday - 1) + _daysInMonth,
                itemBuilder: (ctx, i) {
                  if (i < _firstWeekday - 1) return const SizedBox();
                  final day = i - (_firstWeekday - 2);
                  final isToday = _isToday(day);
                  final isSel = _isSelected(day);
                  final hasTask = _hasTask(day);
                  return GestureDetector(
                    onTap: () => _selectDay(day),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: isSel ? AppColors.accent : isToday ? AppColors.accent.withValues(alpha: 0.12) : null,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text('$day', style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday || isSel ? FontWeight.w600 : FontWeight.w400,
                            color: isSel ? Colors.white : isToday ? AppColors.accent : AppColors.label,
                          )),
                        ),
                        const SizedBox(height: 2),
                        // Task dot indicator
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            color: hasTask ? (isSel ? Colors.white70 : AppColors.accent) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ]),
          ),
          // Selected day tasks
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Text(_selectedLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.label3, letterSpacing: 0.5)),
              const Spacer(),
              if (_selectedDayTasks.isNotEmpty)
                Text('${_selectedDayTasks.length} task${_selectedDayTasks.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.label3)),
            ]),
          ),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _selectedDayTasks.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.event_available, size: 40, color: AppColors.separator),
                    const SizedBox(height: 8),
                    Text('No tasks on $_selectedLabel', style: const TextStyle(color: AppColors.label3, fontSize: 15)),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedDayTasks.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 0, indent: 16),
                    itemBuilder: (ctx, i) {
                      final t = _selectedDayTasks[i];
                      final status = t['status'] as String? ?? 'pending';
                      final isDone = status == 'verified';
                      return Container(
                        color: AppColors.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 4, height: 36,
                            decoration: BoxDecoration(
                              color: isDone ? AppColors.success : AppColors.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t['title'] ?? '', style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? AppColors.label3 : AppColors.label,
                            )),
                            if (t['scheduled_time'] != null)
                              Text(
                                DateTime.parse(t['scheduled_time']).toString().substring(11, 16),
                                style: const TextStyle(fontSize: 13, color: AppColors.label3),
                              ),
                          ])),
                          _statusChip(status),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch(status) {
      'verified' => ('Done', AppColors.success),
      'failed' => ('Failed', AppColors.destructive),
      'in_progress' => ('Active', AppColors.accent),
      _ => ('Pending', AppColors.label3),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

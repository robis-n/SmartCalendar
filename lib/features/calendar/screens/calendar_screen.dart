import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../tasks/screens/add_task_screen.dart';

/// Apple-Calendar-style continuously scrolling month list.
/// Past and future months stream infinitely around the current month
/// (anchored via CustomScrollView `center`). Tap a day to see its
/// reminders; tap a reminder to open its editing screen.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _centerKey = const ValueKey('center-month');
  final _ctrl = ScrollController();
  late final DateTime _base;        // first day of the current month
  DateTime _selected = DateTime.now();
  int _reloadToken = 0;             // bumped to force month grids to refetch

  static const _span = 120;         // months available each direction (~10y)

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _base = DateTime(n.year, n.month);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  DateTime _monthAt(int offset) => DateTime(_base.year, _base.month + offset);

  void _jumpToToday() {
    setState(() => _selected = DateTime.now());
    _ctrl.animateTo(0,
        duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  Future<void> _openDay(DateTime day) async {
    setState(() => _selected = day);
    await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      // Use root navigator so the sheet covers the bottom nav (no peeking),
      // and a near-transparent scrim so the calendar doesn't visibly "dim"
      // — the glass sheet already separates fg from bg by itself.
      useRootNavigator: true,
      barrierColor: AppColors.bg.withValues(alpha: 0.04),
      isScrollControlled: true,
      builder: (_) => _DaySheet(
        day: day,
        onChanged: () { if (mounted) setState(() => _reloadToken++); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // ── Top bar ───────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
            child: Row(children: [
              Text('Calendar',
                style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800,
                  color: AppColors.label, letterSpacing: -1.2,
                )),
              const Spacer(),
              GestureDetector(
                onTap: _jumpToToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.separator, width: 0.8),
                  ),
                  child: Text('Today',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.label,
                    )),
                ),
              ),
            ]),
          ),
        ),

        // ── Weekday header (Monday-first, European) ────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: const ['M','T','W','T','F','S','S']
                .map((d) => Expanded(child: _Weekday(d)))
                .toList(),
          ),
        ),
        Container(height: 0.5, color: AppColors.separator),

        // ── Infinite month list ────────────────────────────────
        Expanded(
          child: CustomScrollView(
            controller: _ctrl,
            center: _centerKey,
            slivers: [
              // Past months (grows upward)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MonthView(
                    month: _monthAt(-(i + 1)),
                    selected: _selected,
                    reloadToken: _reloadToken,
                    onTapDay: _openDay,
                  ),
                  childCount: _span,
                ),
              ),
              // Anchor = current month
              SliverToBoxAdapter(
                key: _centerKey,
                child: _MonthView(
                  month: _monthAt(0),
                  selected: _selected,
                  reloadToken: _reloadToken,
                  onTapDay: _openDay,
                ),
              ),
              // Future months
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _MonthView(
                    month: _monthAt(i + 1),
                    selected: _selected,
                    reloadToken: _reloadToken,
                    onTapDay: _openDay,
                  ),
                  childCount: _span,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 130)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Weekday extends StatelessWidget {
  final String d;
  const _Weekday(this.d);
  @override
  Widget build(BuildContext context) => Text(d,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: AppColors.label3, letterSpacing: 0.5,
    ));
}

// ── Month grid ────────────────────────────────────────────────────────────────

class _MonthView extends StatefulWidget {
  final DateTime month;            // first-of-month
  final DateTime selected;
  final int reloadToken;
  final ValueChanged<DateTime> onTapDay;
  const _MonthView({
    required this.month, required this.selected,
    required this.reloadToken, required this.onTapDay,
  });

  @override
  State<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<_MonthView> {
  Set<int> _taskDays = {};

  static const _mn = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void didUpdateWidget(covariant _MonthView old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _load();
  }

  Future<void> _load() async {
    final t = await SupabaseService.getTasksForMonth(widget.month.year, widget.month.month);
    if (!mounted) return;
    setState(() {
      _taskDays = t
          .where((e) => e['scheduled_time'] != null)
          .map((e) => DateTime.parse(e['scheduled_time']).day)
          .toSet();
    });
  }

  int get _daysInMonth => DateTime(widget.month.year, widget.month.month + 1, 0).day;
  // Monday-first column index for the 1st of the month (Mon=0 … Sun=6).
  int get _leadBlanks => DateTime(widget.month.year, widget.month.month, 1).weekday - 1;

  bool _isToday(int d) {
    final n = DateTime.now();
    return n.year == widget.month.year && n.month == widget.month.month && n.day == d;
  }

  bool _isSel(int d) =>
      widget.selected.year == widget.month.year &&
      widget.selected.month == widget.month.month &&
      widget.selected.day == d;

  @override
  Widget build(BuildContext context) {
    final cells = _leadBlanks + _daysInMonth;
    final rows  = (cells / 7).ceil();
    final isCurrentYear = widget.month.year == DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Month title — always carries the year so scrolling reads clearly
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 12),
          child: RichText(text: TextSpan(children: [
            TextSpan(text: _mn[widget.month.month - 1],
              style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800,
                color: AppColors.label, letterSpacing: -0.8,
              )),
            TextSpan(text: '  ${widget.month.year}',
              style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w400,
                color: isCurrentYear ? AppColors.label3 : AppColors.label2,
                letterSpacing: -0.8,
              )),
          ])),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, childAspectRatio: 0.86,
          ),
          itemCount: rows * 7,
          itemBuilder: (ctx, i) {
            if (i < _leadBlanks) return const SizedBox();
            final day = i - _leadBlanks + 1;
            if (day > _daysInMonth) return const SizedBox();

            final today = _isToday(day);
            final sel   = _isSel(day);
            final dot   = _taskDays.contains(day);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTapDay(
                  DateTime(widget.month.year, widget.month.month, day)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: today ? AppColors.label : Colors.transparent,
                    border: (sel && !today)
                        ? Border.all(color: AppColors.label, width: 1.6)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('$day',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: (today || sel) ? FontWeight.w700 : FontWeight.w500,
                      color: today ? AppColors.bg : AppColors.label,
                    )),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot
                        ? (today ? AppColors.bg : AppColors.label)
                        : Colors.transparent,
                  ),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

// ── Glassy day sheet — reminders for the tapped day ───────────────────────────

class _DaySheet extends StatefulWidget {
  final DateTime day;
  final VoidCallback onChanged;
  const _DaySheet({required this.day, required this.onChanged});
  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  static const _mn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static const _wd = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final t = await SupabaseService.getTasksForDate(widget.day);
    if (mounted) setState(() { _tasks = t; _loading = false; });
  }

  Future<void> _openTask(Map<String, dynamic> task) async {
    final r = await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => TaskDetailScreen(taskId: task['id']),
    ));
    if (r != null) { widget.onChanged(); await _load(); }
  }

  Future<void> _addTask() async {
    final r = await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => AddTaskScreen(initialDate: widget.day),
    ));
    if (r == true) { widget.onChanged(); await _load(); }
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    final title = '${_wd[d.weekday - 1]}, ${_mn[d.month - 1]} ${d.day}';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glass,
            border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.8)),
          ),
          child: PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {},
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  minHeight: 240,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.separator,
                      borderRadius: BorderRadius.circular(3),
                    )),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(children: [
                      Expanded(child: Text(title,
                        style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800,
                          color: AppColors.label, letterSpacing: -0.8,
                        ))),
                      GestureDetector(
                        onTap: _addTask,
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.label, shape: BoxShape.circle),
                          child: Icon(Icons.add_rounded, color: AppColors.bg, size: 24),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: _loading
                        ? Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.label)),
                          )
                        : _tasks.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                                child: Text('No reminders this day.',
                                  style: TextStyle(fontSize: 16, color: AppColors.label3)),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                itemCount: _tasks.length,
                                separatorBuilder: (_, _) =>
                                    Container(height: 0.5, color: AppColors.separator),
                                itemBuilder: (ctx, i) {
                                  final t = _tasks[i];
                                  final status = t['status'] as String? ?? 'pending';
                                  final isDone = status == 'verified';
                                  final isFailed = status == 'failed';
                                  final time = t['scheduled_time'] != null
                                      ? _fmtTime(DateTime.parse(t['scheduled_time']))
                                      : 'Anytime';
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openTask(t),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Row(children: [
                                        Container(
                                          width: 30, height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDone ? AppColors.label : Colors.transparent,
                                            border: isDone ? null
                                                : Border.all(color: AppColors.separator, width: 1.5),
                                          ),
                                          child: Icon(
                                            isDone ? Icons.check_rounded
                                                : isFailed ? Icons.close_rounded : null,
                                            size: 17,
                                            color: isDone ? AppColors.bg : AppColors.label3,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t['title'] ?? '',
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 18, fontWeight: FontWeight.w600,
                                                color: isDone ? AppColors.label3 : AppColors.label,
                                                decoration: isDone ? TextDecoration.lineThrough : null,
                                                decorationColor: AppColors.label3,
                                                letterSpacing: -0.3,
                                              )),
                                            const SizedBox(height: 3),
                                            Text(time,
                                              style: TextStyle(fontSize: 14, color: AppColors.label3)),
                                          ],
                                        )),
                                        Icon(Icons.chevron_right_rounded,
                                            color: AppColors.label3, size: 22),
                                      ]),
                                    ),
                                  );
                                },
                              ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

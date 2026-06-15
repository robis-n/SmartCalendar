import 'dart:math' show max;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_utils.dart';
import '../../../services/device_calendar_service.dart';
import '../../../services/supabase_service.dart';
import '../../tasks/screens/add_task_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';
import 'calendar_event_screen.dart';

// ── View mode ─────────────────────────────────────────────────────────────────

enum _ViewMode { year, month, week }

// ── Root screen ───────────────────────────────────────────────────────────────

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _monthCtrl = ScrollController();
  final _centerKey = const ValueKey<String>('center-month');
  late final DateTime _base;
  DateTime _selected = DateTime.now();
  int _reloadToken = 0;
  _ViewMode _view = _ViewMode.month;

  // Week view — PageView anchored at page 1000 = current week
  late final PageController _weekCtrl;
  static const int _weekAnchorPage = 1000;
  late DateTime _weekAnchor; // Monday of the current week

  static const int _span = 120;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _base = DateTime(n.year, n.month);
    _weekAnchor = _mondayOf(n);
    _weekCtrl = PageController(initialPage: _weekAnchorPage);
  }

  @override
  void dispose() {
    _monthCtrl.dispose();
    _weekCtrl.dispose();
    super.dispose();
  }

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  DateTime _monthAt(int offset) =>
      DateTime(_base.year, _base.month + offset);

  DateTime _weekStartAt(int page) =>
      _weekAnchor.add(Duration(days: (page - _weekAnchorPage) * 7));

  void _jumpToToday() {
    setState(() {
      _selected = DateTime.now();
      _weekAnchor = _mondayOf(DateTime.now());
    });
    if (_view == _ViewMode.month) {
      _monthCtrl.animateTo(0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic);
    } else if (_view == _ViewMode.week) {
      _weekCtrl.animateToPage(_weekAnchorPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _openDay(DateTime day) async {
    setState(() => _selected = day);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      barrierColor: AppColors.bg.withValues(alpha: 0.04),
      builder: (_) => _DaySheet(
        day: day,
        onChanged: () {
          if (mounted) setState(() => _reloadToken++);
        },
      ),
    );
  }

  // ── Pinch-zoom (Apple-Calendar feel) ───────────────────────────────────────
  // Live finger tracking drives a damped scale on the whole grid; on release
  // we either commit to the next/prev zoom level (which the AnimatedSwitcher
  // crossfades with a scale) or spring back to 1.0. No abrupt jumps mid-pinch.
  double _pinch = 1.0;
  bool _pinching = false;

  // Zoom granularity: year ⇄ month ⇄ week.
  _ViewMode get _zoomedIn => switch (_view) {
        _ViewMode.year  => _ViewMode.month,
        _ViewMode.month => _ViewMode.week,
        _ViewMode.week  => _ViewMode.week,
      };
  _ViewMode get _zoomedOut => switch (_view) {
        _ViewMode.week  => _ViewMode.month,
        _ViewMode.month => _ViewMode.year,
        _ViewMode.year  => _ViewMode.year,
      };

  // Damped, rubber-banded scale shown while the fingers are down.
  double get _visualScale {
    if (!_pinching) return 1.0;
    final damped = 1 + (_pinch - 1) * 0.45;
    return damped.clamp(0.80, 1.20);
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (d.pointerCount < 2) return;
    setState(() {
      _pinching = true;
      _pinch = 1.0;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    setState(() => _pinch = d.scale);
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!_pinching) return;
    final s = _pinch;
    if (s < 0.80) {
      _switchView(_zoomedOut);
    } else if (s > 1.22) {
      _switchView(_zoomedIn);
    }
    setState(() { _pinching = false; _pinch = 1.0; });
  }

  // Switch view mode and — when entering week view — jump to the page that
  // contains the currently selected/tapped day, not always the current week.
  void _switchView(_ViewMode next) {
    if (next == _ViewMode.week && _view != _ViewMode.week) {
      final targetMonday = _mondayOf(_selected);
      final diff = targetMonday.difference(_weekAnchor).inDays ~/ 7;
      final targetPage = _weekAnchorPage + diff;
      // Jump immediately (no animation flicker) then rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_weekCtrl.hasClients) _weekCtrl.jumpToPage(targetPage);
      });
    }
    setState(() => _view = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Stack(children: [
        Column(children: [
          // ── Top bar ────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
              child: Row(children: [
                Text('Calendar',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.label,
                        letterSpacing: -1.2)),
                const Spacer(),
                GestureDetector(
                  onTap: _jumpToToday,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: AppColors.separator, width: 0.8),
                    ),
                    child: Text('Today',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.label)),
                  ),
                ),
              ]),
            ),
          ),

          // ── Weekday header (month + week views) ────────────
          if (_view != _ViewMode.year) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Expanded(
                          child: Text(d,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.label3,
                                  letterSpacing: 0.5)),
                        ))
                    .toList(),
              ),
            ),
            Container(height: 0.5, color: AppColors.separator),
          ],

          // ── View body ──────────────────────────────────────
          Expanded(
            child: AnimatedScale(
              // Tracks the fingers instantly while pinching, then springs
              // back to rest — this is what makes the zoom feel continuous.
              scale: _visualScale,
              duration: _pinching
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_view),
                  child: switch (_view) {
                    _ViewMode.year => _YearView(
                      onMonthTap: (_) => _switchView(_ViewMode.month),
                    ),
                    _ViewMode.month => _buildMonthView(),
                    _ViewMode.week  => _buildWeekView(),
                  },
                ),
              ),
            ),
          ),
        ]),
        // ── Right-edge zoom rail (Year / Month / Week) ──
        Positioned(
          right: 6, top: 0, bottom: 0,
          child: Center(child: _ZoomRail(
            view: _view,
            onPick: _switchView,
          )),
        ),
        ]),
      ),
    );
  }

  Widget _buildMonthView() => CustomScrollView(
        controller: _monthCtrl,
        center: _centerKey,
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _MonthGrid(
                month: _monthAt(-(i + 1)),
                selected: _selected,
                reloadToken: _reloadToken,
                onTapDay: _openDay,
              ),
              childCount: _span,
            ),
          ),
          SliverToBoxAdapter(
            key: _centerKey,
            child: _MonthGrid(
              month: _monthAt(0),
              selected: _selected,
              reloadToken: _reloadToken,
              onTapDay: _openDay,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _MonthGrid(
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
      );

  Widget _buildWeekView() => PageView.builder(
        controller: _weekCtrl,
        itemBuilder: (_, page) => _WeekTimeline(
          key: ValueKey(_weekStartAt(page)),
          weekStart: _weekStartAt(page),
          selected: _selected,
          reloadToken: _reloadToken,
          onTapDay: _openDay,
        ),
      );
}

// ── Right-edge zoom rail ──────────────────────────────────────────────────────
// A vertical glass pill: Year / Month / Week, with a sliding ink indicator.
// Tapping a level switches the view; mirrors the pinch zoom granularity.
class _ZoomRail extends StatelessWidget {
  final _ViewMode view;
  final ValueChanged<_ViewMode> onPick;
  const _ZoomRail({required this.view, required this.onPick});

  static const _items = [
    (_ViewMode.year, 'Y'),
    (_ViewMode.month, 'M'),
    (_ViewMode.week, 'W'),
  ];

  @override
  Widget build(BuildContext context) {
    const seg = 40.0;
    final activeIndex = _items.indexWhere((e) => e.$1 == view);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: AppColors.glassBlur, sigmaY: AppColors.glassBlur),
        child: Container(
          width: 38,
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
            boxShadow: cardShadow,
          ),
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              top: activeIndex * seg + 4,
              left: 4, right: 4, height: seg - 8,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.label,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (mode, letter) in _items)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPick(mode);
                  },
                  child: SizedBox(
                    width: 38, height: seg,
                    child: Center(
                      child: Text(letter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: mode == view
                                ? AppColors.bg
                                : AppColors.label3,
                          )),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Year view — 3 × 4 mini months ─────────────────────────────────────────────

class _YearView extends StatelessWidget {
  final void Function(DateTime) onMonthTap;
  const _YearView({required this.onMonthTap});

  static const _mNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 18,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final month = DateTime(year, i + 1);
        return GestureDetector(
          onTap: () => onMonthTap(month),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_mNames[i],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label,
                      letterSpacing: -0.2)),
              const SizedBox(height: 5),
              Expanded(child: _MiniMonthGrid(month: month)),
            ],
          ),
        );
      },
    );
  }
}

class _MiniMonthGrid extends StatelessWidget {
  final DateTime month;
  const _MiniMonthGrid({required this.month});

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadBlanks  = DateTime(month.year, month.month, 1).weekday - 1;
    final now = DateTime.now();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, childAspectRatio: 1.1),
      itemCount: leadBlanks + daysInMonth,
      itemBuilder: (_, i) {
        if (i < leadBlanks) return const SizedBox();
        final day = i - leadBlanks + 1;
        final isToday = now.year == month.year &&
            now.month == month.month &&
            now.day == day;
        return Container(
          margin: const EdgeInsets.all(0.8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday ? AppColors.label : Colors.transparent,
          ),
          child: Center(
            child: Text('$day',
                style: TextStyle(
                    fontSize: 6.5,
                    color: isToday ? AppColors.bg : AppColors.label3,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400)),
          ),
        );
      },
    );
  }
}

// ── Month grid with event chips ────────────────────────────────────────────────

class _CalChip {
  final String title;
  final bool isTask;
  final String status;
  final int? color; // ambient calendar color (device events only)
  const _CalChip(
      {required this.title, required this.isTask, this.status = 'pending',
       this.color});
}

class _MonthGrid extends StatefulWidget {
  final DateTime month;
  final DateTime selected;
  final int reloadToken;
  final ValueChanged<DateTime> onTapDay;
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.reloadToken,
    required this.onTapDay,
  });
  @override
  State<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<_MonthGrid> {
  Map<int, List<_CalChip>> _chips = {};

  static const _mNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MonthGrid old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _load();
  }

  Future<void> _load() async {
    final tasks = await SupabaseService.getTasksForMonth(
        widget.month.year, widget.month.month);

    final result = <int, List<_CalChip>>{};
    for (final t in tasks) {
      if (t['scheduled_time'] == null) continue;
      final day = tsFromDb(t['scheduled_time'] as String).day;
      result.putIfAbsent(day, () => []).add(_CalChip(
        title: t['title'] as String? ?? '',
        isTask: true,
        status: t['status'] as String? ?? 'pending',
      ));
    }

    // Device events (local read — only if user has them enabled)
    if (DeviceCalendarService.enabled) {
      try {
        final devEvents =
            await DeviceCalendarService.eventsForMonth(widget.month);
        for (final e in devEvents) {
          if (e.start == null) continue;
          if (e.title.trim().isEmpty) continue; // never render blank boxes
          result.putIfAbsent(e.start!.day, () => []).add(
              _CalChip(title: e.title, isTask: false, color: e.color));
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _chips = result);
  }

  int get _daysInMonth =>
      DateTime(widget.month.year, widget.month.month + 1, 0).day;
  int get _leadBlanks =>
      DateTime(widget.month.year, widget.month.month, 1).weekday - 1;

  bool _isToday(int d) {
    final n = DateTime.now();
    return n.year == widget.month.year &&
        n.month == widget.month.month &&
        n.day == d;
  }

  bool _isSel(int d) =>
      widget.selected.year == widget.month.year &&
      widget.selected.month == widget.month.month &&
      widget.selected.day == d;

  @override
  Widget build(BuildContext context) {
    final rows = ((_leadBlanks + _daysInMonth) / 7).ceil();
    final isCurYear = widget.month.year == DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 12),
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: _mNames[widget.month.month - 1],
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.label,
                      letterSpacing: -0.8)),
              TextSpan(
                  text: '  ${widget.month.year}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      color: isCurYear ? AppColors.label3 : AppColors.label2,
                      letterSpacing: -0.8)),
            ]),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.50, // tall enough for 2 chips
          ),
          itemCount: rows * 7,
          itemBuilder: (_, i) {
            if (i < _leadBlanks) return const SizedBox();
            final day = i - _leadBlanks + 1;
            if (day > _daysInMonth) return const SizedBox();

            final today = _isToday(day);
            final sel   = _isSel(day);
            final all = (_chips[day] ?? [])
                .where((c) => c.isTask || DeviceCalendarService.enabled)
                .toList();
            // The app's whole point: combine reminders + events but keep them
            // distinct. Reminders sit ABOVE the number (ink dots); events sit
            // BELOW (coloured dot+label). Never mixed.
            final reminders = all.where((c) => c.isTask).toList();
            final events    = all.where((c) => !c.isTask).toList();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTapDay(
                  DateTime(widget.month.year, widget.month.month, day)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 3),
                    // ── Reminders — dots above the number ──
                    SizedBox(
                      height: 7,
                      child: reminders.isEmpty
                          ? null
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var r = 0; r < reminders.length && r < 4; r++)
                                  Container(
                                    width: 5, height: 5,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: reminders[r].status == 'verified'
                                          ? AppColors.accent.withValues(alpha: 0.30)
                                          : AppColors.accent,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 2),
                    // ── Day number ──
                    Align(
                      child: Container(
                        width: 34, height: 34,
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
                                fontSize: 16,
                                fontWeight: (today || sel)
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: today ? AppColors.bg : AppColors.label)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // ── Events — dot+label below ──
                    for (var e = 0; e < events.length && e < 2; e++)
                      _Chip(chip: events[e], onToday: today),
                    if (events.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 1, left: 2),
                        child: Text('+${events.length - 2}',
                            style: TextStyle(
                                fontSize: 8.5,
                                color: AppColors.label3,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final _CalChip chip;
  final bool onToday;
  const _Chip({required this.chip, required this.onToday});

  @override
  Widget build(BuildContext context) {
    final isDone = chip.status == 'verified';
    final base   = onToday ? AppColors.bg : AppColors.label;
    // Clean "dot + label" instead of a filled box — no more gray rectangles.
    // Reminders use ink; device events use their calendar's ambient colour.
    final dotColor = (!chip.isTask && chip.color != null)
        ? Color(chip.color!)
        : base.withValues(alpha: chip.isTask ? 0.9 : 0.55);

    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 2, right: 1),
      child: Row(mainAxisSize: MainAxisSize.max, children: [
        Container(
          width: 5, height: 5,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        Expanded(
          child: Text(
            chip.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: base.withValues(alpha: isDone ? 0.4 : 0.85),
              decoration: isDone ? TextDecoration.lineThrough : null,
              decorationColor: base.withValues(alpha: 0.4),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Week timeline view ─────────────────────────────────────────────────────────

class _WeekEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool isTask;
  final bool allDay;
  final String status;
  final int? color; // device-calendar ambient color
  const _WeekEvent({
    this.id = '',
    required this.title,
    required this.start,
    required this.end,
    required this.isTask,
    this.allDay = false,
    this.status = 'pending',
    this.color,
  });
}

class _WeekTimeline extends StatefulWidget {
  final DateTime weekStart;
  final DateTime selected;
  final int reloadToken;
  final ValueChanged<DateTime> onTapDay;
  const _WeekTimeline({
    super.key,
    required this.weekStart,
    required this.selected,
    required this.reloadToken,
    required this.onTapDay,
  });
  @override
  State<_WeekTimeline> createState() => _WeekTimelineState();
}

class _WeekTimelineState extends State<_WeekTimeline> {
  List<List<_WeekEvent>> _events = List.generate(7, (_) => []);
  final _scrollCtrl = ScrollController();
  int _lastHapticHour = -1;

  // 7 AM – 10 PM at 44 px/h = 660 px total — fits most screens without
  // needing to scroll to see the evening (previously 56 px/h was 952 px).
  static const double _hourH  = 44.0;
  static const int    _startH = 7;
  static const int    _endH   = 22;
  static const double _labelW = 46.0;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo((8 - _startH) * _hourH);
      }
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final hourIdx = (_scrollCtrl.offset / _hourH).floor();
    if (hourIdx != _lastHapticHour) {
      _lastHapticHour = hourIdx;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WeekTimeline old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken ||
        old.weekStart != widget.weekStart) {
      _load();
    }
  }

  Future<void> _load() async {
    final taskFutures = List.generate(
      7,
      (i) => SupabaseService.getTasksForDate(
          widget.weekStart.add(Duration(days: i))),
    );
    final allTasks = await Future.wait(taskFutures);

    final ev = List.generate(7, (_) => <_WeekEvent>[]);

    for (var day = 0; day < 7; day++) {
      for (final t in allTasks[day]) {
        if (t['scheduled_time'] == null) continue;
        final start = tsFromDb(t['scheduled_time'] as String);
        ev[day].add(_WeekEvent(
          id: t['id'] as String? ?? '',
          title: t['title'] as String? ?? '',
          start: start,
          end: start.add(const Duration(hours: 1)),
          isTask: true,
          status: t['status'] as String? ?? 'pending',
        ));
      }
    }

    if (DeviceCalendarService.enabled) {
      for (var day = 0; day < 7; day++) {
        try {
          final d = widget.weekStart.add(Duration(days: day));
          final devEvs = await DeviceCalendarService.eventsForDay(d);
          for (final e in devEvs) {
            if (e.title.trim().isEmpty) continue;
            ev[day].add(_WeekEvent(
              title: e.title,
              start: e.start ?? widget.weekStart.add(Duration(days: day)),
              end:   e.end   ??
                  (e.start ?? widget.weekStart.add(Duration(days: day)))
                      .add(const Duration(hours: 1)),
              isTask: false,
              allDay: e.allDay,
              color: e.color,
            ));
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() => _events = ev);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double? get _nowLineY {
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      if (_sameDay(widget.weekStart.add(Duration(days: i)), now)) {
        final mins = (now.hour - _startH) * 60.0 + now.minute;
        if (mins < 0 || mins > (_endH - _startH) * 60) return null;
        return mins / 60 * _hourH;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final w   = MediaQuery.of(context).size.width;
    final dayW = (w - _labelW) / 7;
    final totalH = (_endH - _startH) * _hourH + 24;

    return Column(children: [
      // ── Day column headers ─────────────────────────────
      Container(
        height: 54,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
        ),
        child: Row(children: [
          SizedBox(width: _labelW),
          ...List.generate(7, (day) {
            final date    = widget.weekStart.add(Duration(days: day));
            final isToday = _sameDay(date, DateTime.now());
            final isSel   = _sameDay(date, widget.selected);
            return GestureDetector(
              onTap: () => widget.onTapDay(date),
              child: SizedBox(
                width: dayW,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day],
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label3)),
                  const SizedBox(height: 3),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? AppColors.accent : Colors.transparent,
                      border: (isSel && !isToday)
                          ? Border.all(color: AppColors.accent, width: 1.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text('${date.day}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: (isToday || isSel)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color:
                                isToday ? AppColors.bg : AppColors.label)),
                  ),
                ]),
              ),
            );
          }),
        ]),
      ),

      // ── All-day events strip ───────────────────────────
      if (_events.any((day) => day.any((e) => e.allDay)))
        Container(
          height: 28,
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
          ),
          child: Row(children: [
            SizedBox(
              width: _labelW,
              child: Center(
                child: Text('all-day',
                    style: TextStyle(fontSize: 8, color: AppColors.label3)),
              ),
            ),
            ...List.generate(7, (day) {
              final allDayEvs = _events[day].where((e) => e.allDay).toList();
              return SizedBox(
                width: dayW,
                child: allDayEvs.isEmpty
                    ? const SizedBox()
                    : Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 1.5, vertical: 3),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color:
                              AppColors.label.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(allDayEvs.first.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.label2,
                                fontWeight: FontWeight.w600)),
                      ),
              );
            }),
          ]),
        ),

      // ── Timed events timeline ──────────────────────────
      // Always render the hour grid immediately (no full-screen spinner);
      // event blocks simply appear once the fetch returns — feels instant.
      Expanded(
        child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: SizedBox(
                  height: totalH,
                  child: Stack(children: [
                    // Hour gridlines — the hairline sits EXACTLY at the hour's
                    // y so event blocks (anchored to the same y) line up. The
                    // label is centred on the line, not pushing it down.
                    ...List.generate(_endH - _startH + 1, (i) {
                      final y = i * _hourH + 12;
                      return Positioned(
                        top: y, left: _labelW, right: 0, height: 0.5,
                        child: Container(color: AppColors.separator),
                      );
                    }),
                    ...List.generate(_endH - _startH + 1, (i) {
                      final hour = _startH + i;
                      final y    = i * _hourH + 12;
                      return Positioned(
                        top: y - 6, left: 0, width: _labelW - 6,
                        child: Text(
                          hour == 12
                              ? '12 PM'
                              : hour < 12 ? '$hour AM' : '${hour - 12} PM',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.label3,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }),

                    // Vertical day separators
                    ...List.generate(6, (i) => Positioned(
                      top: 0, bottom: 0,
                      left: _labelW + (i + 1) * dayW,
                      width: 0.5,
                      child: Container(color: AppColors.separator),
                    )),

                    // Current-time line — hairline exactly on the minute, dot
                    // centred on it.
                    if (_nowLineY != null) ...[
                      Positioned(
                        top: _nowLineY! + 12 - 0.75,
                        left: _labelW, right: 0, height: 1.5,
                        child: Container(
                            color: Colors.red.withValues(alpha: 0.8)),
                      ),
                      Positioned(
                        top: _nowLineY! + 12 - 3.5,
                        left: _labelW - 3.5,
                        child: Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.red)),
                      ),
                    ],

                    // Event blocks
                    for (var day = 0; day < 7; day++)
                      for (final event in _events[day])
                        if (!event.allDay)
                          _eventBlock(event, day, dayW),
                  ]),
                ),
              ),
      ),
    ]);
  }

  Widget _eventBlock(_WeekEvent event, int day, double dayW) {
    final startFrac = event.start.hour + event.start.minute / 60.0;
    final top    = (startFrac - _startH).clamp(0.0, _endH - _startH.toDouble()) * _hourH + 12;
    final left   = _labelW + day * dayW + 1.5;
    final isDone = event.status == 'verified';
    final ambient = (!event.isTask && event.color != null)
        ? Color(event.color!)
        : null;
    final accent = ambient ??
        AppColors.label.withValues(alpha: event.isTask ? 0.8 : 0.55);
    void onTap() => widget.onTapDay(widget.weekStart.add(Duration(days: day)));

    // Reminders are point-in-time: render a compact marker (dot + label), not
    // a fabricated 1-hour block. Events (with a real end) render as a span.
    if (event.isTask) {
      return Positioned(
        top: top, left: left, width: dayW - 3, height: 20,
        child: GestureDetector(
          onTap: onTap,
          child: Row(children: [
            Container(
              width: 6, height: 6,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.label.withValues(alpha: isDone ? 0.35 : 0.9),
              ),
            ),
            Expanded(
              child: Text(event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label.withValues(alpha: isDone ? 0.4 : 0.9),
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.label3,
                  )),
            ),
          ]),
        ),
      );
    }

    final endFrac = event.end.hour + event.end.minute / 60.0;
    final height  = max(22.0, (endFrac - startFrac).clamp(0.0, 12.0) * _hourH);
    return Positioned(
      top: top, left: left, width: dayW - 3, height: height,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 3, 2),
          decoration: BoxDecoration(
            color: (ambient ?? AppColors.label).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: accent, width: 2.5)),
          ),
          child: Text(
            event.title,
            maxLines: height > 40 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.label2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Day sheet (DraggableScrollableSheet with timeline) ────────────────────────

class _DaySheet extends StatefulWidget {
  final DateTime day;
  final VoidCallback onChanged;
  const _DaySheet({required this.day, required this.onChanged});
  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  List<Map<String, dynamic>> _tasks  = [];
  List<DeviceEvent>          _devEvs = [];
  bool _loading = true;

  static const _mAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _wdFull = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await SupabaseService.getTasksForDate(widget.day);
    final devEvs = await DeviceCalendarService.eventsForDay(widget.day);
    if (mounted) setState(() { _tasks = tasks; _devEvs = devEvs; _loading = false; });
  }

  Future<void> _openTask(Map<String, dynamic> task) async {
    final r = await Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task['id'] as String)));
    if (r != null) { widget.onChanged(); await _load(); }
  }

  Future<void> _addTask() async {
    final r = await Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(
            builder: (_) => AddTaskScreen(initialDate: widget.day)));
    if (r == true) { widget.onChanged(); await _load(); }
  }

  Future<void> _addCalendarEvent() async {
    // Full-screen editor (reliable back button + correct insets + clear
    // Apple/Google target selection). Returns created {cal,ev} links.
    final created = await Navigator.of(context, rootNavigator: true)
        .push<List<dynamic>>(MaterialPageRoute(
            builder: (_) => CalendarEventScreen(day: widget.day)));
    if (!mounted) return;
    if (created != null && created.isNotEmpty) {
      widget.onChanged();
      await _load();
    }
  }

  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final d     = widget.day;
    final title = '${_wdFull[d.weekday - 1]}, ${_mAbbr[d.month - 1]} ${d.day}';
    final mq    = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.52, 0.75, 0.92],
      builder: (ctx, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppColors.glassBlur, sigmaY: AppColors.glassBlur),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glass,
              border: Border(
                  top: BorderSide(color: AppColors.glassBorder, width: 0.8)),
            ),
            child: Column(children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                      color: AppColors.separator,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 16),
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.label,
                            letterSpacing: -0.7)),
                  ),
                  // Add calendar event
                  GestureDetector(
                    onTap: _addCalendarEvent,
                    child: Container(
                      width: 38, height: 38,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                          color: AppColors.bg2, shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.separator, width: 0.8)),
                      child: Icon(Icons.calendar_month_outlined,
                          color: AppColors.label2, size: 18),
                    ),
                  ),
                  // Add task
                  GestureDetector(
                    onTap: _addTask,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: AppColors.label, shape: BoxShape.circle),
                      child: Icon(Icons.add_rounded,
                          color: AppColors.bg, size: 22),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.label))
                    : (_tasks.isEmpty && _devEvs.isEmpty)
                        ? ListView(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                            children: [
                              Text('Nothing scheduled this day.',
                                  style: TextStyle(
                                      fontSize: 16, color: AppColors.label3)),
                              const SizedBox(height: 8),
                              Text('Tap + to add a reminder.',
                                  style: TextStyle(
                                      fontSize: 14, color: AppColors.label3)),
                            ],
                          )
                        : ListView(
                            controller: scrollCtrl,
                            padding: EdgeInsets.fromLTRB(
                                24, 4, 24, mq.padding.bottom + 20),
                            children: [
                              // Tasks
                              if (_tasks.isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6, top: 4),
                                  child: Text('REMINDERS',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.label3,
                                          letterSpacing: 1.5)),
                                ),
                                for (var i = 0; i < _tasks.length; i++) ...[
                                  if (i > 0)
                                    Container(
                                        height: 0.5,
                                        color: AppColors.separator),
                                  _TaskRow(
                                      task: _tasks[i],
                                      onTap: () => _openTask(_tasks[i]),
                                      fmtTime: _fmt),
                                ],
                              ],
                              // Device events
                              if (_devEvs.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: _tasks.isEmpty ? 4 : 20,
                                      bottom: 6),
                                  child: Text('FROM YOUR CALENDARS',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.label3,
                                          letterSpacing: 1.5)),
                                ),
                                for (var i = 0; i < _devEvs.length; i++) ...[
                                  if (i > 0)
                                    Container(
                                        height: 0.5,
                                        color: AppColors.separator),
                                  _DevEventRow(
                                      event: _devEvs[i], fmtTime: _fmt),
                                ],
                              ],
                            ],
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Task row in day sheet ─────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  final String Function(DateTime) fmtTime;
  const _TaskRow(
      {required this.task, required this.onTap, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    final status  = task['status'] as String? ?? 'pending';
    final isDone  = status == 'verified';
    final isFail  = status == 'failed';
    final time    = task['scheduled_time'] != null
        ? fmtTime(tsFromDb(task['scheduled_time'] as String))
        : 'Anytime';
    final priority = task['priority'] as String? ?? 'medium';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          // Status circle
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppColors.label : Colors.transparent,
              border: isDone
                  ? null
                  : Border.all(color: AppColors.separator, width: 1.5),
            ),
            child: Icon(
              isDone ? Icons.check_rounded : isFail ? Icons.close_rounded : null,
              size: 17,
              color: isDone ? AppColors.bg : AppColors.label3,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task['title'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isDone ? AppColors.label3 : AppColors.label,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.label3,
                      letterSpacing: -0.3)),
              const SizedBox(height: 3),
              Row(children: [
                Text(time,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.label3)),
                const SizedBox(width: 8),
                // Nudge intensity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.label.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    switch (priority) {
                      'low'  => 'Gentle',
                      'high' => 'Persistent',
                      _      => 'Normal',
                    },
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label3),
                  ),
                ),
              ]),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.label3, size: 20),
        ]),
      ),
    );
  }
}

// ── Device event row in day sheet ─────────────────────────────────────────────

class _DevEventRow extends StatelessWidget {
  final DeviceEvent event;
  final String Function(DateTime) fmtTime;
  const _DevEventRow({required this.event, required this.fmtTime});

  @override
  Widget build(BuildContext context) {
    final when = event.allDay
        ? 'All day'
        : [
            if (event.start != null) fmtTime(event.start!),
            if (event.end != null) fmtTime(event.end!),
          ].join(' – ');

    final ambient = event.color != null ? Color(event.color!) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (ambient ?? AppColors.label).withValues(alpha: 0.12),
          ),
          child: Icon(Icons.circle,
              size: 12, color: ambient ?? AppColors.label2),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.label2,
                    letterSpacing: -0.2)),
            const SizedBox(height: 3),
            Text(
              event.calendarName.isEmpty
                  ? when
                  : '$when · ${event.calendarName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.label3),
            ),
          ]),
        ),
      ]),
    );
  }
}

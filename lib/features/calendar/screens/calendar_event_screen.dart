import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_utils.dart';
import '../../../services/device_calendar_service.dart';

/// Full-screen "Add to calendar" / new Event editor.
///
/// Replaces the old nested bottom-sheet (which had broken margins, jumped
/// while scrolling, and could trap you with no way back). A real route with
/// an app bar gives a reliable back button and correct insets, and you can
/// clearly pick Apple / Google / both as the destination.
///
/// Pops with a `List<Map<String,String>>` of created `{cal, ev}` links
/// (empty list if nothing was created).
class CalendarEventScreen extends StatefulWidget {
  final DateTime day;
  final String? initialTitle;
  const CalendarEventScreen({super.key, required this.day, this.initialTitle});

  @override
  State<CalendarEventScreen> createState() => _CalendarEventScreenState();
}

class _CalendarEventScreenState extends State<CalendarEventScreen> {
  final _title = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  List<WritableCalendar> _cals = [];
  final Set<String> _targets = {}; // selected calendar ids
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle ?? '';
    final d = widget.day;
    _start = DateTime(d.year, d.month, d.day, 9);
    _end = DateTime(d.year, d.month, d.day, 10);
    _loadCalendars();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadCalendars() async {
    final cals = await DeviceCalendarService.writableCalendars();
    if (!mounted) return;
    setState(() {
      _cals = cals;
      // Pre-select the first calendar of each kind so "both" is one tap away,
      // and a single-account user is ready to save immediately.
      final seenKind = <String>{};
      for (final c in cals) {
        if (seenKind.add(c.kind)) _targets.add(c.id);
      }
      if (_targets.isEmpty && cals.isNotEmpty) _targets.add(cals.first.id);
      _loading = false;
    });
  }

  String _fmtTime(DateTime d) => TimeFmt.t(d);

  Future<void> _pickTime(bool isStart) async {
    DateTime temp = isStart ? _start : _end;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(children: [
              Text(isStart ? 'Start time' : 'End time',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label)),
              const Spacer(),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Done',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label))),
            ]),
          ),
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness:
                    AppColors.isDark ? Brightness.dark : Brightness.light,
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: temp,
                use24hFormat: TimeFmt.use24h,
                onDateTimeChanged: (dt) => temp = dt,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    final d = widget.day;
    setState(() {
      if (isStart) {
        _start = DateTime(d.year, d.month, d.day, temp.hour, temp.minute);
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = DateTime(d.year, d.month, d.day, temp.hour, temp.minute);
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _targets.isEmpty) return;
    setState(() => _saving = true);
    final created = <Map<String, String>>[];
    for (final id in _targets) {
      final ev = await DeviceCalendarService.createEvent(
        calendarId: id,
        title: _title.text.trim(),
        start: _start,
        end: _end,
      );
      if (ev != null) created.add({'cal': id, 'ev': ev});
    }
    if (!mounted) return;
    if (created.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save to calendar')));
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _title.text.trim().isNotEmpty && _targets.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.label),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add to calendar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.label)),
                  )
                : GestureDetector(
                    onTap: canSave ? _save : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: canSave
                            ? AppColors.label
                            : AppColors.label.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text('Save',
                          style: TextStyle(
                              color: AppColors.bg,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.label))
          : _cals.isEmpty
              ? _noCalendars()
              : ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  children: [
                    // Title
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.separator, width: 1),
                      ),
                      child: TextField(
                        controller: _title,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.label),
                        decoration: InputDecoration(
                          hintText: 'Event title',
                          hintStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppColors.label3),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _label('WHEN'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: _timeChip(
                              Icons.schedule_outlined, _fmtTime(_start),
                              () => _pickTime(true))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('–',
                            style: TextStyle(
                                color: AppColors.label3, fontSize: 16)),
                      ),
                      Expanded(
                          child: _timeChip(
                              Icons.schedule_outlined, _fmtTime(_end),
                              () => _pickTime(false))),
                    ]),
                    const SizedBox(height: 20),

                    _label('SAVE TO'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.separator, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < _cals.length; i++) ...[
                            if (i > 0)
                              Container(
                                  height: 0.5,
                                  margin: const EdgeInsets.only(left: 46),
                                  color: AppColors.separator),
                            _calRow(_cals[i]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pick one or more calendars — choose both an Apple and a '
                      'Google calendar to add the event to each.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.label3, height: 1.4),
                    ),
                  ],
                ),
    );
  }

  Widget _calRow(WritableCalendar c) {
    final sel = _targets.contains(c.id);
    final dot = c.color != null ? Color(c.color!) : AppColors.label2;
    final kind = switch (c.kind) {
      'google' => 'Google Calendar',
      'apple' => 'Apple Calendar',
      _ => null,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (sel) {
          _targets.remove(c.id);
        } else {
          _targets.add(c.id);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(Icons.circle, size: 14, color: dot),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.label)),
              if (kind != null)
                Text(kind,
                    style: TextStyle(fontSize: 12, color: AppColors.label3)),
            ]),
          ),
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? AppColors.label : Colors.transparent,
              border: sel
                  ? null
                  : Border.all(color: AppColors.separator, width: 1.5),
            ),
            child: sel
                ? Icon(Icons.check_rounded, size: 16, color: AppColors.bg)
                : null,
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.label3,
          letterSpacing: 1.5));

  Widget _timeChip(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.separator, width: 1),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: AppColors.label2),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label2)),
          ]),
        ),
      );

  Widget _noCalendars() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_outlined, size: 44, color: AppColors.label3),
            const SizedBox(height: 14),
            Text('No writable calendars',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label)),
            const SizedBox(height: 8),
            Text(
              'Enable Apple Calendar or a Google account on this phone, then '
              'turn on “Show phone calendars” in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.label3, height: 1.5),
            ),
          ]),
        ),
      );
}

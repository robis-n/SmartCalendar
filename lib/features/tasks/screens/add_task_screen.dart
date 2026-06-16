import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/recurrence.dart';
import '../../../core/utils/time_utils.dart';
import '../../../services/device_calendar_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/widgets/repeat_picker.dart';

/// How the reminder is anchored in time.
///   scheduled — a specific date AND time (fires a timed reminder)
///   today     — a specific day, no clock time ("do it that day"); day editable
///   global    — no date at all; lives in the Anytime list
enum _TaskKind { scheduled, today, global }

class AddTaskScreen extends StatefulWidget {
  final DateTime? initialDate;
  /// When set, this screen edits the given task in place (prefilled, "Save"
  /// updates instead of creating) instead of making a new one. The full-task
  /// map as returned by the task-detail/list queries.
  final Map<String, dynamic>? existingTask;
  const AddTaskScreen({super.key, this.initialDate, this.existingTask});
  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  late DateTime _deadline;
  _TaskKind _kind = _TaskKind.scheduled;
  String _priority    = 'medium';
  bool   _saving      = false;
  bool   _requireProof = true; // photo proof to complete (off = simple tick)
  bool   _syncCal     = false;
  String? _syncCalId;
  Map<String, dynamic>? _recurrence; // null = never repeats
  List<WritableCalendar> _writableCals = [];

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _groups  = []; // named friend groups (e.g. Family)
  final Set<String> _collab = {};

  bool get _editing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTask;
    if (existing != null) {
      // Prefill every field from the task being edited.
      _title.text = existing['title'] as String? ?? '';
      _desc.text  = existing['description'] as String? ?? '';
      final sched = tsTryFromDb(existing['scheduled_time'] as String?);
      if (sched == null) {
        _kind = _TaskKind.global;
        _deadline = DateTime.now().add(const Duration(hours: 1));
      } else if (existing['all_day'] == true) {
        _kind = _TaskKind.today;
        _deadline = sched;
      } else {
        _kind = _TaskKind.scheduled;
        _deadline = sched;
      }
      _priority = existing['priority'] as String? ?? 'medium';
      _requireProof = existing['verification_required'] != false;
      final rec = existing['recurrence'];
      _recurrence = rec is Map ? rec.cast<String, dynamic>() : null;
    } else {
      final d = widget.initialDate;
      _deadline = d != null
          ? DateTime(d.year, d.month, d.day, 9, 0)
          : DateTime.now().add(const Duration(hours: 1));
      // Opened from a specific day → default to a day-anchored task on that day.
      if (d != null) _kind = _TaskKind.today;
      _loadFriends();
      _loadCalendars();
    }
  }

  Future<void> _loadFriends() async {
    final f = await SupabaseService.getAcceptedFriends();
    final g = await SupabaseService.getFriendGroups();
    if (mounted) setState(() { _friends = f; _groups = g; });
  }

  Future<void> _loadCalendars() async {
    final cals = await DeviceCalendarService.writableCalendars();
    if (mounted) {
      setState(() {
        _writableCals = cals;
        if (cals.isNotEmpty) { _syncCalId = cals.first.id; }
      });
    }
  }

  @override
  void dispose() { _title.dispose(); _desc.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (d != null && mounted) {
      setState(() => _deadline = DateTime(d.year, d.month, d.day, _deadline.hour, _deadline.minute));
    }
  }

  // Natural wheel time picker (Cupertino) — no clock dial.
  Future<void> _pickTime() async {
    DateTime temp = _deadline;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 5,
              decoration: BoxDecoration(color: AppColors.separator,
                  borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(children: [
              Text('Pick a time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.label)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.label)),
              ),
            ]),
          ),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.label),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _deadline,
                use24hFormat: TimeFmt.use24h,
                onDateTimeChanged: (dt) => temp = dt,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (mounted) {
      setState(() => _deadline =
          DateTime(_deadline.year, _deadline.month, _deadline.day, temp.hour, temp.minute));
    }
  }

  Future<void> _pickCollaborators() async {
    if (_friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add friends first (Profile → Friends) to collaborate')));
      return;
    }
    final temp = Set<String>.from(_collab);
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 5,
              decoration: BoxDecoration(color: AppColors.separator,
                  borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
            child: Row(children: [
              Text('Share with friends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.label)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.label)),
              ),
            ]),
          ),
          // ── Groups — tap to add/remove everyone in the group at once ──
          if (_groups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('GROUPS',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: AppColors.label3, letterSpacing: 1.5)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 8, runSpacing: 8, children: _groups.map((g) {
                final members =
                    List<String>.from((g['member_ids'] as List?) ?? const []);
                // "On" when every member is already selected.
                final allIn = members.isNotEmpty &&
                    members.every((m) => temp.contains(m));
                return GestureDetector(
                  onTap: () => ss(() {
                    if (allIn) {
                      temp.removeAll(members);
                    } else {
                      temp.addAll(members);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: allIn ? AppColors.label : AppColors.bg2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.separator, width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.group_rounded, size: 15,
                          color: allIn ? AppColors.bg : AppColors.label2),
                      const SizedBox(width: 7),
                      Text('${g['name']} · ${members.length}',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: allIn ? AppColors.bg : AppColors.label)),
                    ]),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(height: 8),
          ],
          ..._friends.map((f) {
            final id = f['id'] as String;
            final on = temp.contains(id);
            return ListTile(
              onTap: () => ss(() => on ? temp.remove(id) : temp.add(id)),
              leading: CircleAvatar(
                radius: 18, backgroundColor: AppColors.bg2,
                child: Text((f['email'] as String).characters.first.toUpperCase(),
                    style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w700)),
              ),
              title: Text((f['email'] as String).split('@').first,
                  style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w500)),
              trailing: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? AppColors.label : Colors.transparent,
                  border: on ? null : Border.all(color: AppColors.separator, width: 1.5),
                ),
                child: on ? Icon(Icons.check_rounded, size: 16, color: AppColors.bg) : null,
              ),
            );
          }),
          const SizedBox(height: 12),
        ]),
      )),
    );
    setState(() { _collab..clear()..addAll(temp); });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your task a title first')));
      return;
    }
    setState(() => _saving = true);
    try {
      final isGlobal = _kind == _TaskKind.global;
      final isToday  = _kind == _TaskKind.today;
      // scheduled → exact datetime; today → that day at 00:00 (all-day);
      // global → no time at all.
      final DateTime? sched = isGlobal
          ? null
          : (isToday
              ? DateTime(_deadline.year, _deadline.month, _deadline.day)
              : _deadline);
      final notifyAt = isToday
          ? DateTime(_deadline.year, _deadline.month, _deadline.day, 9, 0)
          : _deadline;

      final String taskId;
      if (_editing) {
        taskId = widget.existingTask!['id'] as String;
        await SupabaseService.updateTask(taskId, {
          'title':          _title.text.trim(),
          'description':    _desc.text.trim(),
          'scheduled_time': sched != null ? tsToDb(sched) : null,
          'all_day':        isToday,
          'priority':       _priority,
          'verification_required': _requireProof,
          'recurrence':     _recurrence,
        });
        // Reschedule notifications from scratch — old ones may no longer
        // match the (possibly changed) time/priority.
        await NotificationService().cancelTaskNotifications(taskId);
        if (!isGlobal) {
          await NotificationService().scheduleTaskNotifications(
              taskId: taskId, taskTitle: _title.text.trim(),
              deadline: notifyAt, priority: _priority);
        }
      } else {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        final created = await SupabaseService.createTask({
          'user_id':        uid,
          'title':          _title.text.trim(),
          'description':    _desc.text.trim(),
          if (sched != null) 'scheduled_time': tsToDb(sched),
          'all_day':        isToday,
          'status':         'pending',
          'ai_generated':   false,
          'priority':       _priority,
          'verification_required': _requireProof,
          if (_recurrence != null) 'recurrence': _recurrence,
        });
        taskId = created['id'] as String;
        if (_collab.isNotEmpty) {
          await SupabaseService.addCollaborators(taskId, _collab.toList());
        }
        if (!isGlobal) {
          await NotificationService().scheduleTaskNotifications(
              taskId: taskId, taskTitle: _title.text.trim(),
              deadline: notifyAt, priority: _priority);
        }
        // Mirror into Apple/Google Calendar (timed tasks only, new tasks only).
        if (_kind == _TaskKind.scheduled && _syncCal && _syncCalId != null) {
          await DeviceCalendarService.createEvent(
            calendarId: _syncCalId!,
            title: _title.text.trim(),
            start: _deadline,
            end: _deadline.add(const Duration(hours: 1)),
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _dateLabel {
    final now = _deadline, today = DateTime.now();
    if (now.year == today.year && now.month == today.month && now.day == today.day) return 'Today';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${now.day} ${m[now.month - 1]} ${now.year}';
  }

  String get _timeLabel => TimeFmt.t(_deadline);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.label2),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_editing ? 'Edit task' : 'New task'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.label)),
                  )
                : GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.label,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text('Save',
                          style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        // Drag the list down and the keyboard dismisses with it.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // Title + notes card
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.separator, width: 1),
              boxShadow: cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                    color: AppColors.label, letterSpacing: -0.4),
                decoration: InputDecoration(
                  hintText: 'What do you need to do?',
                  hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w500,
                      color: AppColors.label3, letterSpacing: -0.4),
                  filled: false,
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: AppColors.separator,
                  indent: 18, endIndent: 18),
              TextField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null, minLines: 2,
                style: TextStyle(fontSize: 16, color: AppColors.label2),
                decoration: InputDecoration(
                  hintText: 'Add notes…',
                  hintStyle: TextStyle(color: AppColors.label3, fontSize: 16),
                  filled: false,
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Schedule — how the task is anchored in time.
          _sectionLabel('SCHEDULE'),
          const SizedBox(height: 10),
          _kindSelector(),
          if (_kind == _TaskKind.scheduled) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _chipButton(
                icon: Icons.calendar_today_outlined,
                label: _dateLabel, onTap: _pickDate,
              )),
              const SizedBox(width: 10),
              Expanded(child: _chipButton(
                icon: Icons.access_time_outlined,
                label: _timeLabel, onTap: _pickTime,
              )),
            ]),
          ] else if (_kind == _TaskKind.today) ...[
            const SizedBox(height: 10),
            _chipButton(
              icon: Icons.calendar_today_outlined,
              label: _dateLabel, onTap: _pickDate,
            ),
          ],
          // Repeat (not for global/anytime tasks — nothing to advance).
          if (_kind != _TaskKind.global) ...[
            const SizedBox(height: 10),
            _chipButton(
              icon: Icons.repeat_rounded,
              label: Recurrence.label(_recurrence) ?? 'Does not repeat',
              onTap: () async {
                final r = await showRepeatPicker(context, _recurrence);
                if (r != null) {
                  setState(() => _recurrence =
                      (r['preset'] == 'none') ? null : r);
                }
              },
            ),
          ],
          const SizedBox(height: 24),

          // Reminders — priority IS nudge intensity, not abstract importance.
          _sectionLabel('REMINDERS'),
          const SizedBox(height: 10),
          Row(children: [
            for (final (p, label) in [('low', 'Gentle'), ('medium', 'Normal'), ('high', 'Persistent')]) ...[
              if (p != 'low') const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _priority == p ? AppColors.label : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _priority == p ? AppColors.label : AppColors.separator,
                        width: _priority == p ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(label,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: _priority == p ? AppColors.bg : AppColors.label3,
                        )),
                    ),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              switch (_priority) {
                'low'  => 'One quiet ping at the time. Nothing more.',
                'high' => "Keeps nudging after the deadline until you open the app.",
                _      => 'A heads-up before, plus a follow-up if you miss it.',
              },
              style: TextStyle(fontSize: 13, color: AppColors.label3, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),

          // Verification — does finishing this need a photo, or just a tick?
          _sectionLabel('VERIFICATION'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.separator, width: 1),
            ),
            child: Column(children: [
              GestureDetector(
                onTap: () => setState(() => _requireProof = !_requireProof),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Icon(_requireProof
                            ? Icons.photo_camera_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 20, color: AppColors.label2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Require photo proof',
                            style: TextStyle(fontSize: 15, color: AppColors.label)),
                        const SizedBox(height: 2),
                        Text(
                          _requireProof
                              ? 'Snap a photo to mark it done'
                              : 'Just tick it done — good for group plans',
                          style: TextStyle(fontSize: 12, color: AppColors.label3),
                        ),
                      ]),
                    ),
                    CupertinoSwitch(
                      value: _requireProof,
                      onChanged: (v) => setState(() => _requireProof = v),
                      activeTrackColor: AppColors.label,
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Calendar sync (new, timed tasks only, when writable calendars exist)
          if (!_editing && _kind == _TaskKind.scheduled && _writableCals.isNotEmpty) ...[
            _sectionLabel('CALENDAR'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.separator, width: 1),
              ),
              child: Column(children: [
                GestureDetector(
                  onTap: () => setState(() => _syncCal = !_syncCal),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 20, color: AppColors.label2),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Add to Apple / Google Calendar',
                            style: TextStyle(
                                fontSize: 15, color: AppColors.label)),
                      ),
                      CupertinoSwitch(
                        value: _syncCal,
                        onChanged: (v) => setState(() => _syncCal = v),
                        activeTrackColor: AppColors.label,
                      ),
                    ]),
                  ),
                ),
                if (_syncCal && _writableCals.length > 1) ...[
                  Container(height: 0.5,
                      color: AppColors.separator,
                      margin: const EdgeInsets.symmetric(horizontal: 16)),
                  for (final cal in _writableCals)
                    GestureDetector(
                      onTap: () => setState(() => _syncCalId = cal.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          const SizedBox(width: 32),
                          Expanded(
                            child: Text(cal.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: _syncCalId == cal.id
                                        ? AppColors.label
                                        : AppColors.label2,
                                    fontWeight: _syncCalId == cal.id
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                          ),
                          if (_syncCalId == cal.id)
                            Icon(Icons.check_rounded,
                                size: 17, color: AppColors.label),
                        ]),
                      ),
                    ),
                ],
              ]),
            ),
            const SizedBox(height: 24),
          ],

          // Collaborators — quiet, optional (new tasks only; sharing an
          // existing task is a separate, deliberate action elsewhere).
          if (!_editing) ...[
            _sectionLabel('COLLABORATORS'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickCollaborators,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.separator, width: 1),
                ),
                child: Row(children: [
                  Icon(Icons.group_add_outlined, size: 20, color: AppColors.label2),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    _collab.isEmpty ? 'Share with a friend (optional)'
                                    : '${_collab.length} ${_collab.length == 1 ? "friend" : "friends"} added',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _collab.isEmpty ? FontWeight.w400 : FontWeight.w600,
                      color: _collab.isEmpty ? AppColors.label3 : AppColors.label,
                    ),
                  )),
                  Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.label3),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
          color: AppColors.label3, letterSpacing: 1.5));

  // Scheduled / Today / Anytime segmented selector.
  Widget _kindSelector() {
    const items = [
      (_TaskKind.scheduled, Icons.schedule_rounded, 'Scheduled'),
      (_TaskKind.today,     Icons.today_rounded,     'A day'),
      (_TaskKind.global,    Icons.all_inclusive_rounded, 'Anytime'),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator, width: 1),
      ),
      child: Row(children: items.map((it) {
        final sel = _kind == it.$1;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() { _kind = it.$1; if (it.$1 != _TaskKind.scheduled) _syncCal = false; });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: sel ? AppColors.label : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Icon(it.$2, size: 19, color: sel ? AppColors.bg : AppColors.label3),
                const SizedBox(height: 4),
                Text(it.$3,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: sel ? AppColors.bg : AppColors.label3)),
              ]),
            ),
          ),
        );
      }).toList()),
    );
  }

  Widget _chipButton({required IconData icon, required String label, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.separator, width: 1),
            boxShadow: cardShadow,
          ),
          child: Row(children: [
            Icon(icon, size: 17, color: AppColors.label),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: AppColors.label2))),
          ]),
        ),
      );
}

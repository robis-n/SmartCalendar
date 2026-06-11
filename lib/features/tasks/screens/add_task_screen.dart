import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_utils.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';

class AddTaskScreen extends StatefulWidget {
  final DateTime? initialDate;
  const AddTaskScreen({super.key, this.initialDate});
  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  late DateTime _deadline;
  String _priority = 'medium';
  bool   _saving   = false;

  List<Map<String, dynamic>> _friends = [];
  final Set<String> _collab = {};

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    _deadline = d != null
        ? DateTime(d.year, d.month, d.day, 9, 0)
        : DateTime.now().add(const Duration(hours: 1));
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final f = await SupabaseService.getAcceptedFriends();
    if (mounted) setState(() => _friends = f);
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
                use24hFormat: false,
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
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final created = await SupabaseService.createTask({
        'user_id':        uid,
        'title':          _title.text.trim(),
        'description':    _desc.text.trim(),
        'scheduled_time': tsToDb(_deadline),
        'status':         'pending',
        'ai_generated':   false,
        'priority':       _priority,
      });
      if (_collab.isNotEmpty) {
        await SupabaseService.addCollaborators(created['id'], _collab.toList());
      }
      await NotificationService().scheduleTaskNotifications(
          taskId: created['id'], taskTitle: _title.text.trim(), deadline: _deadline,
          priority: _priority);
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

  String get _timeLabel {
    final h = _deadline.hour;
    final m = _deadline.minute.toString().padLeft(2, '0');
    return '${h % 12 == 0 ? 12 : h % 12}:$m ${h >= 12 ? 'PM' : 'AM'}';
  }

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
        title: const Text('New task'),
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

          // Schedule
          _sectionLabel('SCHEDULE'),
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

          // Collaborators — quiet, optional
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
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
          color: AppColors.label3, letterSpacing: 1.5));

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

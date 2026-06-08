import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});
  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(hours: 1));
  String   _priority = 'medium';
  bool     _saving   = false;

  @override
  void dispose() { _title.dispose(); _desc.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (d != null && mounted) {
      setState(() => _deadline = DateTime(d.year, d.month, d.day, _deadline.hour, _deadline.minute));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (t != null && mounted) {
      setState(() => _deadline = DateTime(_deadline.year, _deadline.month, _deadline.day, t.hour, t.minute));
    }
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
        'scheduled_time': _deadline.toIso8601String(),
        'status':         'pending',
        'ai_generated':   false,
        'priority':       _priority,
      });
      await NotificationService().scheduleTaskNotifications(
          taskId: created['id'], taskTitle: _title.text.trim(), deadline: _deadline);
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
    return '${now.day} ${m[now.month - 1]}';
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
          icon: const Icon(Icons.close, color: AppColors.label2),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Task'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                : GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9B7AFF), Color(0xFF5B3FD9)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Save',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700,
                              fontSize: 14)),
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
              borderRadius: BorderRadius.circular(16),
              boxShadow: cardShadow,
            ),
            child: Column(children: [
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.label, letterSpacing: -0.3),
                decoration: const InputDecoration(
                  hintText: 'What do you need to do?',
                  hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500,
                      color: AppColors.label3, letterSpacing: -0.3),
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                ),
              ),
              const Divider(height: 1, indent: 18, endIndent: 18),
              TextField(
                controller: _desc,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null, minLines: 2,
                style: const TextStyle(fontSize: 15, color: AppColors.label2),
                decoration: const InputDecoration(
                  hintText: 'Add notes…',
                  hintStyle: TextStyle(color: AppColors.label3, fontSize: 15),
                  border: InputBorder.none, enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(18, 10, 18, 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Schedule
          _sectionLabel('SCHEDULE'),
          const SizedBox(height: 8),
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
          const SizedBox(height: 20),

          // Priority
          _sectionLabel('PRIORITY'),
          const SizedBox(height: 8),
          Row(children: [
            for (final p in [
              ('low',    '🟢', 'Low',    AppColors.success,     AppColors.successBg),
              ('medium', '🟡', 'Medium', AppColors.warning,     AppColors.warningBg),
              ('high',   '🔴', 'High',   AppColors.destructive, AppColors.destructiveBg),
            ]) ...[
              if (p.$1 != 'low') const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _priority == p.$1 ? p.$4.withValues(alpha: 0.15) : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _priority == p.$1 ? p.$4 : AppColors.separator,
                        width: _priority == p.$1 ? 1.5 : 1,
                      ),
                      boxShadow: _priority == p.$1 ? cardShadow : null,
                    ),
                    child: Column(children: [
                      Text(p.$2, style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(p.$3, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: _priority == p.$1 ? p.$4 : AppColors.label3,
                      )),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.label3, letterSpacing: 0.8));

  Widget _chipButton({required IconData icon, required String label, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.separator),
            boxShadow: cardShadow,
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.label2)),
          ]),
        ),
      );
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';
import '../../verification/screens/verification_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic>? _task;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await SupabaseService.getTaskById(widget.taskId);
    if (mounted) setState(() { _task = t; _loading = false; });
  }

  // ── Edits ──────────────────────────────────────────────

  Future<void> _editTitle() async {
    final ctrl = TextEditingController(text: _task?['title'] ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Title'),
      content: TextField(controller: ctrl, autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: InputBorder.none)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ));
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await SupabaseService.updateTask(widget.taskId, {'title': ctrl.text.trim()});
    _load();
  }

  Future<void> _editDesc() async {
    final ctrl = TextEditingController(text: _task?['description'] ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Notes'),
      content: TextField(controller: ctrl, autofocus: true, maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(border: InputBorder.none)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ));
    if (ok != true) return;
    await SupabaseService.updateTask(widget.taskId, {'description': ctrl.text.trim()});
    _load();
  }

  Future<void> _reschedule() async {
    final cur = _task?['scheduled_time'] != null
        ? DateTime.parse(_task!['scheduled_time'])
        : DateTime.now().add(const Duration(hours: 1));
    final d = await showDatePicker(context: context, initialDate: cur,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(cur));
    if (t == null || !mounted) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    await SupabaseService.updateTask(widget.taskId, {'scheduled_time': dt.toIso8601String()});
    await NotificationService().scheduleTaskNotifications(
        taskId: widget.taskId, taskTitle: _task?['title'] ?? '', deadline: dt);
    _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete task?'),
      content: Text('"${_task?['title']}"'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.destructive))),
      ],
    ));
    if (ok != true) return;
    await SupabaseService.deleteTask(widget.taskId);
    await NotificationService().cancelTaskNotifications(widget.taskId);
    if (mounted) Navigator.of(context).pop('deleted');
  }

  Future<void> _verify() async {
    final r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(taskId: widget.taskId, taskTitle: _task?['title'] ?? ''),
    ));
    if (r != null && mounted) _load();
  }

  Future<void> _fail() async {
    setState(() => _saving = true);
    await SupabaseService.updateTaskStatus(widget.taskId, 'failed');
    await NotificationService().cancelTaskNotifications(widget.taskId);
    if (mounted) Navigator.of(context).pop('updated');
  }

  // ── Helpers ────────────────────────────────────────────

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final n = DateTime.now();
    if (d.year == n.year && d.month == n.month && d.day == n.day) return 'Today';
    if (d.year == n.year && d.month == n.month && d.day == n.day + 1) return 'Tomorrow';
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Task'),
        actions: [
          if (!_loading && _task != null)
            TextButton(
              onPressed: _delete,
              child: const Text('Delete', style: TextStyle(color: AppColors.destructive)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
          : _task == null
              ? const Center(child: Text('Not found', style: TextStyle(color: AppColors.label3)))
              : _body(),
    );
  }

  Widget _body() {
    final t       = _task!;
    final status  = t['status'] as String? ?? 'pending';
    final priority = t['priority'] as String? ?? 'medium';
    final isDone  = status == 'verified' || status == 'failed';
    final sched   = t['scheduled_time'] != null ? DateTime.parse(t['scheduled_time']) : null;

    final (statusLabel, statusColor) = switch (status) {
      'verified'    => ('Completed', AppColors.success),
      'failed'      => ('Failed',    AppColors.destructive),
      'in_progress' => ('Active',    AppColors.accent),
      _             => ('Pending',   AppColors.label3),
    };

    return ListView(children: [
      // Title
      ListTile(
        title: Text(t['title'] ?? '',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        subtitle: Text(statusLabel, style: TextStyle(fontSize: 13, color: statusColor)),
        trailing: isDone ? null : const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
        onTap: isDone ? null : _editTitle,
      ),
      const Divider(height: 1, indent: 16),

      // Notes
      ListTile(
        title: Text(
          (t['description'] as String?)?.isNotEmpty == true ? t['description'] : 'Add notes…',
          style: TextStyle(
            fontSize: 15,
            color: (t['description'] as String?)?.isNotEmpty == true
                ? AppColors.label
                : AppColors.label3,
          ),
        ),
        trailing: isDone ? null : const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
        onTap: isDone ? null : _editDesc,
      ),
      const Divider(height: 1, indent: 16),

      // Schedule
      ListTile(
        leading: const Icon(Icons.access_time_outlined, size: 20, color: AppColors.accent),
        title: Text(
          sched != null ? '${_fmtDate(sched)}, ${_fmtTime(sched)}' : 'No date',
          style: const TextStyle(fontSize: 15),
        ),
        trailing: isDone ? null : const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
        onTap: isDone ? null : _reschedule,
      ),
      const Divider(height: 1, indent: 16),

      // Priority
      ListTile(
        leading: const Icon(Icons.flag_outlined, size: 20, color: AppColors.label3),
        title: const Text('Priority', style: TextStyle(fontSize: 15)),
        trailing: isDone
            ? Text(
                priority[0].toUpperCase() + priority.substring(1),
                style: TextStyle(fontSize: 15, color: _priColor(priority), fontWeight: FontWeight.w600),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                for (final p in ['low', 'medium', 'high']) ...[
                  if (p != 'low') const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () async {
                      await SupabaseService.updateTask(widget.taskId, {'priority': p});
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: priority == p
                            ? _priColor(p).withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: priority == p ? _priColor(p) : AppColors.separator,
                        ),
                      ),
                      child: Text(
                        p[0].toUpperCase() + p.substring(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: priority == p ? _priColor(p) : AppColors.label3,
                          fontWeight: priority == p ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
      ),
      const Divider(height: 1),

      // Created
      if (t['created_at'] != null) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Created ${_fmtDate(DateTime.parse(t['created_at']))}',
            style: const TextStyle(fontSize: 12, color: AppColors.label3),
          ),
        ),
      ],

      // Actions
      if (status == 'pending') ...[
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilledButton(
            onPressed: _saving ? null : _verify,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Verify Completion', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextButton(
            onPressed: _saving ? null : _fail,
            style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
            child: const Text('Mark as Failed',
                style: TextStyle(color: AppColors.destructive, fontSize: 15)),
          ),
        ),
      ],
      const SizedBox(height: 40),
    ]);
  }

  Color _priColor(String p) => switch (p) {
        'high'   => AppColors.destructive,
        'medium' => AppColors.warning,
        _        => AppColors.success,
      };
}

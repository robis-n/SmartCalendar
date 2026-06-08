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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final task = await SupabaseService.getTaskById(widget.taskId);
    if (mounted) setState(() { _task = task; _loading = false; });
  }

  // ── Actions ────────────────────────────────────────────

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${_task?['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    await SupabaseService.deleteTask(widget.taskId);
    await NotificationService().cancelTaskNotifications(widget.taskId);
    if (mounted) Navigator.of(context).pop('deleted');
  }

  Future<void> _editTitle() async {
    final ctrl = TextEditingController(text: _task?['title'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Task title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    await SupabaseService.updateTask(widget.taskId, {'title': ctrl.text.trim()});
    _load();
  }

  Future<void> _editDescription() async {
    final ctrl = TextEditingController(text: _task?['description'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Description'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await SupabaseService.updateTask(widget.taskId, {'description': ctrl.text.trim()});
    _load();
  }

  Future<void> _reschedule() async {
    final current = _task?['scheduled_time'] != null
        ? DateTime.parse(_task!['scheduled_time'])
        : DateTime.now().add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;

    final newDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await SupabaseService.updateTask(widget.taskId, {'scheduled_time': newDeadline.toIso8601String()});
    await NotificationService().scheduleTaskNotifications(
      taskId: widget.taskId,
      taskTitle: _task?['title'] ?? '',
      deadline: newDeadline,
    );
    _load();
  }

  Future<void> _changePriority(String priority) async {
    await SupabaseService.updateTask(widget.taskId, {'priority': priority});
    _load();
  }

  Future<void> _openVerification() async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(
        taskId: widget.taskId,
        taskTitle: _task?['title'] ?? '',
      ),
    ));
    if (result != null && mounted) _load();
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg2,
      appBar: AppBar(
        title: const Text('Task Detail'),
        backgroundColor: AppColors.bg,
        actions: [
          if (!_loading && _task != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
              onPressed: _delete,
              tooltip: 'Delete task',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? const Center(child: Text('Task not found', style: TextStyle(color: AppColors.label3)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final t = _task!;
    final status = t['status'] as String? ?? 'pending';
    final priority = t['priority'] as String? ?? 'medium';
    final scheduledTime = t['scheduled_time'] != null
        ? DateTime.parse(t['scheduled_time'])
        : null;
    final isDone = status == 'verified' || status == 'failed';

    final (statusLabel, statusColor) = switch (status) {
      'verified' => ('Done ✓', AppColors.success),
      'failed'   => ('Failed', AppColors.destructive),
      'in_progress' => ('In Progress', AppColors.accent),
      _          => ('Pending', AppColors.label3),
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Status badge ───────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 20),

        // ── Title ──────────────────────────────────────
        _section('Title', [
          _editRow(
            child: Text(t['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            onTap: isDone ? null : _editTitle,
          ),
        ]),
        const SizedBox(height: 16),

        // ── Description ────────────────────────────────
        _section('Description', [
          _editRow(
            child: Text(
              (t['description'] as String?)?.isNotEmpty == true
                  ? t['description']
                  : 'No description',
              style: TextStyle(
                fontSize: 15,
                color: (t['description'] as String?)?.isNotEmpty == true
                    ? AppColors.label
                    : AppColors.label3,
              ),
            ),
            onTap: isDone ? null : _editDescription,
          ),
        ]),
        const SizedBox(height: 16),

        // ── Schedule ───────────────────────────────────
        _section('Scheduled', [
          _editRow(
            child: scheduledTime != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_formatDate(scheduledTime), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    Text(_formatTime(scheduledTime), style: const TextStyle(fontSize: 13, color: AppColors.label3)),
                  ])
                : const Text('No date set', style: TextStyle(color: AppColors.label3)),
            onTap: isDone ? null : _reschedule,
          ),
        ]),
        const SizedBox(height: 16),

        // ── Priority ───────────────────────────────────
        _section('Priority', [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: isDone
                ? _priorityChip(priority)
                : SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'low', label: Text('Low')),
                      ButtonSegment(value: 'medium', label: Text('Medium')),
                      ButtonSegment(value: 'high', label: Text('High')),
                    ],
                    selected: {priority},
                    onSelectionChanged: (val) => _changePriority(val.first),
                  ),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Verify button (only for pending tasks) ─────
        if (status == 'pending') ...[
          FilledButton.icon(
            onPressed: _saving ? null : _openVerification,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Verify Completion'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await SupabaseService.updateTaskStatus(widget.taskId, 'failed');
                    await NotificationService().cancelTaskNotifications(widget.taskId);
                    if (mounted) Navigator.of(context).pop('updated');
                  },
            icon: const Icon(Icons.close, color: AppColors.destructive),
            label: const Text('Mark as Failed', style: TextStyle(color: AppColors.destructive)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.destructive),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],

        // ── Metadata ───────────────────────────────────
        const SizedBox(height: 24),
        if (t['created_at'] != null)
          Center(
            child: Text(
              'Created ${_formatDate(DateTime.parse(t['created_at']))}',
              style: const TextStyle(fontSize: 12, color: AppColors.label3),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _section(String label, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ),
          Container(
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: children),
          ),
        ],
      );

  Widget _editRow({required Widget child, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: child),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
          ]),
        ),
      );

  Widget _priorityChip(String p) {
    final (label, color) = switch (p) {
      'high' => ('High', AppColors.destructive),
      'medium' => ('Medium', AppColors.warning),
      _ => ('Low', AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    if (d.year == now.year && d.month == now.month && d.day == now.day + 1) return 'Tomorrow';
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}

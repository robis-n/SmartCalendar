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
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          child: const Text('Save')),
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
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          child: const Text('Save')),
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
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 5, 12, 31));
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
            child: Text('Delete', style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w700))),
      ],
    ));
    if (ok != true) return;
    await SupabaseService.deleteTask(widget.taskId);
    await NotificationService().cancelTaskNotifications(widget.taskId);
    if (mounted) Navigator.of(context).pop('deleted');
  }

  Future<void> _verify() async {
    final r = await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
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
      backgroundColor: AppColors.bg,
      body: _loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.label))
          : _task == null
              ? _notFound()
              : _body(),
    );
  }

  Widget _notFound() => SafeArea(
    child: Column(children: [
      _topBar(null),
      Expanded(
        child: Center(
          child: Text('Not found', style: TextStyle(color: AppColors.label3, fontSize: 16)),
        ),
      ),
    ]),
  );

  Widget _topBar(Map<String, dynamic>? t) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.bg2,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.separator, width: 0.8),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.label),
        ),
      ),
      const Spacer(),
      if (t != null)
        GestureDetector(
          onTap: _delete,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.separator, width: 0.8),
            ),
            child: Text('Delete',
              style: TextStyle(fontSize: 14, color: AppColors.label, fontWeight: FontWeight.w600)),
          ),
        ),
    ]),
  );

  Widget _body() {
    final t        = _task!;
    final status   = t['status'] as String? ?? 'pending';
    final priority = t['priority'] as String? ?? 'medium';
    final sched    = t['scheduled_time'] != null ? DateTime.parse(t['scheduled_time']) : null;

    final statusLabel = switch (status) {
      'verified'    => 'Completed',
      'failed'      => 'Missed',
      'in_progress' => 'Active',
      _             => 'To-do',
    };

    return SafeArea(
      bottom: false,
      child: Column(children: [
        _topBar(t),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
            children: [
              // ── Title + Status ─────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: cardShadow,
                ),
                padding: const EdgeInsets.all(22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.separator, width: 0.8),
                      ),
                      child: Text(statusLabel,
                        style: TextStyle(fontSize: 13, color: AppColors.label, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _editTitle,
                      child: Icon(Icons.edit_outlined, size: 20, color: AppColors.label3),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _editTitle,
                    child: Text(t['title'] ?? '',
                      style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700,
                        color: AppColors.label, letterSpacing: -0.5,
                      )),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Schedule ──────────────────────────────
              _detailCard(
                icon: Icons.access_time_rounded,
                label: 'Scheduled',
                value: sched != null ? '${_fmtDate(sched)}, ${_fmtTime(sched)}' : 'No date set',
                onTap: _reschedule,
              ),
              const SizedBox(height: 10),

              // ── Notes ─────────────────────────────────
              _notesCard(t),
              const SizedBox(height: 10),

              // ── Priority ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: cardShadow,
                ),
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Icon(Icons.flag_outlined, size: 22, color: AppColors.label),
                  const SizedBox(width: 14),
                  Text('Priority', style: TextStyle(fontSize: 16, color: AppColors.label2)),
                  const Spacer(),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final p in ['low', 'medium', 'high']) ...[
                        if (p != 'low') const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () async {
                            await SupabaseService.updateTask(widget.taskId, {'priority': p});
                            _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: priority == p ? AppColors.label : AppColors.bg2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              p[0].toUpperCase() + p.substring(1),
                              style: TextStyle(
                                fontSize: 13,
                                color: priority == p ? AppColors.bg : AppColors.label3,
                                fontWeight: priority == p ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
                ]),
              ),

              // ── Created at ────────────────────────────
              if (t['created_at'] != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Created ${_fmtDate(DateTime.parse(t['created_at']))}',
                    style: TextStyle(fontSize: 13, color: AppColors.label3),
                  ),
                ),
              ],

              // ── Actions ───────────────────────────────
              const SizedBox(height: 28),
              if (status == 'pending') ...[
                FilledButton(
                  onPressed: _saving ? null : _verify,
                  child: const Text('Verify completion'),
                ),
                const SizedBox(height: 12),
                _secondaryButton(label: 'Mark as missed',
                    onTap: _saving ? null : _fail),
              ] else if (status == 'failed') ...[
                // A missed task can now be reopened (this is what was bothering
                // the user — failed = total dead end). Reopening also reschedules
                // notifications via _load → no orphaned state.
                FilledButton(
                  onPressed: _saving ? null : () async {
                    setState(() => _saving = true);
                    await SupabaseService.updateTask(widget.taskId,
                        {'status': 'pending', 'completed_at': null});
                    if (sched != null) {
                      await NotificationService().scheduleTaskNotifications(
                          taskId: widget.taskId, taskTitle: t['title'] ?? '',
                          deadline: sched);
                    }
                    if (mounted) { setState(() => _saving = false); _load(); }
                  },
                  child: const Text('Re-open task'),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: cardShadow,
      ),
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Icon(icon, size: 22, color: AppColors.label),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 16, color: AppColors.label, fontWeight: FontWeight.w500)),
        ])),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.label3),
      ]),
    ),
  );

  // Shared little secondary button — keeps the body free of duplication.
  Widget _secondaryButton({required String label, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.separator, width: 0.8),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppColors.label)),
          ),
        ),
      );

  Widget _notesCard(Map<String, dynamic> t) {
    final hasNotes = (t['description'] as String?)?.isNotEmpty == true;
    return GestureDetector(
      onTap: _editDesc,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: cardShadow,
        ),
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.notes_rounded, size: 22, color: AppColors.label),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notes', style: TextStyle(fontSize: 12, color: AppColors.label3, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
              hasNotes ? t['description'] : 'Add notes…',
              style: TextStyle(
                fontSize: 16,
                color: hasNotes ? AppColors.label : AppColors.label3,
              ),
            ),
          ])),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.label3),
        ]),
      ),
    );
  }
}

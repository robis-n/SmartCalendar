import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_utils.dart';
import '../../../services/device_calendar_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/widgets/wheel_time_picker.dart';
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

  // Owner-aware load: getAnyTaskById resolves the row whether I own it or it
  // was shared with me (RLS still guards access). `_is_owner` decides whether
  // the screen is editable or a read-only "shared with you" view.
  bool get _isOwner => _task?['_is_owner'] != false;

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await SupabaseService.getAnyTaskById(widget.taskId);
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
    final cur = tsTryFromDb(_task?['scheduled_time'] as String?) ??
        DateTime.now().add(const Duration(hours: 1));
    final d = await showDatePicker(context: context, initialDate: cur,
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 5, 12, 31));
    if (d == null || !mounted) return;
    final t = await showWheelTimePicker(context,
        initial: TimeOfDay.fromDateTime(cur));
    if (t == null || !mounted) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    await SupabaseService.updateTask(widget.taskId, {'scheduled_time': tsToDb(dt)});
    await NotificationService().scheduleTaskNotifications(
        taskId: widget.taskId, taskTitle: _task?['title'] ?? '', deadline: dt,
        priority: _task?['priority'] as String? ?? 'medium');
    _load();
  }

  // Reuse a finished task instead of recreating it: pick a fresh time, flip
  // it back to pending, clear the completion stamp and re-arm its reminders.
  Future<void> _resetReminder() async {
    final base = DateTime.now().add(const Duration(hours: 1));
    final d = await showDatePicker(
        context: context,
        initialDate: base,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime(DateTime.now().year + 5, 12, 31));
    if (d == null || !mounted) return;
    final t = await showWheelTimePicker(context,
        initial: TimeOfDay.fromDateTime(base));
    if (t == null || !mounted) return;
    final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);

    setState(() => _saving = true);
    await SupabaseService.updateTask(widget.taskId, {
      'status': 'pending',
      'completed_at': null,
      'scheduled_time': tsToDb(dt),
    });
    await NotificationService().scheduleTaskNotifications(
      taskId: widget.taskId,
      taskTitle: _task?['title'] ?? '',
      deadline: dt,
      priority: _task?['priority'] as String? ?? 'medium',
    );
    if (mounted) { setState(() => _saving = false); _load(); }
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
    // Remove any synced Apple/Google copies before the row goes away.
    final linked = List<dynamic>.from((_task?['device_events'] as List?) ?? const []);
    await DeviceCalendarService.deleteLinkedEvents(linked);
    await SupabaseService.deleteTask(widget.taskId);
    await NotificationService().cancelTaskNotifications(widget.taskId);
    if (mounted) Navigator.of(context).pop('deleted');
  }

  Future<void> _verify() async {
    final r = await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => VerificationScreen(
          taskId: widget.taskId,
          taskTitle: _task?['title'] ?? '',
          taskDescription: _task?['description'] as String?),
    ));
    if (r != null && mounted) _load();
  }

  Future<void> _fail() async {
    setState(() => _saving = true);
    await SupabaseService.updateTaskStatus(widget.taskId, 'failed');
    await NotificationService().cancelTaskNotifications(widget.taskId);
    if (mounted) Navigator.of(context).pop('updated');
  }

  // Complete a task that doesn't require photo proof — a plain tick, no camera.
  Future<void> _markDone() async {
    setState(() => _saving = true);
    await SupabaseService.updateTaskStatus(widget.taskId, 'verified');
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
      // Only the owner can delete; a shared task is read-only for collaborators.
      if (t != null && _isOwner)
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
    final owner    = _isOwner;
    final status   = t['status'] as String? ?? 'pending';
    final priority = t['priority'] as String? ?? 'medium';
    final sched    = tsTryFromDb(t['scheduled_time'] as String?);
    final needsProof = t['verification_required'] != false;

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
              // ── Shared-with-you banner (collaborator, read-only) ──
              if (!owner) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.people_outline_rounded,
                        size: 20, color: AppColors.label2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Shared by ${t['_shared_by'] ?? 'a friend'} · view only',
                        style: TextStyle(fontSize: 14, color: AppColors.label2),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

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
                    if (owner)
                      GestureDetector(
                        onTap: _editTitle,
                        child: Icon(Icons.edit_outlined, size: 20, color: AppColors.label3),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: owner ? _editTitle : null,
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
                onTap: owner ? _reschedule : null,
              ),
              const SizedBox(height: 10),

              // ── Notes ─────────────────────────────────
              _notesCard(t, owner),
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
                  Icon(Icons.notifications_none_rounded, size: 22, color: AppColors.label),
                  const SizedBox(width: 14),
                  Text('Reminders', style: TextStyle(fontSize: 16, color: AppColors.label2)),
                  const Spacer(),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final (p, label) in [('low', 'Gentle'), ('medium', 'Normal'), ('high', 'Persistent')]) ...[
                        if (p != 'low') const SizedBox(width: 6),
                        GestureDetector(
                          onTap: !owner ? null : () async {
                            await SupabaseService.updateTask(widget.taskId, {'priority': p});
                            // Re-arm with the new nudge intensity right away.
                            if (sched != null && status == 'pending') {
                              await NotificationService().scheduleTaskNotifications(
                                  taskId: widget.taskId, taskTitle: t['title'] ?? '',
                                  deadline: sched, priority: p);
                            }
                            _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: priority == p ? AppColors.label : AppColors.bg2,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
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

              // ── Proof requirement (informational) ─────
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: cardShadow,
                ),
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Icon(needsProof
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle_outline_rounded,
                      size: 22, color: AppColors.label),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      needsProof
                          ? 'Photo proof required to complete'
                          : 'No proof needed — just tick it done',
                      style: TextStyle(fontSize: 15, color: AppColors.label2),
                    ),
                  ),
                ]),
              ),

              // ── Created at ────────────────────────────
              if (t['created_at'] != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Created ${_fmtDate(tsFromDb(t['created_at']))}',
                    style: TextStyle(fontSize: 13, color: AppColors.label3),
                  ),
                ),
              ],

              // ── Actions (owner only — collaborators are read-only) ──
              if (!owner) ...[
                const SizedBox(height: 8),
              ] else if (status == 'pending') ...[
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : (needsProof ? _verify : _markDone),
                  child: Text(needsProof ? 'Verify completion' : 'Mark done'),
                ),
                const SizedBox(height: 12),
                _secondaryButton(label: 'Mark as missed',
                    onTap: _saving ? null : _fail),
              ] else if (status == 'failed') ...[
                const SizedBox(height: 28),
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
                          deadline: sched,
                          priority: t['priority'] as String? ?? 'medium');
                    }
                    if (mounted) { setState(() => _saving = false); _load(); }
                  },
                  child: const Text('Re-open task'),
                ),
              ] else if (status == 'verified') ...[
                const SizedBox(height: 28),
                // Reuse a completed task: set a new time and arm it again,
                // so the user never has to recreate the same reminder.
                FilledButton(
                  onPressed: _saving ? null : _resetReminder,
                  child: const Text('Reset reminder'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text('Pick a new time to do this again.',
                      style: TextStyle(fontSize: 13, color: AppColors.label3)),
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

  Widget _notesCard(Map<String, dynamic> t, bool owner) {
    final hasNotes = (t['description'] as String?)?.isNotEmpty == true;
    // For a shared (read-only) task with no notes, don't show an "Add notes…"
    // affordance the collaborator can't act on.
    if (!owner && !hasNotes) return const SizedBox.shrink();
    return GestureDetector(
      onTap: owner ? _editDesc : null,
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
          if (owner)
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.label3),
        ]),
      ),
    );
  }
}

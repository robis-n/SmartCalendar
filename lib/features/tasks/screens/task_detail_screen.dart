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

  Color _priColor(String p) => switch (p) {
        'high'   => AppColors.destructive,
        'medium' => AppColors.warning,
        _        => AppColors.success,
      };

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent))
          : _task == null
              ? _notFound()
              : _body(),
    );
  }

  Widget _notFound() => SafeArea(
    child: Column(children: [
      _topBar(null),
      const Expanded(
        child: Center(
          child: Text('Not found', style: TextStyle(color: AppColors.label3, fontSize: 16)),
        ),
      ),
    ]),
  );

  Widget _topBar(Map<String, dynamic>? t) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            boxShadow: cardShadow,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.label),
        ),
      ),
      const Spacer(),
      if (t != null)
        GestureDetector(
          onTap: _delete,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.destructiveBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Delete',
              style: TextStyle(fontSize: 13, color: AppColors.destructive, fontWeight: FontWeight.w600)),
          ),
        ),
    ]),
  );

  Widget _body() {
    final t        = _task!;
    final status   = t['status'] as String? ?? 'pending';
    final priority = t['priority'] as String? ?? 'medium';
    final isDone   = status == 'verified' || status == 'failed';
    final sched    = t['scheduled_time'] != null ? DateTime.parse(t['scheduled_time']) : null;

    final (statusLabel, statusColor, statusBg) = switch (status) {
      'verified'    => ('Completed', AppColors.success,     AppColors.successBg),
      'failed'      => ('Failed',    AppColors.destructive, AppColors.destructiveBg),
      'in_progress' => ('Active',    AppColors.accent,      AppColors.accentLight),
      _             => ('Pending',   AppColors.label3,      AppColors.bg2),
    };

    return SafeArea(
      bottom: false,
      child: Column(children: [
        _topBar(t),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              // ── Title + Status ─────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: cardShadow,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusLabel,
                        style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    if (!isDone)
                      GestureDetector(
                        onTap: _editTitle,
                        child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.label3),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: isDone ? null : _editTitle,
                    child: Text(t['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.label, letterSpacing: -0.3,
                      )),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Schedule ──────────────────────────────
              _detailCard(
                icon: Icons.access_time_rounded,
                iconColor: AppColors.accent,
                iconBg: AppColors.accentLight,
                label: 'Scheduled',
                value: sched != null ? '${_fmtDate(sched)}, ${_fmtTime(sched)}' : 'No date set',
                onTap: isDone ? null : _reschedule,
              ),
              const SizedBox(height: 10),

              // ── Notes ─────────────────────────────────
              _notesCard(t, isDone),
              const SizedBox(height: 10),

              // ── Priority ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: cardShadow,
                ),
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flag_rounded, size: 18, color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  const Text('Priority', style: TextStyle(fontSize: 14, color: AppColors.label2)),
                  const Spacer(),
                  if (isDone)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priColor(priority).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priority[0].toUpperCase() + priority.substring(1),
                        style: TextStyle(fontSize: 13, color: _priColor(priority), fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final p in ['low', 'medium', 'high']) ...[
                        if (p != 'low') const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () async {
                            await SupabaseService.updateTask(widget.taskId, {'priority': p});
                            _load();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: priority == p
                                  ? _priColor(p).withValues(alpha: 0.15)
                                  : AppColors.bg2,
                              borderRadius: BorderRadius.circular(12),
                              border: priority == p
                                  ? Border.all(color: _priColor(p), width: 1.5)
                                  : null,
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
                ]),
              ),

              // ── Created at ────────────────────────────
              if (t['created_at'] != null) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Created ${_fmtDate(DateTime.parse(t['created_at']))}',
                    style: const TextStyle(fontSize: 12, color: AppColors.label3),
                  ),
                ),
              ],

              // ── Actions ───────────────────────────────
              if (status == 'pending') ...[
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: _saving ? null : _verify,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('Verify Completion',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 0.2,
                        )),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _saving ? null : _fail,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.destructiveBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text('Mark as Failed',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.destructive,
                        )),
                    ),
                  ),
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
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.label3, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, color: AppColors.label, fontWeight: FontWeight.w500)),
        ])),
        if (onTap != null)
          const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
      ]),
    ),
  );

  Widget _notesCard(Map<String, dynamic> t, bool isDone) {
    final hasNotes = (t['description'] as String?)?.isNotEmpty == true;
    return GestureDetector(
      onTap: isDone ? null : _editDesc,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notes_rounded, size: 18, color: AppColors.label2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notes', style: TextStyle(fontSize: 11, color: AppColors.label3, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
              hasNotes ? t['description'] : 'Add notes…',
              style: TextStyle(
                fontSize: 14,
                color: hasNotes ? AppColors.label : AppColors.label3,
              ),
            ),
          ])),
          if (!isDone) const Icon(Icons.chevron_right, size: 18, color: AppColors.label3),
        ]),
      ),
    );
  }
}

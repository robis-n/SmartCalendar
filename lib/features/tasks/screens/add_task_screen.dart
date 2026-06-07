import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/notification_service.dart';
import '../../../services/supabase_service.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _estimatedMinutes = 30;
  String _priority = 'medium';
  bool _loading = false;
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 1));

  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _scheduledTime.hour,
          _scheduledTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
    );
    if (picked != null) {
      setState(() {
        _scheduledTime = DateTime(
          _scheduledTime.year,
          _scheduledTime.month,
          _scheduledTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a task title');
      return;
    }
    setState(() => _loading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final created = await SupabaseService.createTask({
        'user_id': userId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'scheduled_time': _scheduledTime.toIso8601String(),
        'status': 'pending',
        'ai_generated': false,
        'priority': _priority,
      });
      // Schedule reminder notification
      await NotificationService().scheduleTaskNotifications(
        taskId: created['id'],
        taskTitle: _titleController.text.trim(),
        deadline: _scheduledTime,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Failed to save task: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.destructive),
      );

  String get _formattedDate {
    final now = DateTime.now();
    final d = _scheduledTime;
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    if (d.year == now.year && d.month == now.month && d.day == now.day + 1) return 'Tomorrow';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  String get _formattedTime {
    final h = _scheduledTime.hour;
    final m = _scheduledTime.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $suffix';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
        backgroundColor: AppColors.bg,
        actions: [
          TextButton(
            onPressed: _loading ? null : _saveTask,
            child: const Text('Save', style: TextStyle(color: AppColors.accent, fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.task_alt),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // ── Description ────────────────────────────
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // ── Schedule ────────────────────────────────
            Text('Schedule', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Text(_formattedDate, style: const TextStyle(fontSize: 15, color: AppColors.label)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time_outlined, size: 18, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Text(_formattedTime, style: const TextStyle(fontSize: 15, color: AppColors.label)),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Duration ───────────────────────────────
            Text('Estimated Duration', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durationOptions
                  .map((min) => ChoiceChip(
                        label: Text(
                          min < 60
                              ? '${min}m'
                              : min % 60 == 0
                                  ? '${min ~/ 60}h'
                                  : '${min ~/ 60}h ${min % 60}m',
                        ),
                        selected: _estimatedMinutes == min,
                        onSelected: (_) => setState(() => _estimatedMinutes = min),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // ── Priority ───────────────────────────────
            Text('Priority', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low'), icon: Icon(Icons.arrow_downward, size: 14)),
                ButtonSegment(value: 'medium', label: Text('Medium'), icon: Icon(Icons.remove, size: 14)),
                ButtonSegment(value: 'high', label: Text('High'), icon: Icon(Icons.arrow_upward, size: 14)),
              ],
              selected: {_priority},
              onSelectionChanged: (val) => setState(() => _priority = val.first),
            ),
            const SizedBox(height: 36),

            // ── Save button ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _saveTask,
                icon: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_task),
                label: Text(_loading ? 'Saving...' : 'Create Task', style: const TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

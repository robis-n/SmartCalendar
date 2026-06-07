import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/claude_service.dart';
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
  bool _aiSchedule = true;
  bool _loading = false;
  String? _aiReasoning;
  DateTime? _scheduledTime;

  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  Future<void> _getAiSchedule() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() { _loading = true; _aiReasoning = null; });
    try {
      final existingTasks = await SupabaseService.getTodayTasks();
      final result = await ClaudeService().scheduleTask(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        estimatedMinutes: _estimatedMinutes,
        existingTasks: existingTasks,
      );
      setState(() {
        _scheduledTime = DateTime.parse(result['scheduled_time']);
        _aiReasoning = result['reasoning'];
      });
    } catch (e) {
      _showError('AI scheduling failed: $e');
    } finally {
      setState(() => _loading = false);
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
      final deadline = _scheduledTime ?? DateTime.now().add(const Duration(hours: 1));
      final created = await SupabaseService.createTask({
        'user_id': userId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'scheduled_time': deadline.toIso8601String(),
        'status': 'pending',
        'ai_generated': _aiSchedule,
        'ai_reasoning': _aiReasoning,
        'priority': _priority,
      });
      // Schedule notification for this task
      await NotificationService().scheduleTaskNotifications(
        taskId: created['id'],
        taskTitle: _titleController.text.trim(),
        deadline: deadline,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Failed to save task: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Task'), actions: [
        TextButton(onPressed: _loading ? null : _saveTask, child: const Text('Save')),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task title *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.task_alt)),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Duration
            Text('Estimated Duration', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _durationOptions.map((min) => ChoiceChip(
                label: Text('${min}m'),
                selected: _estimatedMinutes == min,
                onSelected: (_) => setState(() => _estimatedMinutes = min),
              )).toList(),
            ),
            const SizedBox(height: 20),

            // Priority
            Text('Priority', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('Low'), icon: Icon(Icons.arrow_downward)),
                ButtonSegment(value: 'medium', label: Text('Medium'), icon: Icon(Icons.remove)),
                ButtonSegment(value: 'high', label: Text('High'), icon: Icon(Icons.arrow_upward)),
              ],
              selected: {_priority},
              onSelectionChanged: (val) => setState(() => _priority = val.first),
            ),
            const SizedBox(height: 20),

            // AI Scheduling toggle
            SwitchListTile(
              title: const Text('AI Smart Scheduling'),
              subtitle: const Text('Let Claude pick the best time'),
              value: _aiSchedule,
              onChanged: (val) => setState(() => _aiSchedule = val),
              secondary: const Icon(Icons.auto_awesome),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
            ),
            const SizedBox(height: 16),

            if (_aiSchedule) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _getAiSchedule,
                  icon: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? 'Thinking...' : 'Get AI Schedule'),
                ),
              ),
              if (_aiReasoning != null && _scheduledTime != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha:0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.schedule, size: 16, color: Color(0xFF6C63FF)),
                        const SizedBox(width: 6),
                        Text(_scheduledTime!.toString().substring(0, 16), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                      ]),
                      const SizedBox(height: 4),
                      Text(_aiReasoning!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _saveTask,
                icon: const Icon(Icons.add_task),
                label: const Text('Create Task', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

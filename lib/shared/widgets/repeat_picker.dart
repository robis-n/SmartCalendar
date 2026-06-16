import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/recurrence.dart';

/// Bottom sheet to choose a repeat rule. Returns the chosen rule map
/// ({'preset': 'daily'} or {'freq':'weekly','interval':2}), `{'preset':'none'}`
/// for Never, or null if dismissed without choosing (caller leaves unchanged).
Future<Map<String, dynamic>?> showRepeatPicker(
    BuildContext context, Map<String, dynamic>? current) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _RepeatSheet(current: current),
  );
}

class _RepeatSheet extends StatefulWidget {
  final Map<String, dynamic>? current;
  const _RepeatSheet({required this.current});
  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  bool _custom = false;
  String _freq = 'weekly';
  int _interval = 2;

  @override
  void initState() {
    super.initState();
    // Pre-open custom mode if the current rule is a custom one.
    final c = widget.current;
    if (c != null && c['freq'] != null) {
      _custom = true;
      _freq = c['freq'] as String;
      _interval = (c['interval'] as num?)?.toInt() ?? 2;
    }
  }

  String? get _currentPreset =>
      widget.current == null ? 'none' : widget.current!['preset'] as String?;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40, height: 5,
            decoration: BoxDecoration(
                color: AppColors.separator,
                borderRadius: BorderRadius.circular(3))),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
          child: Row(children: [
            Text('Repeat',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.label,
                    letterSpacing: -0.5)),
          ]),
        ),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(12, 4, 12, mq.padding.bottom + 24),
            children: [
              for (final (key, label) in Recurrence.presets)
                _option(
                  label: label,
                  selected: !_custom && _currentPreset == key,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, {'preset': key});
                  },
                ),
              const SizedBox(height: 4),
              Container(height: 0.5, color: AppColors.separator,
                  margin: const EdgeInsets.symmetric(horizontal: 12)),
              const SizedBox(height: 4),
              // ── Custom ──
              _option(
                label: 'Custom…',
                selected: _custom,
                onTap: () => setState(() => _custom = true),
              ),
              if (_custom) _customEditor(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _option({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.label)),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: AppColors.accent),
          ]),
        ),
      );

  Widget _customEditor() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('EVERY',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.label3,
                letterSpacing: 1.5)),
        const SizedBox(height: 10),
        // Number stepper
        Row(children: [
          _stepBtn(Icons.remove_rounded,
              () => setState(() => _interval = (_interval - 1).clamp(1, 99))),
          Expanded(
            child: Center(
              child: Text('$_interval',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.label)),
            ),
          ),
          _stepBtn(Icons.add_rounded,
              () => setState(() => _interval = (_interval + 1).clamp(1, 99))),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (key, label) in Recurrence.customFreqs)
            GestureDetector(
              onTap: () => setState(() => _freq = key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _freq == key ? AppColors.label : AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.separator, width: 1),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _freq == key ? AppColors.bg : AppColors.label)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, {'freq': _freq, 'interval': _interval});
            },
            child: Text('Set — ${Recurrence.label({'freq': _freq, 'interval': _interval})}'),
          ),
        ),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.separator, width: 1),
          ),
          child: Icon(icon, size: 20, color: AppColors.label),
        ),
      );
}

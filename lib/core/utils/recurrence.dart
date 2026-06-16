/// Recurrence rules for repeating tasks.
///
/// Stored in `tasks.recurrence` (jsonb). Two shapes:
///   • preset:  {"preset": "daily"}
///   • custom:  {"freq": "weekly", "interval": 2}   // "every 2 weeks"
/// Absent/null/`none` means it does not repeat.
///
/// When a repeating task is completed we spawn the next occurrence by advancing
/// its scheduled time with [nextOccurrence] — simple, predictable, and avoids a
/// fragile always-running recurrence engine.
library;

class Recurrence {
  Recurrence._();

  /// Preset keys in display order, with their human label.
  static const List<(String, String)> presets = [
    ('none',        'Never'),
    ('hourly',      'Hourly'),
    ('daily',       'Daily'),
    ('weekdays',    'Weekdays'),
    ('weekends',    'Weekends'),
    ('weekly',      'Weekly'),
    ('fortnightly', 'Every 2 weeks'),
    ('monthly',     'Monthly'),
    ('quarterly',   'Every 3 months'),
    ('semiannually','Every 6 months'),
    ('yearly',      'Yearly'),
  ];

  /// Custom frequencies offered alongside an "every N" number.
  static const List<(String, String)> customFreqs = [
    ('hourly',  'Hours'),
    ('daily',   'Days'),
    ('weekly',  'Weeks'),
    ('monthly', 'Months'),
    ('yearly',  'Years'),
  ];

  /// Short label for a stored rule, e.g. "Daily", "Every 3 weeks", or null when
  /// it doesn't repeat.
  static String? label(Map<String, dynamic>? rule) {
    if (rule == null) return null;
    final preset = rule['preset'] as String?;
    if (preset != null) {
      if (preset == 'none') return null;
      for (final p in presets) {
        if (p.$1 == preset) return p.$2;
      }
    }
    final freq = rule['freq'] as String?;
    final interval = (rule['interval'] as num?)?.toInt() ?? 1;
    if (freq == null) return null;
    final unit = switch (freq) {
      'hourly'  => interval == 1 ? 'hour'  : 'hours',
      'daily'   => interval == 1 ? 'day'   : 'days',
      'weekly'  => interval == 1 ? 'week'  : 'weeks',
      'monthly' => interval == 1 ? 'month' : 'months',
      'yearly'  => interval == 1 ? 'year'  : 'years',
      _         => 'times',
    };
    return interval == 1 ? 'Every $unit' : 'Every $interval $unit';
  }

  static bool repeats(Map<String, dynamic>? rule) =>
      label(rule) != null;

  static DateTime _addMonths(DateTime d, int months) {
    final m = d.month - 1 + months;
    final y = d.year + (m ~/ 12);
    final mm = m % 12;
    // Clamp the day to the target month's length (e.g. Jan 31 + 1mo -> Feb 28).
    final lastDay = DateTime(y, mm + 2, 0).day;
    return DateTime(y, mm + 1, d.day > lastDay ? lastDay : d.day,
        d.hour, d.minute);
  }

  /// The next occurrence strictly after [from], or null if the rule doesn't
  /// repeat. For weekdays/weekends it lands on the next valid day.
  static DateTime? nextOccurrence(DateTime from, Map<String, dynamic>? rule) {
    if (rule == null) return null;
    final preset = rule['preset'] as String?;
    if (preset != null && preset != 'none') {
      switch (preset) {
        case 'hourly':       return from.add(const Duration(hours: 1));
        case 'daily':        return from.add(const Duration(days: 1));
        case 'weekly':       return from.add(const Duration(days: 7));
        case 'fortnightly':  return from.add(const Duration(days: 14));
        case 'monthly':      return _addMonths(from, 1);
        case 'quarterly':    return _addMonths(from, 3);
        case 'semiannually': return _addMonths(from, 6);
        case 'yearly':       return _addMonths(from, 12);
        case 'weekdays': {
          var d = from.add(const Duration(days: 1));
          while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
            d = d.add(const Duration(days: 1));
          }
          return d;
        }
        case 'weekends': {
          var d = from.add(const Duration(days: 1));
          while (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
            d = d.add(const Duration(days: 1));
          }
          return d;
        }
      }
    }
    final freq = rule['freq'] as String?;
    final n = (rule['interval'] as num?)?.toInt() ?? 1;
    if (freq == null) return null;
    return switch (freq) {
      'hourly'  => from.add(Duration(hours: n)),
      'daily'   => from.add(Duration(days: n)),
      'weekly'  => from.add(Duration(days: 7 * n)),
      'monthly' => _addMonths(from, n),
      'yearly'  => _addMonths(from, 12 * n),
      _         => null,
    };
  }
}

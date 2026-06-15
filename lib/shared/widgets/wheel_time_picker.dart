import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A clean Cupertino wheel time picker in a bottom sheet — the same control
/// used when creating a task. Replaces Material's `showTimePicker` clock dial,
/// which felt out of place in this app. Returns the chosen [TimeOfDay], or null
/// if dismissed. Keep all time-of-day editing routed through here so the app
/// never shows the analog clock again.
Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  String title = 'Pick a time',
}) async {
  // Anchor on an arbitrary date — only the time component is used.
  DateTime temp = DateTime(2000, 1, 1, initial.hour, initial.minute);
  var confirmed = false;

  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
                color: AppColors.separator,
                borderRadius: BorderRadius.circular(3))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
          child: Row(children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label)),
            const Spacer(),
            TextButton(
              onPressed: () {
                confirmed = true;
                Navigator.pop(ctx);
              },
              child: Text('Done',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label)),
            ),
          ]),
        ),
        SizedBox(
          height: 216,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness:
                  AppColors.isDark ? Brightness.dark : Brightness.light,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: temp,
              use24hFormat: false,
              onDateTimeChanged: (dt) => temp = dt,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );

  if (!confirmed) return null;
  return TimeOfDay(hour: temp.hour, minute: temp.minute);
}

/// Platform-adaptive date picker.
/// Uses CupertinoDatePicker in a bottom sheet on iOS,
/// Material showDatePicker on Android.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// A platform-adaptive date picker helper.
/// Shows a CupertinoDatePicker in a modal bottom sheet on iOS,
/// and the standard Material date picker dialog on Android.
class AdaptiveDatePicker {
  AdaptiveDatePicker._();

  /// Shows a platform-adaptive date picker.
  ///
  /// Returns the selected date, or null if cancelled.
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) async {
    if (Platform.isIOS) {
      return _showCupertinoDatePicker(
        context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        cancelText: cancelText,
        confirmText: confirmText,
      );
    }

    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  /// Shows a Cupertino-style date picker in a modal bottom sheet.
  static Future<DateTime?> _showCupertinoDatePicker(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    String? cancelText,
    String? confirmText,
  }) async {
    DateTime selectedDate = initialDate;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                // Header with Cancel and Done buttons
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingM,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          cancelText ?? 'Avbryt',
                          style: TextStyle(
                            color:
                                CupertinoColors.systemBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            Navigator.of(context).pop(selectedDate),
                        child: Text(
                          confirmText ?? 'Klar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                CupertinoColors.systemBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Date picker
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initialDate,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    onDateTimeChanged: (date) {
                      selectedDate = date;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result;
  }

  /// Shows a platform-adaptive date and time picker.
  ///
  /// Returns the selected date and time, or null if cancelled.
  static Future<DateTime?> showDateTime(
    BuildContext context, {
    required DateTime initialDateTime,
    required DateTime firstDate,
    required DateTime lastDate,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) async {
    if (Platform.isIOS) {
      return _showCupertinoDateTimePicker(
        context,
        initialDateTime: initialDateTime,
        firstDate: firstDate,
        lastDate: lastDate,
        cancelText: cancelText,
        confirmText: confirmText,
      );
    }

    // On Android, show date picker first, then time picker
    final date = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
    );

    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
      cancelText: cancelText,
      confirmText: confirmText,
    );

    if (time == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  /// Shows a Cupertino-style date and time picker.
  static Future<DateTime?> _showCupertinoDateTimePicker(
    BuildContext context, {
    required DateTime initialDateTime,
    required DateTime firstDate,
    required DateTime lastDate,
    String? cancelText,
    String? confirmText,
  }) async {
    DateTime selectedDateTime = initialDateTime;

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                // Header with Cancel and Done buttons
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingM,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          cancelText ?? 'Avbryt',
                          style: TextStyle(
                            color:
                                CupertinoColors.systemBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            Navigator.of(context).pop(selectedDateTime),
                        child: Text(
                          confirmText ?? 'Klar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                CupertinoColors.systemBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Date and time picker
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    initialDateTime: initialDateTime,
                    minimumDate: firstDate,
                    maximumDate: lastDate,
                    onDateTimeChanged: (dateTime) {
                      selectedDateTime = dateTime;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result;
  }

  /// Shows a platform-adaptive time picker.
  ///
  /// Returns the selected time, or null if cancelled.
  static Future<TimeOfDay?> showTime(
    BuildContext context, {
    required TimeOfDay initialTime,
    String? helpText,
    String? cancelText,
    String? confirmText,
  }) async {
    if (Platform.isIOS) {
      return _showCupertinoTimePicker(
        context,
        initialTime: initialTime,
        cancelText: cancelText,
        confirmText: confirmText,
      );
    }

    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      cancelText: cancelText,
      confirmText: confirmText,
    );
  }

  /// Shows a Cupertino-style time picker.
  static Future<TimeOfDay?> _showCupertinoTimePicker(
    BuildContext context, {
    required TimeOfDay initialTime,
    String? cancelText,
    String? confirmText,
  }) async {
    final now = DateTime.now();
    DateTime selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    final result = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                // Header with Cancel and Done buttons
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingM,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator.resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          cancelText ?? 'Avbryt',
                          style: TextStyle(
                            color:
                                CupertinoColors.systemBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(
                          TimeOfDay.fromDateTime(selectedDateTime),
                        ),
                        child: Text(
                          confirmText ?? 'Klar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                CupertinoColors.systemBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Time picker
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: selectedDateTime,
                    onDateTimeChanged: (dateTime) {
                      selectedDateTime = dateTime;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result;
  }
}

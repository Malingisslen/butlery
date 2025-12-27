/// Platform-adaptive switch widget.
/// Uses CupertinoSwitch on iOS, Switch on Android.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A platform-adaptive switch widget.
/// Automatically uses CupertinoSwitch on iOS and Material Switch on Android.
class AdaptiveSwitch extends StatelessWidget {
  /// Creates a platform-adaptive switch.
  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.trackColor,
    this.thumbColor,
  });

  /// Whether this switch is on or off.
  final bool value;

  /// Called when the user toggles the switch on or off.
  final ValueChanged<bool>? onChanged;

  /// The color to use when this switch is on.
  final Color? activeColor;

  /// The color of the track.
  final Color? trackColor;

  /// The color of the thumb.
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: activeColor,
        inactiveTrackColor: trackColor,
        thumbColor: thumbColor,
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor,
      activeTrackColor: activeColor?.withValues(alpha: 0.5),
      inactiveTrackColor: trackColor,
      thumbColor:
          thumbColor != null ? WidgetStateProperty.all(thumbColor) : null,
    );
  }
}

/// A platform-adaptive switch list tile.
/// Combines a list tile with an adaptive switch.
class AdaptiveSwitchListTile extends StatelessWidget {
  /// Creates a platform-adaptive switch list tile.
  const AdaptiveSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.activeColor,
    this.contentPadding,
    this.dense,
  });

  /// Whether this switch is on or off.
  final bool value;

  /// Called when the user toggles the switch on or off.
  final ValueChanged<bool>? onChanged;

  /// The primary content of the list tile.
  final Widget? title;

  /// Additional content displayed below the title.
  final Widget? subtitle;

  /// A widget to display on the opposite side of the switch.
  final Widget? secondary;

  /// The color to use when this switch is on.
  final Color? activeColor;

  /// The padding for the tile's contents.
  final EdgeInsetsGeometry? contentPadding;

  /// Whether this list tile is part of a dense list.
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      // Use CupertinoListTile-style layout with CupertinoSwitch
      return ListTile(
        title: title,
        subtitle: subtitle,
        leading: secondary,
        contentPadding: contentPadding,
        dense: dense,
        trailing: CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: activeColor,
        ),
        onTap: onChanged != null ? () => onChanged!(!value) : null,
      );
    }

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      activeThumbColor: activeColor,
      activeTrackColor: activeColor?.withValues(alpha: 0.5),
      contentPadding: contentPadding,
      dense: dense,
    );
  }
}

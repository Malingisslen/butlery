/// Platform-adaptive switch widget.
/// Uses CupertinoSwitch on iOS, Switch on Android.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';

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

  /// Anroparens spårfärg för på-läget, ogenomskinlig.
  ///
  /// Null låter temat (`switchTheme`) bestämma på-läget; det är där ink ska
  /// komma ifrån (Komponentark v1:172, "Ink = på", rad 176). Satt ritas spåret
  /// i exakt den här färgen — opacitet är aldrig ett tillstånd
  /// (tokens.json:40-53, opacityLadder).
  final Color? activeColor;

  /// The color of the track.
  final Color? trackColor;

  /// The color of the thumb.
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    // The shared grip: a 48 dp box with the focus ring around the whole box
    // and no saffron focus tint (Grafisk manual v6:209, :381).
    return ButleryControlFocus(
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: _buildSwitch(context),
    );
  }

  Widget _buildSwitch(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
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
      // Knoppen på ett helt fyllt spår kan inte ha spårets färg: den skulle
      // försvinna. Komponentark v1:172 ritar papper på ink; onPrimary är
      // papper i båda lägena (app_colors.dart lightColorScheme och
      // darkColorScheme, onPrimary 0xFFF5F4ED).
      activeThumbColor: activeColor == null
          ? null
          : Theme.of(context).colorScheme.onPrimary,
      activeTrackColor: activeColor,
      inactiveTrackColor: trackColor,
      thumbColor: thumbColor != null
          ? WidgetStateProperty.all(thumbColor)
          : null,
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

  /// Anroparens spårfärg för på-läget, ogenomskinlig. Se
  /// [AdaptiveSwitch.activeColor].
  final Color? activeColor;

  /// The padding for the tile's contents.
  final EdgeInsetsGeometry? contentPadding;

  /// Whether this list tile is part of a dense list.
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    // The row takes focus, so the ring goes around the whole row.
    return ButleryControlFocus(child: _buildTile(context));
  }

  Widget _buildTile(BuildContext context) {
    if (!kIsWeb && Platform.isIOS) {
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
      activeThumbColor: activeColor == null
          ? null
          : Theme.of(context).colorScheme.onPrimary,
      activeTrackColor: activeColor,
      contentPadding: contentPadding,
      dense: dense,
    );
  }
}

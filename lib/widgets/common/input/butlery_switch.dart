// lib/widgets/common/input/butlery_switch.dart
//
// tokens.json controls.toggle: 34 x 20 with a 16 knob.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/butlery_control_focus.dart';

class ButlerySwitch extends StatelessWidget {
  const ButlerySwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;

  /// Null stops the switch toggling and draws it disabled.
  final ValueChanged<bool>? onChanged;

  /// tokens.json controls.toggle.width and .height.
  static const double trackWidth = 34;
  static const double trackHeight = 20;

  // Material has no size setting for its switch and draws the track at this
  // size, so the token's track is scaled down from it.
  static const double _materialTrackWidth = 52;
  static const double _materialTrackHeight = 32;
  static const double _scale = trackWidth / _materialTrackWidth;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    // The padding around the track is the touch target, so a tap beside the
    // drawn track still toggles it; one node covers it for a screen reader.
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: SizedBox.square(
          dimension: ButleryControlFocus.minSize,
          child: Center(
            child: SizedBox(
              width: trackWidth,
              height: trackHeight,
              child: OverflowBox(
                maxWidth: _materialTrackWidth,
                maxHeight: _materialTrackHeight,
                child: Transform.scale(
                  scale: _scale,
                  child: Switch(
                    value: value,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

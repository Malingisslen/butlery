import 'package:flutter/material.dart';

import 'package:butlery/theme/app_text_styles.dart';

/// The one error-text style (BUT-2371): listItem (13/600) in the danger
/// colour of [cs], so it follows the mode. On paper that is cs.error; on
/// surface.raised or the danger tint, [onRaised], it is cs.onErrorContainer:
/// dark cs.error is 4.18:1 on surface.raised, onErrorContainer 4.86:1. A
/// static AppTextStyles member could only hold the light value.
TextStyle errorTextStyle(ColorScheme cs, {bool onRaised = false}) =>
    AppTextStyles.bodySmall.copyWith(
      color: onRaised ? cs.onErrorContainer : cs.error,
    );

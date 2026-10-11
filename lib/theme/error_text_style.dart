import 'package:flutter/material.dart';

import 'package:butlery/theme/app_text_styles.dart';

/// The one error-text style (BUT-2371): listItem (13/600) in the danger
/// colour of [cs], so it follows the mode. On paper that is cs.error; on the
/// danger tint, [onDangerTint], it is cs.onErrorContainer. A static
/// AppTextStyles member could only hold the light value.
TextStyle errorTextStyle(ColorScheme cs, {bool onDangerTint = false}) =>
    AppTextStyles.bodySmall.copyWith(
      color: onDangerTint ? cs.onErrorContainer : cs.error,
    );

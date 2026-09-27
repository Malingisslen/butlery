/// Type roles that tokens.json defines but the generated AppTextStyles does
/// not carry yet.
///
/// Each member here is built from a generated role and matches the token
/// exactly. It goes away when the generator (tools/gen-app-theme.mjs in the
/// design system) emits the role, through the D1 delivery routine.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_text_styles.dart';

class AppTextRolesPending {
  AppTextRolesPending._();

  /// tokens.json typography.roles.calendarCell: 11/600, line height 1.45,
  /// "endast kalendercellens rättnamn — 52 dp kolumn" (decision B-41).
  /// navLabel (labelSmall) is 11/700 at 1.45, so only the weight differs.
  static TextStyle get calendarCell =>
      AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600);
}

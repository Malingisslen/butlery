/// Theme constants for opacity, elevation, animation, and visual effects.

import 'package:flutter/material.dart';

/// Central repository for specialized theme constants.
class ThemeConstants {
  /// Private constructor to prevent instantiation of utility class
  ThemeConstants._();

  /// 10% opacity
  static const double opacity10 = 0.1;

  /// 20% opacity
  static const double opacity20 = 0.2;

  /// 30% opacity
  static const double opacity30 = 0.3;

  /// 40% opacity (0x66 in hex)
  static const double opacity40 = 0.4;

  /// 50% opacity
  static const double opacity50 = 0.5;

  /// 60% opacity
  static const double opacity60 = 0.6;

  /// 66% opacity (common for overlays)
  static const double opacity66 = 0.66;

  /// 70% opacity
  static const double opacity70 = 0.7;

  /// 80% opacity
  static const double opacity80 = 0.8;

  /// 90% opacity
  static const double opacity90 = 0.9;

  /// 100% opacity (fully opaque)
  static const double opacity100 = 1.0;

  /// Small blur radius
  static const double blurRadiusSmall = 4.0;

  /// Medium blur radius
  static const double blurRadiusMedium = 8.0;

  /// Large blur radius
  static const double blurRadiusLarge = 12.0;

  /// Extra large blur radius
  static const double blurRadiusXLarge = 16.0;

  /// Zero spread radius
  static const double spreadRadiusZero = 0.0;

  /// Small spread radius
  static const double spreadRadiusSmall = 1.0;

  /// Medium spread radius
  static const double spreadRadiusMedium = 2.0;

  /// Large spread radius
  static const double spreadRadiusLarge = 4.0;

  /// White overlay with 40% opacity
  static const Color whiteOverlay40 = Color(0x66FFFFFF);

  /// Black overlay with 10% opacity
  static const Color blackOverlay10 = Color(0x1A000000);

  /// Black overlay with 20% opacity
  static const Color blackOverlay20 = Color(0x33000000);

  /// Black overlay with 40% opacity
  static const Color blackOverlay40 = Color(0x66000000);

  /// Black overlay with 60% opacity
  static const Color blackOverlay60 = Color(0x99000000);

  /// Standard ease in out curve
  static const Curve standardCurve = Curves.easeInOut;

  /// Fast out slow in curve (Material Design)
  static const Curve materialCurve = Curves.fastOutSlowIn;

  /// Deceleration curve
  static const Curve decelerationCurve = Curves.decelerate;

  /// Acceleration curve
  static const Curve accelerationCurve = Curves.easeIn;

  /// Instant (no animation)
  static const Duration durationInstant = Duration.zero;

  /// Extra fast animation (100ms)
  static const Duration durationXFast = Duration(milliseconds: 100);

  /// Fast animation (150ms)
  static const Duration durationFast = Duration(milliseconds: 150);

  /// Standard animation (200ms)
  static const Duration durationStandard = Duration(milliseconds: 200);

  /// Medium animation (300ms)
  static const Duration durationMedium = Duration(milliseconds: 300);

  /// Slow animation (400ms)
  static const Duration durationSlow = Duration(milliseconds: 400);

  /// Extra slow animation (600ms)
  static const Duration durationXSlow = Duration(milliseconds: 600);

  /// Page transition duration (350ms)
  static const Duration durationPageTransition = Duration(milliseconds: 350);
}

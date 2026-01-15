/// Brand colors for external platforms and services.
/// These colors should match official brand guidelines.
///
/// Usage: Import this file when displaying platform-specific UI elements
/// like badges, icons, or links to external recipe sources.

import 'package:flutter/material.dart';

/// Central repository for platform and service brand colors.
/// Ensures visual consistency when displaying third-party platform elements.
abstract class BrandColors {
  BrandColors._();

  // Social Media Platforms
  /// YouTube brand red
  static const Color youtube = Color(0xFFFF0000);

  /// TikTok brand cyan
  static const Color tiktok = Color(0xFF00F2EA);

  /// Instagram brand pink
  static const Color instagram = Color(0xFFE1306C);

  /// Twitter (X) brand blue
  static const Color twitter = Color(0xFF1DA1F2);

  /// Pinterest brand red
  static const Color pinterest = Color(0xFFE60023);

  /// WhatsApp brand green
  static const Color whatsapp = Color(0xFF25D366);

  /// Telegram brand blue
  static const Color telegram = Color(0xFF0088CC);

  /// Facebook brand blue
  static const Color facebook = Color(0xFF1877F2);

  /// Reddit brand orange
  static const Color reddit = Color(0xFFFF4500);

  // Swedish Recipe Platforms
  /// AllRecipes brand red
  static const Color allrecipes = Color(0xFFBD081C);

  /// ICA brand orange
  static const Color ica = Color(0xFFFF6600);

  /// Coop brand green
  static const Color coop = Color(0xFF006341);

  /// Arla brand red
  static const Color arla = Color(0xFFE30613);

  /// Koket.se brand black
  static const Color koketSe = Color(0xFF000000);

  // Generic fallback for unknown platforms
  /// Generic platform color (neutral gray)
  static const Color generic = Color(0xFF6B7280);

  // Platform-specific background colors (light tints for badges)
  /// YouTube light background (light red tint)
  static const Color youtubeBackground = Color(0xFFFFE0E0);

  /// TikTok light background (light cyan tint)
  static const Color tiktokBackground = Color(0xFFE0F7FA);

  /// Instagram light background (light pink tint)
  static const Color instagramBackground = Color(0xFFFCE4EC);

  // Platform-specific text colors (darker shades for readability)
  /// YouTube dark text color
  static const Color youtubeText = Color(0xFFCC0000);

  /// TikTok dark text color (black per brand guidelines)
  static const Color tiktokText = Color(0xFF161823);

  /// Instagram dark text color
  static const Color instagramText = Color(0xFFC13584);
}

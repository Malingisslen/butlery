/// Brand colors for external platforms and services.
/// These colors should match official brand guidelines.
///
/// Usage: Import this file when displaying platform-specific UI elements
/// like badges, icons, or links to external recipe sources.
///
/// BUT-690: hex literals live in `AppColors.brand*`; this class is the
/// stable platform-semantic API surface so callers don't need to know
/// the underlying token names.

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_colors.dart';

/// Central repository for platform and service brand colors.
/// Ensures visual consistency when displaying third-party platform elements.
abstract class BrandColors {
  BrandColors._();

  // Social Media Platforms
  /// YouTube brand red
  static const Color youtube = AppColors.brandYoutube;

  /// TikTok brand cyan
  static const Color tiktok = AppColors.brandTiktok;

  /// Instagram brand pink
  static const Color instagram = AppColors.brandInstagram;

  /// Twitter (X) brand blue
  static const Color twitter = AppColors.brandTwitter;

  /// Pinterest brand red
  static const Color pinterest = AppColors.brandPinterest;

  /// WhatsApp brand green
  static const Color whatsapp = AppColors.brandWhatsapp;

  /// Telegram brand blue
  static const Color telegram = AppColors.brandTelegram;

  /// Facebook brand blue
  static const Color facebook = AppColors.brandFacebook;

  /// Reddit brand orange
  static const Color reddit = AppColors.brandReddit;

  // Swedish Recipe Platforms
  /// AllRecipes brand red
  static const Color allrecipes = AppColors.brandAllrecipes;

  /// ICA brand orange
  static const Color ica = AppColors.brandIca;

  /// Coop brand green
  static const Color coop = AppColors.brandCoop;

  /// Arla brand red
  static const Color arla = AppColors.brandArla;

  /// Koket.se brand black
  static const Color koketSe = AppColors.brandKoketSe;

  // Generic fallback for unknown platforms
  /// Generic platform color (neutral gray)
  static const Color generic = AppColors.brandGeneric;

  // Platform-specific background colors (light tints for badges)
  /// YouTube light background (light red tint)
  static const Color youtubeBackground = AppColors.brandYoutubeBackground;

  /// TikTok light background (light cyan tint)
  static const Color tiktokBackground = AppColors.brandTiktokBackground;

  /// Instagram light background (light pink tint)
  static const Color instagramBackground = AppColors.brandInstagramBackground;

  // Platform-specific text colors (darker shades for readability)
  /// YouTube dark text color
  static const Color youtubeText = AppColors.brandYoutubeText;

  /// TikTok dark text color (black per brand guidelines)
  static const Color tiktokText = AppColors.brandTiktokText;

  /// Instagram dark text color
  static const Color instagramText = AppColors.brandInstagramText;
}

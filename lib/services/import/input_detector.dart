/// Input detection service for the unified import system.
///
/// Detects whether user input is a URL or plain text, and identifies
/// the platform (YouTube, TikTok, Instagram, or generic website).
library;

import 'package:butlery/core/l10n/app_locale.dart';

/// The type of input detected.
enum InputType {
  url,
  text,
}

/// The platform detected from the URL.
enum Platform {
  youtube,
  tiktok,
  instagram,
  website,
  unknown,
}

/// Result of input detection.
class InputDetectionResult {
  final InputType type;
  final Platform platform;
  final String input;
  final Uri? uri;

  const InputDetectionResult({
    required this.type,
    required this.platform,
    required this.input,
    this.uri,
  });

  bool get isUrl => type == InputType.url;
  bool get isText => type == InputType.text;
  bool get isYouTube => platform == Platform.youtube;
  bool get isTikTok => platform == Platform.tiktok;
  bool get isInstagram => platform == Platform.instagram;
  bool get isWebsite => platform == Platform.website;

  /// Returns localized label for the platform.
  String get platformLabel {
    final l = AppLocale.current;
    switch (platform) {
      case Platform.youtube:
        return l.platformYouTube;
      case Platform.tiktok:
        return l.platformTikTok;
      case Platform.instagram:
        return l.platformInstagram;
      case Platform.website:
        return l.platformWebsite;
      case Platform.unknown:
        return l.platformPastedText;
    }
  }
}

/// Service that detects input type and platform from user input.
class InputDetector {
  /// YouTube URL patterns.
  static final _youtubePatterns = [
    RegExp(r'youtube\.com', caseSensitive: false),
    RegExp(r'youtu\.be', caseSensitive: false),
  ];

  /// TikTok URL patterns.
  static final _tiktokPatterns = [
    RegExp(r'tiktok\.com', caseSensitive: false),
    RegExp(r'vm\.tiktok\.com', caseSensitive: false),
  ];

  /// Instagram URL patterns.
  static final _instagramPatterns = [
    RegExp(r'instagram\.com', caseSensitive: false),
    RegExp(r'instagr\.am', caseSensitive: false),
  ];

  /// Detects the type and platform of the given input.
  InputDetectionResult detect(String input) {
    final trimmed = input.trim();

    if (trimmed.isEmpty) {
      return InputDetectionResult(
        type: InputType.text,
        platform: Platform.unknown,
        input: trimmed,
      );
    }

    // Try to parse as URL
    final uri = _tryParseUrl(trimmed);
    if (uri != null) {
      final platform = _detectPlatform(uri);
      return InputDetectionResult(
        type: InputType.url,
        platform: platform,
        input: trimmed,
        uri: uri,
      );
    }

    // Not a valid URL, treat as text
    return InputDetectionResult(
      type: InputType.text,
      platform: Platform.unknown,
      input: trimmed,
    );
  }

  /// Tries to parse the input as a URL.
  Uri? _tryParseUrl(String input) {
    // Check if it looks like a URL
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      // Try adding https:// if it looks like a domain
      if (_looksLikeDomain(input)) {
        input = 'https://$input';
      } else {
        return null;
      }
    }

    try {
      final uri = Uri.parse(input);
      // Validate it has a host
      if (uri.host.isNotEmpty) {
        return uri;
      }
    } catch (_) {
      // Invalid URL
    }
    return null;
  }

  /// Checks if the input looks like a domain (e.g., "youtube.com/watch?v=xxx").
  bool _looksLikeDomain(String input) {
    // Simple heuristic: contains a dot and no spaces in the first part
    final parts = input.split(' ');
    if (parts.isEmpty) return false;
    final firstPart = parts.first;
    return firstPart.contains('.') && !firstPart.contains('\n');
  }

  /// Detects the platform from the URL.
  Platform _detectPlatform(Uri uri) {
    final host = uri.host.toLowerCase();

    // Check YouTube
    for (final pattern in _youtubePatterns) {
      if (pattern.hasMatch(host)) {
        return Platform.youtube;
      }
    }

    // Check TikTok
    for (final pattern in _tiktokPatterns) {
      if (pattern.hasMatch(host)) {
        return Platform.tiktok;
      }
    }

    // Check Instagram
    for (final pattern in _instagramPatterns) {
      if (pattern.hasMatch(host)) {
        return Platform.instagram;
      }
    }

    // Generic website
    return Platform.website;
  }
}

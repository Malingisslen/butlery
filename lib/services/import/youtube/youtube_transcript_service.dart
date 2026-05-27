/// Service for fetching transcripts and metadata from YouTube videos.
///
/// Uses web-based approaches (no API key required):
/// - oEmbed API for video metadata
/// - Video page parsing for transcript/caption extraction
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:butlery/core/constants/http_constants.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/import/youtube/youtube_models.dart';

/// Service to fetch YouTube video transcripts and metadata.
class YouTubeTranscriptService with ErrorHandlingMixin {
  /// Patterns for extracting video IDs from various YouTube URL formats.
  ///
  /// All host-anchored patterns require `^https?://(?:www\.|m\.)?` (BUT-1091)
  /// so typosquats like `iyoutube.com/watch?...` and `evilyoutube.com/...`
  /// cannot match. `caseSensitive: false` accepts mixed-case hosts from
  /// share-sheets / iOS Safari (BUT-1116).
  static final _videoIdPatterns = [
    // Standard watch URL: youtube.com/watch?v=VIDEO_ID
    RegExp(
        r'^https?://(?:www\.|m\.)?youtube\.com/watch\?.*v=([A-Za-z0-9_-]{11})',
        caseSensitive: false),
    // Short URL: youtu.be/VIDEO_ID (also accepts `www.youtu.be/` — rare but
    // legitimate; `www.youtu.be` resolves and 301-redirects to youtu.be).
    RegExp(r'^https?://(?:www\.)?youtu\.be/([A-Za-z0-9_-]{11})',
        caseSensitive: false),
    // Shorts: youtube.com/shorts/VIDEO_ID
    RegExp(r'^https?://(?:www\.|m\.)?youtube\.com/shorts/([A-Za-z0-9_-]{11})',
        caseSensitive: false),
    // Embed: youtube.com/embed/VIDEO_ID
    RegExp(r'^https?://(?:www\.|m\.)?youtube\.com/embed/([A-Za-z0-9_-]{11})',
        caseSensitive: false),
    // Live: youtube.com/live/VIDEO_ID
    RegExp(r'^https?://(?:www\.|m\.)?youtube\.com/live/([A-Za-z0-9_-]{11})',
        caseSensitive: false),
    // Just the video ID. BUT-1091 trade-off: this pattern still matches any
    // 11-char `[A-Za-z0-9_-]` string. Acceptable because the only caller path
    // that hits `canHandle` with a bare ID is direct user input after they've
    // already picked "YouTube import" — the typosquat surface lives on the
    // URL patterns above, which are now host-anchored.
    RegExp(r'^([A-Za-z0-9_-]{11})$'),
  ];

  /// Preferred languages for transcripts, in order of preference.
  static const _preferredLanguages = ['sv', 'en', 'da', 'no', 'nb'];

  final http.Client _client;
  final bool _ownsClient;

  YouTubeTranscriptService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Extract video ID from various YouTube URL formats.
  ///
  /// Returns null if the URL doesn't match any known YouTube format.
  String? extractVideoId(String url) {
    final trimmed = url.trim();

    for (final pattern in _videoIdPatterns) {
      final match = pattern.firstMatch(trimmed);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Check if a URL is a YouTube URL.
  bool isYouTubeUrl(String url) {
    return extractVideoId(url) != null;
  }

  /// Fetch video metadata using YouTube's oEmbed API.
  ///
  /// This doesn't require an API key and provides basic video info.
  Future<VideoMetadata?> fetchVideoMetadata(String videoIdOrUrl) async {
    final videoId = extractVideoId(videoIdOrUrl) ?? videoIdOrUrl;
    final watchUrl = 'https://www.youtube.com/watch?v=$videoId';

    return await safeExecute<VideoMetadata?>(
      () async {
        final oembedUrl = Uri.parse(
          'https://www.youtube.com/oembed?url=$watchUrl&format=json',
        );

        final response = await _client.get(oembedUrl).timeout(
              const Duration(seconds: 10),
            );

        if (response.statusCode != 200) {
          return null;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;

        return VideoMetadata(
          videoId: videoId,
          title: data['title'] as String? ?? 'Unknown',
          thumbnailUrl: data['thumbnail_url'] as String?,
          channelName: data['author_name'] as String?,
          sourceUrl: watchUrl,
        );
      },
      operationName: 'Fetch YouTube video metadata',
    );
  }

  /// Fetch transcript for a YouTube video.
  ///
  /// Tries to get the best available transcript, preferring Swedish.
  Future<TranscriptResult> fetchTranscript(String videoIdOrUrl) async {
    final videoId = extractVideoId(videoIdOrUrl) ?? videoIdOrUrl;

    final result = await safeExecute(
      () async {
        final captionTracks = await _fetchCaptionTracks(videoId);

        if (captionTracks.isEmpty) {
          return TranscriptResult.failure(
              'No captions available for this video');
        }

        final selectedTrack = _selectBestTrack(captionTracks);
        final transcript = await _fetchTranscriptFromTrack(selectedTrack);

        if (transcript == null || transcript.isEmpty) {
          return TranscriptResult.failure('Failed to fetch transcript content');
        }

        return TranscriptResult.success(
          transcript: transcript,
          language: selectedTrack.languageCode,
          isAutoGenerated: selectedTrack.isAutoGenerated,
        );
      },
      operationName: 'Fetch YouTube transcript',
      defaultValue: TranscriptResult.failure('Error fetching transcript'),
    );

    return result ?? TranscriptResult.failure('Error fetching transcript');
  }

  /// Fetch caption tracks from the video page.
  Future<List<CaptionTrack>> _fetchCaptionTracks(String videoId) async {
    final watchUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    final response = await _client.get(
      watchUrl,
      headers: {
        'Accept-Language': HttpConstants.acceptLanguage,
        'User-Agent': HttpConstants.desktopUserAgent,
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      return [];
    }

    final html = response.body;

    // Find ytInitialPlayerResponse in the page
    final playerResponseMatch = RegExp(
      r'ytInitialPlayerResponse\s*=\s*(\{.+?\});',
      dotAll: true,
    ).firstMatch(html);

    if (playerResponseMatch == null) {
      // Try alternative pattern
      return _extractCaptionsFromAlternativePattern(html);
    }

    try {
      final jsonStr = playerResponseMatch.group(1)!;
      final playerResponse = json.decode(jsonStr) as Map<String, dynamic>;

      return _parseCaptionTracksFromPlayerResponse(playerResponse);
    } catch (e) {
      AppLogger.warning(
        'YouTubeTranscriptService: Failed to parse playerResponse JSON: $e',
      );
      return [];
    }
  }

  /// Parse caption tracks from ytInitialPlayerResponse JSON.
  List<CaptionTrack> _parseCaptionTracksFromPlayerResponse(
    Map<String, dynamic> playerResponse,
  ) {
    try {
      final captions = playerResponse['captions'] as Map<String, dynamic>?;
      if (captions == null) return [];

      final trackListRenderer =
          captions['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
      if (trackListRenderer == null) return [];

      final captionTracks =
          trackListRenderer['captionTracks'] as List<dynamic>?;
      if (captionTracks == null) return [];

      return captionTracks
          .map((track) {
            final trackMap = track as Map<String, dynamic>;
            final languageCode =
                trackMap['languageCode'] as String? ?? 'unknown';
            final name = trackMap['name'] as Map<String, dynamic>?;
            final simpleText = name?['simpleText'] as String? ?? languageCode;

            // Check if it's auto-generated
            final vssId = trackMap['vssId'] as String? ?? '';
            final isAuto = vssId.startsWith('a.');

            return CaptionTrack(
              baseUrl: trackMap['baseUrl'] as String? ?? '',
              languageCode: languageCode,
              languageName: simpleText,
              isAutoGenerated: isAuto,
            );
          })
          .where((track) => track.baseUrl.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.warning(
        'YouTubeTranscriptService: Failed to parse caption tracks: $e',
      );
      return [];
    }
  }

  /// Try to extract captions from alternative patterns in the page.
  List<CaptionTrack> _extractCaptionsFromAlternativePattern(String html) {
    // Look for timedtext URL patterns
    final timedtextPattern = RegExp(
      r'"(https://www\.youtube\.com/api/timedtext[^"]+)"',
    );

    final matches = timedtextPattern.allMatches(html);
    final tracks = <CaptionTrack>[];

    for (final match in matches) {
      var url = match.group(1)!;
      // Unescape the URL
      url = url.replaceAll(r'\u0026', '&');

      // Extract language from URL
      final langMatch = RegExp(r'lang=([a-z]{2})').firstMatch(url);
      final lang = langMatch?.group(1) ?? 'unknown';

      // Check if auto-generated
      final isAuto = url.contains('asr_langs') || url.contains('kind=asr');

      tracks.add(CaptionTrack(
        baseUrl: url,
        languageCode: lang,
        languageName: lang,
        isAutoGenerated: isAuto,
      ));
    }

    return tracks;
  }

  /// Select the best caption track based on language preference.
  CaptionTrack _selectBestTrack(List<CaptionTrack> tracks) {
    // First, try to find manual (non-auto) tracks in preferred languages
    for (final lang in _preferredLanguages) {
      final manual = tracks.where(
        (t) => t.languageCode == lang && !t.isAutoGenerated,
      );
      if (manual.isNotEmpty) return manual.first;
    }

    // Then, try auto-generated in preferred languages
    for (final lang in _preferredLanguages) {
      final auto = tracks.where(
        (t) => t.languageCode == lang && t.isAutoGenerated,
      );
      if (auto.isNotEmpty) return auto.first;
    }

    // Fall back to any manual track
    final anyManual = tracks.where((t) => !t.isAutoGenerated);
    if (anyManual.isNotEmpty) return anyManual.first;

    // Finally, return the first available
    return tracks.first;
  }

  /// Fetch and parse transcript content from a caption track.
  Future<String?> _fetchTranscriptFromTrack(CaptionTrack track) async {
    try {
      // Request JSON format for easier parsing
      var url = track.baseUrl;
      if (!url.contains('fmt=')) {
        url += '&fmt=json3';
      }

      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        // Try without fmt parameter
        return _fetchTranscriptAsXml(track.baseUrl);
      }

      try {
        return _parseJsonTranscript(response.body);
      } catch (e) {
        AppLogger.debug(
          'YouTubeTranscriptService: JSON transcript parse failed, trying XML: $e',
        );
        return _parseXmlTranscript(response.body);
      }
    } catch (e) {
      AppLogger.warning(
        'YouTubeTranscriptService: Failed to fetch transcript from track: $e',
      );
      return null;
    }
  }

  /// Fetch transcript in XML format.
  Future<String?> _fetchTranscriptAsXml(String baseUrl) async {
    try {
      final response = await _client.get(Uri.parse(baseUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) return null;

      return _parseXmlTranscript(response.body);
    } catch (e) {
      AppLogger.warning(
        'YouTubeTranscriptService: Failed to fetch XML transcript: $e',
      );
      return null;
    }
  }

  /// Parse JSON3 format transcript.
  String? _parseJsonTranscript(String jsonBody) {
    final data = json.decode(jsonBody) as Map<String, dynamic>;
    final events = data['events'] as List<dynamic>?;

    if (events == null) return null;

    final buffer = StringBuffer();

    for (final event in events) {
      final eventMap = event as Map<String, dynamic>;
      final segs = eventMap['segs'] as List<dynamic>?;

      if (segs != null) {
        for (final seg in segs) {
          final segMap = seg as Map<String, dynamic>;
          final text = segMap['utf8'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            buffer.write(text);
          }
        }
      }
    }

    final result = buffer.toString().trim();
    return result.isEmpty ? null : _cleanTranscript(result);
  }

  /// Parse XML format transcript.
  String? _parseXmlTranscript(String xmlBody) {
    // Simple XML parsing for transcript format
    // <transcript><text start="0" dur="5.5">Hello</text>...</transcript>
    final textPattern = RegExp(r'<text[^>]*>([^<]*)</text>');
    final matches = textPattern.allMatches(xmlBody);

    if (matches.isEmpty) return null;

    final buffer = StringBuffer();

    for (final match in matches) {
      var text = match.group(1) ?? '';
      // Decode HTML entities
      text = _decodeHtmlEntities(text);
      if (text.trim().isNotEmpty) {
        buffer.write(text);
        buffer.write(' ');
      }
    }

    final result = buffer.toString().trim();
    return result.isEmpty ? null : _cleanTranscript(result);
  }

  /// Decode common HTML entities.
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  /// Clean up transcript text.
  String _cleanTranscript(String text) {
    return text
        // BUT-1096: remove music/sound indicators FIRST so leftover spaces
        // get collapsed by the whitespace normalization below. Previous
        // order (normalize → strip) left double-spaces where markers used
        // to be.
        .replaceAll(RegExp(r'\[musik\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[music\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[applåder\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[applause\]', caseSensitive: false), '')
        // Normalize whitespace AFTER marker strip.
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Dispose resources. Only closes the HTTP client if we created it.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// Image formats recognized at the import / upload boundary.
///
/// `heic` was added with BUT-662 — extension is unreliable on iOS
/// (camera/share apps strip or rewrite it) so detection is purely
/// structural.
enum ImageFormat { jpeg, png, heic, webp, gif, unknown }

/// Magic-byte image format detection. Validates actual file content rather
/// than trusting file extensions, preventing disguised uploads and silent
/// MIME mismatches downstream.
class ImageFormatUtils {
  static const _jpegHeader = [0xFF, 0xD8, 0xFF];
  static const _pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const _gifHeader = [0x47, 0x49, 0x46, 0x38];
  // WebP: starts with RIFF....WEBP
  static const _riffHeader = [0x52, 0x49, 0x46, 0x46];
  static const _webpMarker = [0x57, 0x45, 0x42, 0x50];

  /// `'ftyp'` ISO BMFF box marker at byte offset 4. HEIC and other ISO
  /// BMFF derivatives all share this layout.
  static const _ftypMarker = [0x66, 0x74, 0x79, 0x70];

  /// HEIC `ftyp` box brand fourcc's at offset 8-11. Bytes 0-3 are the
  /// box length, bytes 4-7 are the literal `'ftyp'`.
  static const _heicBrands = <List<int>>[
    [0x68, 0x65, 0x69, 0x63], // 'heic'
    [0x68, 0x65, 0x69, 0x78], // 'heix'
    [0x68, 0x65, 0x76, 0x63], // 'hevc'
    [0x68, 0x65, 0x76, 0x78], // 'hevx'
    [0x6D, 0x69, 0x66, 0x31], // 'mif1' — most common iPhone brand
    [0x6D, 0x73, 0x66, 0x31], // 'msf1'
    [0x68, 0x65, 0x69, 0x73], // 'heis'
    [0x68, 0x65, 0x76, 0x73], // 'hevs'
  ];

  /// Structural format detection. Returns [ImageFormat.unknown] if no
  /// magic matches or bytes are too short.
  static ImageFormat detectFormat(List<int> headerBytes) {
    if (headerBytes.length < 4) return ImageFormat.unknown;

    if (_startsWith(headerBytes, _jpegHeader)) return ImageFormat.jpeg;
    if (_startsWith(headerBytes, _pngHeader)) return ImageFormat.png;
    if (_startsWith(headerBytes, _gifHeader)) return ImageFormat.gif;

    if (headerBytes.length >= 12 &&
        _startsWith(headerBytes, _riffHeader) &&
        _matchesAt(headerBytes, 8, _webpMarker)) {
      return ImageFormat.webp;
    }

    // ISO BMFF: 'ftyp' at offset 4, brand at offset 8.
    if (headerBytes.length >= 12 && _matchesAt(headerBytes, 4, _ftypMarker)) {
      for (final brand in _heicBrands) {
        if (_matchesAt(headerBytes, 8, brand)) return ImageFormat.heic;
      }
    }

    return ImageFormat.unknown;
  }

  /// Stable analytics wire name for an [ImageFormat]. Change with care —
  /// dashboard queries depend on these strings.
  static String wireName(ImageFormat format) {
    switch (format) {
      case ImageFormat.jpeg:
        return 'jpeg';
      case ImageFormat.png:
        return 'png';
      case ImageFormat.heic:
        return 'heic';
      case ImageFormat.webp:
        return 'webp';
      case ImageFormat.gif:
        return 'gif';
      case ImageFormat.unknown:
        return 'unknown';
    }
  }

  /// Detects MIME type from file header bytes.
  /// Returns null if format is not recognized.
  static String? detectMimeType(List<int> headerBytes) {
    final format = detectFormat(headerBytes);
    return _mimeOf(format);
  }

  /// Returns true if the header bytes match a supported image format.
  static bool isSupportedImage(List<int> headerBytes) {
    return detectMimeType(headerBytes) != null;
  }

  /// Detects MIME type from file header bytes, falling back to extension.
  static String detectMimeTypeWithFallback(List<int> data, String path) {
    final fromBytes = detectMimeType(data.take(12).toList());
    if (fromBytes != null) return fromBytes;
    return mimeTypeFromExtension(path);
  }

  /// Infers MIME type from file extension (fallback only).
  static String mimeTypeFromExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    // Default to JPEG for .jpg, .jpeg, or unknown
    return 'image/jpeg';
  }

  static String? _mimeOf(ImageFormat format) {
    switch (format) {
      case ImageFormat.jpeg:
        return 'image/jpeg';
      case ImageFormat.png:
        return 'image/png';
      case ImageFormat.gif:
        return 'image/gif';
      case ImageFormat.webp:
        return 'image/webp';
      case ImageFormat.heic:
        return 'image/heic';
      case ImageFormat.unknown:
        return null;
    }
  }

  static bool _startsWith(List<int> data, List<int> prefix) =>
      _matchesAt(data, 0, prefix);

  static bool _matchesAt(List<int> data, int offset, List<int> pattern) {
    if (data.length < offset + pattern.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (data[offset + i] != pattern[i]) return false;
    }
    return true;
  }
}

/// Magic-byte MIME type detection for uploaded images.
///
/// Validates actual file content rather than trusting file extensions,
/// preventing disguised file uploads.
class ImageFormatUtils {
  static const _jpegHeader = [0xFF, 0xD8, 0xFF];
  static const _pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const _gifHeader = [0x47, 0x49, 0x46, 0x38];
  // WebP: starts with RIFF....WEBP
  static const _riffHeader = [0x52, 0x49, 0x46, 0x46];
  static const _webpMarker = [0x57, 0x45, 0x42, 0x50];

  /// Detects MIME type from file header bytes.
  /// Returns null if format is not recognized.
  static String? detectMimeType(List<int> headerBytes) {
    if (headerBytes.length < 4) return null;

    if (_startsWith(headerBytes, _jpegHeader)) return 'image/jpeg';
    if (_startsWith(headerBytes, _pngHeader)) return 'image/png';
    if (_startsWith(headerBytes, _gifHeader)) return 'image/gif';

    // WebP: RIFF + 4 bytes size + WEBP
    if (headerBytes.length >= 12 &&
        _startsWith(headerBytes, _riffHeader) &&
        _matchesAt(headerBytes, 8, _webpMarker)) {
      return 'image/webp';
    }

    return null;
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
    // Default to JPEG for .jpg, .jpeg, or unknown
    return 'image/jpeg';
  }

  static bool _startsWith(List<int> data, List<int> prefix) {
    if (data.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }

  static bool _matchesAt(List<int> data, int offset, List<int> pattern) {
    if (data.length < offset + pattern.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (data[offset + i] != pattern[i]) return false;
    }
    return true;
  }
}

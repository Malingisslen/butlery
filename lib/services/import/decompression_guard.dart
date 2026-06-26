import 'package:archive/archive.dart';

/// Thrown when an archive entry exceeds the decompression-bomb size caps.
class DecompressionBombException implements Exception {
  const DecompressionBombException(this.message);

  final String message;

  @override
  String toString() => 'DecompressionBombException: $message';
}

/// Bounds how many decompressed bytes the import paths pull out of a
/// user-supplied archive, guarding `.xlsx` and `.paprikarecipes` imports
/// against decompression ("zip") bombs.
///
/// A crafted archive can declare tiny compressed entries that inflate to
/// hundreds of MB and OOM-kill the app — mobile is especially exposed (no swap;
/// iOS terminates around ~150 MB). [read] checks an entry's declared
/// uncompressed `size` from the central-directory header BEFORE materialising
/// `content`, so a naive bomb is rejected without ever being inflated, then
/// re-verifies the actual materialised length to catch a header that understates
/// the truth.
///
/// This bounds the bytes we *retain and process*. It does not bound the
/// transient allocation inside a single `GZipDecoder` inflate of one
/// already-capped entry; the airtight version would stream the inflate with a
/// running counter (tracked on BUT-1370).
class DecompressionGuard {
  DecompressionGuard({
    this.maxEntryBytes = defaultMaxEntryBytes,
    this.maxTotalBytes = defaultMaxTotalBytes,
  });

  /// Cap for a single decompressed entry (one worksheet/sharedStrings XML, or
  /// one gunzipped Paprika recipe). 20 MB is generous for recipe data and far
  /// under the mobile OOM threshold.
  static const int defaultMaxEntryBytes = 20 * 1024 * 1024;

  /// Ceiling on everything pulled out of one archive.
  static const int defaultMaxTotalBytes = 64 * 1024 * 1024;

  final int maxEntryBytes;
  final int maxTotalBytes;
  int _totalBytes = 0;

  /// Running total of decompressed bytes accepted so far.
  int get totalBytes => _totalBytes;

  /// Returns [file]'s decompressed content if within the caps; otherwise throws
  /// [DecompressionBombException]. The declared header size is checked first so
  /// a bomb is rejected before `content` inflates it.
  ///
  /// Set [count] to false for a transient entry whose bytes are immediately
  /// replaced by a further inflate (e.g. the outer `.gz` in a Paprika archive,
  /// which is gunzipped into the JSON we actually retain). Such an entry is
  /// still bounded by the per-entry cap, but not added to the running total —
  /// otherwise both the compressed layer and its inflation would be charged.
  List<int> read(ArchiveFile file, {bool count = true}) {
    _checkDeclared(file.name, file.size, count: count);
    // `ArchiveFile.content` is statically `List<int>` and is materialised
    // (decompressed) here — after the declared-size pre-check above, so a bomb
    // is rejected before this line ever inflates it.
    return _record(file.name, file.content, count: count);
  }

  /// Validates an already-decompressed [bytes] blob (e.g. the output of an inner
  /// gzip inflate) against the per-entry and running-total caps, then counts it.
  List<int> accept(String label, List<int> bytes) =>
      _record(label, bytes, count: true);

  List<int> _record(String label, List<int> bytes, {required bool count}) {
    if (bytes.length > maxEntryBytes) {
      throw DecompressionBombException(
        'entry "$label" inflated to ${bytes.length} bytes (cap $maxEntryBytes)',
      );
    }
    if (count) {
      _totalBytes += bytes.length;
      if (_totalBytes > maxTotalBytes) {
        throw DecompressionBombException(
          'archive total exceeded $maxTotalBytes bytes',
        );
      }
    }
    return bytes;
  }

  void _checkDeclared(String name, int declared, {required bool count}) {
    if (declared > maxEntryBytes) {
      throw DecompressionBombException(
        'entry "$name" declares $declared bytes (cap $maxEntryBytes)',
      );
    }
    // Pre-flight total check uses the declared size; the authoritative count
    // happens in [_record] on the actual bytes. The two can briefly diverge
    // (a lying-low header), so the total may be over-admitted by at most one
    // maxEntryBytes before [_record] throws — no content is returned past that.
    if (count && _totalBytes + declared > maxTotalBytes) {
      throw DecompressionBombException(
        'archive total would exceed $maxTotalBytes bytes',
      );
    }
  }
}

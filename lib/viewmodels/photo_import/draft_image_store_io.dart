import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:butlery/core/utils/logger.dart';

/// BUT-910: on-disk staging for the photo-import draft image (native only).
///
/// SharedPreferences cannot hold image bytes, so the draft persists only a
/// *path*; the bytes live here as a single gzipped temp file. One draft at a
/// time by design — every stage overwrites the previous file, and the OS may
/// purge the temp dir at will (a draft is a convenience, never a source of
/// truth). All operations are best-effort: failures log and degrade to a
/// text-only draft rather than breaking the import flow.
const String _draftFileName = 'photo_import_draft.img.gz';

/// Test seam: overrides the staging directory ([getTemporaryDirectory] needs
/// a platform channel that unit tests don't have).
Directory? debugDraftImageDirOverride;

Future<File> _draftFile() async {
  final dir = debugDraftImageDirOverride ?? await getTemporaryDirectory();
  return File('${dir.path}${Platform.pathSeparator}$_draftFileName');
}

/// Gzips [bytes] to the draft temp file and returns its path, or null on any
/// failure.
Future<String?> stageDraftImage(Uint8List bytes) async {
  try {
    final file = await _draftFile();
    await file.writeAsBytes(gzip.encode(bytes), flush: true);
    return file.path;
  } catch (e) {
    AppLogger.warning('DraftImageStore: failed to stage image ($e)');
    return null;
  }
}

/// Reads and gunzips the staged image at [path]. Null when the path is null,
/// the file is gone (OS-purged temp dir), or the content is corrupt.
Future<Uint8List?> readDraftImage(String? path) async {
  if (path == null) return null;
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return Uint8List.fromList(gzip.decode(await file.readAsBytes()));
  } catch (e) {
    AppLogger.warning('DraftImageStore: failed to read staged image ($e)');
    return null;
  }
}

/// Deletes the staged image at [path]. Best-effort.
Future<void> deleteDraftImage(String? path) async {
  if (path == null) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (e) {
    AppLogger.warning('DraftImageStore: failed to delete staged image ($e)');
  }
}

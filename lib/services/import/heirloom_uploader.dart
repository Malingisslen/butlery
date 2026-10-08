import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/services/permission_service.dart';

/// BUT-953 / BUT-2280: uploads an heirloom scan for the recipe being saved and
/// returns the [HeirloomMetadata] to store on it.
class HeirloomUploader extends BaseService {
  final StorageRepository _storage;
  final PermissionService _permission;

  HeirloomUploader({
    required StorageRepository storage,
    required PermissionService permission,
  }) : _storage = storage,
       _permission = permission;

  @override
  String get serviceName => 'HeirloomUploader';

  /// Returns null when the upload failed or nobody is signed in; the caller
  /// must then fail the save rather than store the recipe without its scan.
  Future<HeirloomMetadata?> upload(HeirloomDraft draft, String recipeId) {
    return executeServiceOperation(
      () => _upload(draft, recipeId),
      operationName: 'Upload heirloom scan',
      // Auth is checked in _upload against PermissionService, the uid source
      // the storage path is built from.
      requiresAuth: false,
    );
  }

  Future<HeirloomMetadata> _upload(HeirloomDraft draft, String recipeId) async {
    // Mirror BUT-1086: re-check auth AND uid together so a sign-out
    // mid-import surfaces as a failed save instead of a Storage rules deny.
    final userId = _permission.currentUserId;
    if (!_permission.isAuthenticated || userId == null) {
      throw StateError('Heirloom upload without a signed-in user');
    }

    final digest = sha256.convert(draft.imageBytes).toString().substring(0, 16);
    // BUT-1161: derive the extension from the real image bytes instead of
    // hardcoding .jpg — heirloom scans can be PNG/HEIC/WebP and a mismatched
    // suffix drives the wrong content-type fallback in the storage layer.
    final ext = ImageFormatUtils.extensionFromBytes(draft.imageBytes);
    final url = await _storage.uploadImageData(
      imageData: draft.imageBytes,
      userId: userId,
      path: 'users/$userId/recipes/$recipeId/heirloom/$digest.$ext',
      // Content-addressed → safe to cache for a year.
      cacheControl: 'public, max-age=31536000, immutable',
      metadata: {'purpose': 'heirloom', 'recipeId': recipeId},
    );
    if (url == null) {
      AppLogger.warning('Heirloom upload returned null URL for $recipeId');
      throw StateError('Heirloom upload returned no URL');
    }

    return HeirloomMetadata(
      sourceImageUrl: url,
      writerName: draft.writerName,
      year: draft.year,
      note: draft.note,
      addedAt: clock.now(),
      addedByUserId: userId,
    );
  }
}

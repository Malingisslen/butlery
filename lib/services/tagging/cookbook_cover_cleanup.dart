import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/storage_service.dart';

/// Removes a cookbook's own cover photo from Storage once the cookbook is
/// gone (BUT-2378). The photo is a file under the user's own folder that no
/// other document points at, so deleting it never takes anything else with it.
///
/// Best effort: a tag delete or merge has already succeeded when this runs,
/// and a file left behind is removed with the account, so a failure here is
/// logged and never reaches the caller.
///
/// [StorageService] lives in the Content module, which is configured after
/// Tagging, so it is resolved on first use.
class CookbookCoverCleanup {
  CookbookCoverCleanup({StorageService? storageService})
    : _storageOverride = storageService;

  final StorageService? _storageOverride;

  StorageService? get _storage =>
      _storageOverride ?? ServiceLocator.tryGet<StorageService>();

  /// The URL of [cookbook]'s own cover photo, or null for any other cover.
  static String? ownPhotoUrl(CookbookDetails? cookbook) {
    final cover = cookbook?.cover;
    if (cover == null || cover.kind != CookbookCoverKind.photo) return null;
    return cover.imageUrl;
  }

  /// [PersonalTag.cookbook] of each tag in [tags] whose id is in [ids].
  static List<CookbookDetails?> cookbooksOf(
    Iterable<PersonalTag> tags,
    Iterable<String> ids,
  ) {
    final wanted = ids.toSet();
    return [
      for (final tag in tags)
        if (wanted.contains(tag.id)) tag.cookbook,
    ];
  }

  Future<void> deleteOwnPhotos(Iterable<CookbookDetails?> cookbooks) async {
    final urls = {
      for (final cookbook in cookbooks) ?ownPhotoUrl(cookbook),
    };
    if (urls.isEmpty) return;
    final storage = _storage;
    if (storage == null) {
      AppLogger.warning('Cookbook cover left in Storage: no storage service');
      return;
    }
    for (final url in urls) {
      try {
        final deleted = await storage.deleteImage(url);
        if (!deleted) AppLogger.warning('Cookbook cover left in Storage');
      } catch (e) {
        AppLogger.warning('Cookbook cover left in Storage: $e');
      }
    }
  }
}

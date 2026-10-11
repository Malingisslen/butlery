import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/image_picker_provider.dart';
import 'package:butlery/services/tagging/cookbook_ordering.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The shelf and the open book (BUT-1325). Tags come from the live tag
/// stream and recipes from the library already in memory, so showing a
/// book costs no extra reads.
class CookbookViewModel extends BaseViewModel {
  CookbookViewModel({
    CookbookService? service,
    ImagePickerProvider? imagePicker,
  }) : _service = service ?? ServiceLocator.get<CookbookService>(),
       _picker = imagePicker ?? DefaultImagePickerProvider();

  final CookbookService _service;
  final ImagePickerProvider _picker;
  StreamSubscription<List<PersonalTag>>? _tagSub;
  StreamSubscription<void>? _librarySub;
  List<PersonalTag> _tags = const [];
  bool _started = false;
  bool _tagsLoaded = false;

  bool get tagsLoaded => _tagsLoaded;

  void start() {
    if (_started) return;
    _started = true;
    _tagSub = _service.watchTags().listen(
      (tags) {
        _tags = tags;
        _tagsLoaded = true;
        notifyListeners();
      },
      onError: (Object _) {
        _tagsLoaded = true;
        setError(AppLocale.current.cookbookLoadFailed);
      },
    );
    _librarySub = _service.libraryChanges.listen((_) => notifyListeners());
  }

  List<PersonalTag> get cookbooks =>
      _tags.where((t) => t.isCookbook).toList()..sort(_byShelfOrder);

  /// Tags the user can still turn into a cookbook.
  List<PersonalTag> get otherTags =>
      _tags.where((t) => !t.isCookbook).toList()..sort(_byShelfOrder);

  bool get hasAnyTags => _tags.isNotEmpty;

  PersonalTag? tagById(String id) {
    for (final t in _tags) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// A tag that is not a cookbook yet lists its recipes A–Ö, so the make
  /// sheet can offer their photos as a cover.
  List<Recipe> recipesIn(PersonalTag tag) => orderCookbookRecipes(
    tagId: tag.id,
    recipes: _service.libraryRecipes,
    cookbook: tag.cookbook ?? const CookbookDetails(),
  );

  int recipeCount(PersonalTag tag) => recipesIn(tag).length;

  /// Library recipes not yet in [tag], A–Ö, for "Lägg till recept".
  List<Recipe> recipesNotIn(PersonalTag tag) =>
      _service.libraryRecipes
          .where((r) => !(r.core.personalTagIds?.contains(tag.id) ?? false))
          .toList()
        ..sort(compareRecipeTitles);

  /// The photo a cover shows, or null to draw the colour. A recipe cover
  /// whose recipe left the book or has no photo falls back to the colour.
  String? coverImageUrl(PersonalTag tag) {
    final cover = tag.cookbook?.cover;
    if (cover == null) return null;
    switch (cover.kind) {
      case CookbookCoverKind.color:
        return null;
      case CookbookCoverKind.photo:
        return cover.imageUrl;
      case CookbookCoverKind.recipe:
        for (final r in recipesIn(tag)) {
          if (r.id == cover.recipeId) return recipePhoto(r);
        }
        return null;
    }
  }

  static String? recipePhoto(Recipe recipe) {
    final thumb = recipe.core.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) return thumb;
    final urls = recipe.core.imageUrls;
    return urls.isEmpty ? null : urls.first;
  }

  Future<bool> save(PersonalTag tag, CookbookDetails details) =>
      _write(() => _service.save(tag, details));

  Future<bool> remove(PersonalTag tag) => _write(() => _service.remove(tag));

  /// Lets the user pick a photo and uploads it. Null when they cancelled or
  /// the upload failed (then the error is set).
  Future<String?> pickAndUploadCoverPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: coverPhotoMaxSide,
      maxHeight: coverPhotoMaxSide,
      imageQuality: coverPhotoQuality,
    );
    if (file == null || isDisposed) return null;
    clearError();
    return _uploadCoverPhoto(await file.readAsBytes(), file.name);
  }

  static const double coverPhotoMaxSide = 1600;
  static const int coverPhotoQuality = 85;

  Future<String?> _uploadCoverPhoto(Uint8List bytes, String fileName) async {
    final url = await _service.uploadCoverPhoto(bytes, fileName);
    if (url == null && !isDisposed) {
      setError(AppLocale.current.cookbookCoverUploadFailed);
    }
    return url;
  }

  /// Moves the recipe at [index] one step by [delta] (-1 up, +1 down). The
  /// whole visible order is written, which also starts the book's own order
  /// and drops ids of recipes that have left the book.
  Future<bool> move(PersonalTag tag, int index, int delta) {
    final cookbook = tag.cookbook;
    if (cookbook == null) return Future.value(false);
    final ids = recipesIn(tag).map((r) => r.id).toList();
    final target = index + delta;
    if (index < 0 ||
        target < 0 ||
        index >= ids.length ||
        target >= ids.length) {
      return Future.value(false);
    }
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    if (ids.length > CookbookDetails.maxOrderedRecipes) {
      setError(AppLocale.current.cookbookTooManyRecipes);
      return Future.value(false);
    }
    return save(tag, cookbook.copyWith(recipeOrder: ids));
  }

  Future<bool> sortAlphabetically(PersonalTag tag) {
    final cookbook = tag.cookbook;
    if (cookbook == null) return Future.value(false);
    return save(tag, cookbook.copyWith(clearRecipeOrder: true));
  }

  /// An empty [text] removes the note.
  Future<bool> setNote(PersonalTag tag, String recipeId, String text) {
    final cookbook = tag.cookbook;
    if (cookbook == null) return Future.value(false);
    final notes = Map<String, String>.of(cookbook.recipeNotes);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      notes.remove(recipeId);
    } else {
      notes[recipeId] = trimmed;
    }
    return save(tag, cookbook.copyWith(recipeNotes: notes));
  }

  /// Returns how many recipes were added, or null on failure (the error is
  /// set for the screen).
  Future<int?> addRecipes(PersonalTag tag, List<Recipe> recipes) async {
    final current = recipesIn(tag).length;
    if (current + recipes.length > CookbookDetails.maxOrderedRecipes) {
      setError(AppLocale.current.cookbookTooManyRecipes);
      return null;
    }
    clearError();
    final added = await _service.addRecipes(tag, recipes);
    if (isDisposed) return added;
    if (added == null || added < recipes.length) {
      setError(AppLocale.current.cookbookAddRecipesFailed);
    }
    return added;
  }

  Future<bool> _write(Future<bool> Function() write) async {
    clearError();
    final ok = await write();
    if (!ok && !isDisposed) setError(AppLocale.current.cookbookSaveFailed);
    return ok;
  }

  static int _byShelfOrder(PersonalTag a, PersonalTag b) {
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    return bySort != 0 ? bySort : compareSwedish(a.name, b.name);
  }

  @override
  void dispose() {
    _tagSub?.cancel();
    _librarySub?.cancel();
    super.dispose();
  }
}

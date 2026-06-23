/// ViewModel for managing CookSnap gallery on a recipe detail view.
library;

import 'dart:async';

import 'package:image_picker/image_picker.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Provides cook snap state for a single recipe.
///
/// Created per-recipe via factory registration in DI.
class CookSnapViewModel extends BaseViewModel {
  final CookSnapService _service;
  final String _recipeId;
  final String _recipeAuthorId;
  final String _recipeName;

  List<CookSnap> _snaps = [];
  bool _isUploading = false;
  StreamSubscription<List<CookSnap>>? _subscription;

  CookSnapViewModel({
    required CookSnapService service,
    required String recipeId,
    required String recipeAuthorId,
    required String recipeName,
  }) : _service = service,
       _recipeId = recipeId,
       _recipeAuthorId = recipeAuthorId,
       _recipeName = recipeName {
    _startWatching();
  }

  List<CookSnap> get snaps => List.unmodifiable(_snaps);
  bool get isUploading => _isUploading;
  bool get hasSnaps => _snaps.isNotEmpty;
  int get snapCount => _snaps.length;

  void _startWatching() {
    setLoading(true);
    _subscription = _service
        .watchCookSnaps(_recipeId)
        .listen(
          (snapList) {
            _snaps = snapList;
            setLoading(false);
          },
          onError: (e) {
            AppLogger.error('CookSnap stream error: $e');
            setError(AppLocale.current.cookSnapErrorLoad);
          },
        );
  }

  Future<bool> addSnap({
    required ImageSource source,
    String? caption,
    CookSnapVisibility visibility = CookSnapVisibility.sameAsRecipe,
  }) async {
    if (_isUploading) return false;

    _isUploading = true;
    notifyListeners();

    try {
      final snap = await _service.addCookSnap(
        recipeId: _recipeId,
        recipeAuthorId: _recipeAuthorId,
        recipeName: _recipeName,
        source: source,
        caption: caption,
        visibility: visibility,
      );
      return snap != null;
    } catch (e) {
      AppLogger.error('Failed to add cook snap: $e');
      setError(AppLocale.current.cookSnapErrorUpload);
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSnap(String snapId) async {
    try {
      await _service.deleteCookSnap(snapId);
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete cook snap: $e');
      setError(AppLocale.current.cookSnapErrorDelete);
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

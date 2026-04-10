/// ViewModel for managing CookSnap gallery on a recipe detail view.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/services/cook_snap_service.dart';

/// Provides cook snap state for a single recipe.
///
/// Created per-recipe via factory registration in DI.
class CookSnapViewModel extends ChangeNotifier with StateNotifierMixin {
  final CookSnapService _service;
  final String _recipeId;
  final String _recipeAuthorId;
  final String _recipeName;

  List<CookSnap> _snaps = [];
  bool _isUploading = false;
  bool _isDisposed = false;
  StreamSubscription<List<CookSnap>>? _subscription;

  CookSnapViewModel({
    required CookSnapService service,
    required String recipeId,
    required String recipeAuthorId,
    required String recipeName,
  })  : _service = service,
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
    _subscription = _service.watchCookSnaps(_recipeId).listen(
      (snapList) {
        _snaps = snapList;
        setLoading(false);
        _safeNotify();
      },
      onError: (e) {
        AppLogger.error('CookSnap stream error: $e');
        setError('Could not load photos');
      },
    );
  }

  /// Picks and uploads a new cook snap photo.
  Future<bool> addSnap({
    required ImageSource source,
    String? caption,
  }) async {
    if (_isUploading) return false;

    _isUploading = true;
    _safeNotify();

    try {
      final snap = await _service.addCookSnap(
        recipeId: _recipeId,
        recipeAuthorId: _recipeAuthorId,
        recipeName: _recipeName,
        source: source,
        caption: caption,
      );
      return snap != null;
    } catch (e) {
      AppLogger.error('Failed to add cook snap: $e');
      setError('Could not upload photo');
      return false;
    } finally {
      _isUploading = false;
      _safeNotify();
    }
  }

  /// Deletes a cook snap.
  Future<bool> deleteSnap(String snapId) async {
    try {
      await _service.deleteCookSnap(snapId);
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete cook snap: $e');
      setError('Could not delete photo');
      return false;
    }
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

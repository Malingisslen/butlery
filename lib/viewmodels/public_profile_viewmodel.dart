/// ViewModel for the public profile view, loading a user's profile and public recipes.

import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';

class PublicProfileViewModel extends BaseViewModel {
  final String userId;

  UserProfile? _profile;
  static const int recipePageSize = 20;

  List<Recipe> _publicRecipes = [];
  bool _isSearchable = false;
  bool _hasMoreRecipes = false;
  bool _isLoadingMore = false;

  UserProfile? get profile => _profile;
  List<Recipe> get publicRecipes => _publicRecipes;
  bool get hasPublicRecipes => _publicRecipes.isNotEmpty;

  /// A full page came back, so there may be more behind "Visa fler".
  bool get hasMoreRecipes => _hasMoreRecipes;
  bool get isLoadingMore => _isLoadingMore;

  /// Whether the profile is findable in people-search: stored
  /// `isSearchable == true` and not hidden by moderation. A missing value, or
  /// a read that fails, counts as not searchable, so a non-friend gets no
  /// friend button (R8-7).
  bool get isSearchable => _isSearchable;

  PublicProfileViewModel({required this.userId}) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    await executeAsyncVoid(() async {
      final userRepo = ServiceLocator.get<UserRepository>();
      final fetchedProfile = await userRepo.fetchProfile(userId);

      if (fetchedProfile == null) {
        throw Exception(AppLocale.current.publicProfileError);
      }

      _profile = fetchedProfile;
      _isSearchable =
          !fetchedProfile.isHidden && await _readSearchable(userRepo);

      final recipeRepo = ServiceLocator.get<RecipeRepository>();
      _publicRecipes = await recipeRepo.fetchPublicUserRecipes(
        userId,
        limit: recipePageSize,
      );
      _hasMoreRecipes = _publicRecipes.length == recipePageSize;
    }, errorPrefix: AppLocale.current.publicProfileError);
  }

  Future<void> loadMoreRecipes() async {
    if (!_hasMoreRecipes || _isLoadingMore || _publicRecipes.isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await ServiceLocator.get<RecipeRepository>()
          .fetchPublicUserRecipes(
            userId,
            limit: recipePageSize,
            after: _publicRecipes.last,
          );
      _publicRecipes = [..._publicRecipes, ...page];
      _hasMoreRecipes = page.length == recipePageSize;
    } catch (e) {
      // The recipes already shown stay; "Visa fler" stays so it can be tried
      // again. An error here would replace the whole profile.
      AppLogger.warning(
        '[PublicProfile] loading more recipes failed: ${e.runtimeType}',
      );
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> _readSearchable(UserRepository userRepo) async {
    try {
      return await userRepo.fetchPersistedSearchable(userId);
    } catch (_) {
      return false;
    }
  }
}

/// ViewModel for the public profile view, loading a user's profile and public recipes.

import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class PublicProfileViewModel extends BaseViewModel {
  final String userId;

  UserProfile? _profile;
  List<Recipe> _publicRecipes = [];
  bool _isSearchable = false;

  UserProfile? get profile => _profile;
  List<Recipe> get publicRecipes => _publicRecipes;
  bool get hasPublicRecipes => _publicRecipes.isNotEmpty;

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
      _publicRecipes = await recipeRepo.fetchPublicUserRecipes(userId);
    }, errorPrefix: AppLocale.current.publicProfileError);
  }

  Future<bool> _readSearchable(UserRepository userRepo) async {
    try {
      return await userRepo.fetchPersistedSearchable(userId);
    } catch (_) {
      return false;
    }
  }
}

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

  UserProfile? get profile => _profile;
  List<Recipe> get publicRecipes => _publicRecipes;
  bool get hasPublicRecipes => _publicRecipes.isNotEmpty;

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

      final recipeRepo = ServiceLocator.get<RecipeRepository>();
      _publicRecipes = await recipeRepo.fetchPublicUserRecipes(userId);
    }, errorPrefix: AppLocale.current.publicProfileError);
  }
}

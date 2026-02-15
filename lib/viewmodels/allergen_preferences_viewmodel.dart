import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// ViewModel for managing user allergen and dietary preferences.
///
/// Controls which allergens and dietary restrictions are displayed
/// on recipe cards and detail views throughout the app.
class AllergenPreferencesViewModel extends BaseViewModel {
  final UserService _userService;

  late UserAllergenPreferences _preferences;
  bool _hasChanges = false;

  AllergenPreferencesViewModel({UserService? userService})
      : _userService = userService ?? ServiceLocator.get<UserService>() {
    _preferences = _userService.allergenPreferences;
  }

  // Getters
  UserAllergenPreferences get preferences => _preferences;
  bool get hasChanges => _hasChanges;
  Set<String> get trackedAllergens => _preferences.trackedAllergens;
  Set<String> get trackedDietary => _preferences.trackedDietary;
  bool get showOnCards => _preferences.showOnCards;
  bool get showOnDetail => _preferences.showOnDetail;
  bool get showCoverage => _preferences.showCoverage;

  /// Checks if an allergen is being tracked.
  bool isAllergenTracked(String key) =>
      _preferences.trackedAllergens.contains(key);

  /// Checks if a dietary preference is being tracked.
  bool isDietaryTracked(String key) =>
      _preferences.trackedDietary.contains(key);

  /// Toggles tracking for a specific allergen.
  void toggleAllergen(String key) {
    if (_preferences.trackedAllergens.contains(key)) {
      _preferences = _preferences.untrackAllergen(key);
    } else {
      _preferences = _preferences.trackAllergen(key);
    }
    _hasChanges = true;
    notifyListeners();
  }

  /// Toggles tracking for a specific dietary preference.
  void toggleDietary(String key) {
    if (_preferences.trackedDietary.contains(key)) {
      _preferences = _preferences.untrackDietary(key);
    } else {
      _preferences = _preferences.trackDietary(key);
    }
    _hasChanges = true;
    notifyListeners();
  }

  /// Updates the show on cards setting.
  void setShowOnCards(bool value) {
    _preferences = _preferences.copyWith(showOnCards: value);
    _hasChanges = true;
    notifyListeners();
  }

  /// Updates the show on detail setting.
  void setShowOnDetail(bool value) {
    _preferences = _preferences.copyWith(showOnDetail: value);
    _hasChanges = true;
    notifyListeners();
  }

  /// Updates the show coverage setting.
  void setShowCoverage(bool value) {
    _preferences = _preferences.copyWith(showCoverage: value);
    _hasChanges = true;
    notifyListeners();
  }

  /// Saves the current preferences to Firestore.
  Future<bool> save() async {
    return executeAsyncVoid(
      () async {
        final success =
            await _userService.updateAllergenPreferences(_preferences);
        if (success) {
          _hasChanges = false;
        } else {
          throw Exception(AppLocale.current
              .errorCouldNotUpdate(AppLocale.current.nounSettings));
        }
      },
      errorPrefix: AppLocale.current.errorCouldNotUpdateAllergenSettings,
    );
  }

  /// Resets preferences to defaults.
  void resetToDefaults() {
    _preferences = UserAllergenPreferences.defaults;
    _hasChanges = true;
    notifyListeners();
  }

  /// Discards changes and reloads from service.
  void discardChanges() {
    _preferences = _userService.allergenPreferences;
    _hasChanges = false;
    notifyListeners();
  }
}

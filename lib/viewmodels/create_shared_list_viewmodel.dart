// lib/viewmodels/create_shared_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

// BUT-520: migrated off raw ChangeNotifier onto BaseViewModel — loading/error
// state and disposed-guarded notifyListeners now come from the base. Operation-
// specific `isCreating` stays local (distinct UI semantics from generic
// isLoading). The old hand-rolled _setError/_clearError did NOT guard the
// disposed state, so a createSharedList() completing after dispose would notify
// a disposed VM; the base's guards fix that.
class CreateSharedListViewModel extends BaseViewModel {
  final UnifiedShoppingService _shoppingService;
  final UnifiedFriendsService _friendsService;

  // Form state
  String _title = '';
  String _description = '';
  List<String> _selectedFriendIds = [];
  Map<String, List<Recipe>>? _menu;

  // UI state — `isCreating` is operation-specific; `error`/loading come from BaseViewModel.
  bool _isCreating = false;

  CreateSharedListViewModel({
    UnifiedShoppingService? shoppingService,
    UnifiedFriendsService? friendsService,
  })  : _shoppingService =
            shoppingService ?? ServiceLocator.get<UnifiedShoppingService>(),
        _friendsService =
            friendsService ?? ServiceLocator.get<UnifiedFriendsService>();
  String get title => _title;
  String get description => _description;
  List<String> get selectedFriendIds => List.unmodifiable(_selectedFriendIds);
  Map<String, List<Recipe>>? get menu => _menu;

  bool get isCreating => _isCreating;
  bool get isTitleValid => _title.trim().isNotEmpty;
  bool get hasFriendsSelected => _selectedFriendIds.isNotEmpty;
  bool get canCreate => isTitleValid && hasFriendsSelected && !_isCreating;

  String? get titleError {
    if (_title.isEmpty) {
      return null; // Don't show error until user starts typing
    }
    if (_title.trim().isEmpty) {
      return AppLocale.current.errorTitleRequiredNotEmpty;
    }
    if (_title.length > 100) return AppLocale.current.errorDescriptionTooLong;
    return null;
  }

  String? get descriptionError {
    if (_description.length > 500) {
      return AppLocale.current.errorDescriptionTooLong;
    }
    return null;
  }

  String get selectedFriendsText {
    if (_selectedFriendIds.isEmpty) {
      return AppLocale.current.selectionNoFriendsSelected;
    }
    return AppLocale.current
        .selectionFriendsSelected(_selectedFriendIds.length);
  }

  String get trimmedTitle => _title.trim();
  String get trimmedDescription => _description.trim();

  bool get hasDescription => trimmedDescription.isNotEmpty;

  String get createButtonText => _isCreating
      ? AppLocale.current.buttonCreating
      : AppLocale.current.buttonCreateAndShare;
  void initialize({
    Map<String, List<Recipe>>? menu,
    String? defaultTitle,
  }) {
    _menu = menu;
    if (defaultTitle != null && defaultTitle.isNotEmpty) {
      _title = defaultTitle;
      notifyListeners();
    }

    AppLogger.info(
        '🔧 CreateSharedListViewModel initialiserad med menu: ${menu?.keys.join(", ")}');
  }

  void updateTitle(String value) {
    if (_title != value) {
      _title = value;
      clearError();
      notifyListeners();
      AppLogger.debug('📝 Titel uppdaterad: "$value"');
    }
  }

  void updateDescription(String value) {
    if (_description != value) {
      _description = value;
      clearError();
      notifyListeners();
      AppLogger.debug('📝 Beskrivning uppdaterad');
    }
  }

  void updateSelectedFriends(List<String> friendIds) {
    if (!listEquals(_selectedFriendIds, friendIds)) {
      _selectedFriendIds = List.from(friendIds);
      clearError();
      notifyListeners();
      AppLogger.info('👥 Vänner valda: ${friendIds.length}');
    }
  }

  void clearForm() {
    _title = '';
    _description = '';
    _selectedFriendIds.clear();
    clearError();
    notifyListeners();
    AppLogger.info('🗑️ Formulär rensat');
  }

  Future<String?> createSharedList() async {
    if (!canCreate) {
      setError(AppLocale.current.errorFormIncomplete);
      return null;
    }

    // Verify that the user has a profile
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
      setError(AppLocale.current.errorMustCreateProfileFirst);
      return null;
    }

    _setCreating(true);
    clearError();

    try {
      AppLogger.info(
          '🔄 Skapar delad lista: "$trimmedTitle" med ${_selectedFriendIds.length} vänner');

      // Create member display names map from friend IDs
      final memberDisplayNames = <String, String>{};
      for (final friendId in _selectedFriendIds) {
        // Get displayName from friends service
        final friend = _friendsService.friendsList
            .where((f) => f.uid == friendId)
            .firstOrNull;
        memberDisplayNames[friendId] = friend?.displayName ?? '?';
      }

      final listId = await _shoppingService.createCollaborativeList(
        name: trimmedTitle,
        description: hasDescription ? trimmedDescription : null,
        memberIds: _selectedFriendIds,
        memberDisplayNames: memberDisplayNames,
      );

      if (listId != null) {
        AppLogger.success('✅ Delad lista skapad: $listId');

        // Reset form after successful creation
        clearForm();

        return listId;
      } else {
        final serviceError =
            _shoppingService.error ?? AppLocale.current.errorUnknown;
        setError(serviceError);
        AppLogger.error('❌ Kunde inte skapa delad lista: $serviceError');
        return null;
      }
    } catch (e) {
      final errorMessage = AppLocale.current.createSharedListError('$e');
      setError(errorMessage);
      AppLogger.error('❌ Exception vid skapande av delad lista', e);
      return null;
    } finally {
      _setCreating(false);
    }
  }

  bool validateForm() {
    final titleValid = titleError == null && isTitleValid;
    final descriptionValid = descriptionError == null;
    final friendsValid = hasFriendsSelected;

    if (!titleValid) {
      setError(AppLocale.current.errorTitleRequiredNotEmpty);
      return false;
    }

    if (!descriptionValid) {
      setError(AppLocale.current.errorDescriptionTooLong);
      return false;
    }

    if (!friendsValid) {
      setError(AppLocale.current.errorSelectAtLeastOneFriend);
      return false;
    }

    return true;
  }

  void _setCreating(bool creating) {
    _isCreating = creating;
    notifyListeners();
  }

  Map<String, dynamic> get analyticsData => {
        'title_length': _title.length,
        'has_description': hasDescription,
        'selected_friends_count': _selectedFriendIds.length,
        'menu_days_count': _menu?.keys.length ?? 0,
      };
  @override
  void dispose() {
    AppLogger.info('🗑️ CreateSharedListViewModel disposed');
    super.dispose();
  }
}

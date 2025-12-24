// lib/viewmodels/create_shared_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

class CreateSharedListViewModel extends ChangeNotifier {
  final UnifiedShoppingService _shoppingService;
  final UnifiedFriendsService _friendsService;

  // Form state
  String _title = '';
  String _description = '';
  List<String> _selectedFriendIds = [];
  Map<String, List<Recipe>>? _menu;

  // UI state
  bool _isCreating = false;
  String? _error;

  CreateSharedListViewModel({
    UnifiedShoppingService? shoppingService,
    UnifiedFriendsService? friendsService,
  })  : _shoppingService =
            shoppingService ?? ServiceLocator.get<UnifiedShoppingService>(),
        _friendsService =
            friendsService ?? ServiceLocator.get<UnifiedFriendsService>();

  // ===== GETTERS (UI State) =====

  String get title => _title;
  String get description => _description;
  List<String> get selectedFriendIds => List.unmodifiable(_selectedFriendIds);
  Map<String, List<Recipe>>? get menu => _menu;

  bool get isCreating => _isCreating;
  String? get error => _error;
  bool get hasError => _error != null;

  // ===== VALIDATION GETTERS =====

  bool get isTitleValid => _title.trim().isNotEmpty;
  bool get hasFriendsSelected => _selectedFriendIds.isNotEmpty;
  bool get canCreate => isTitleValid && hasFriendsSelected && !_isCreating;

  String? get titleError {
    if (_title.isEmpty) {
      return null; // Don't show error until user starts typing
    }
    if (_title.trim().isEmpty) return 'Titel krävs';
    if (_title.length > 100) return 'Titel för lång (max 100 tecken)';
    return null;
  }

  String? get descriptionError {
    if (_description.length > 500) {
      return 'Beskrivning för lång (max 500 tecken)';
    }
    return null;
  }

  // ===== DISPLAY GETTERS =====

  String get selectedFriendsText {
    if (_selectedFriendIds.isEmpty) return 'Inga vänner valda';
    return '${_selectedFriendIds.length} ${_selectedFriendIds.length == 1 ? 'vän vald' : 'vänner valda'}';
  }

  String get trimmedTitle => _title.trim();
  String get trimmedDescription => _description.trim();

  bool get hasDescription => trimmedDescription.isNotEmpty;

  String get createButtonText => _isCreating ? 'Skapar...' : 'Skapa & Dela';

  // ===== INITIALIZATION =====

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

  // ===== FORM ACTIONS =====

  void updateTitle(String value) {
    if (_title != value) {
      _title = value;
      _clearError();
      notifyListeners();
      AppLogger.debug('📝 Titel uppdaterad: "$value"');
    }
  }

  void updateDescription(String value) {
    if (_description != value) {
      _description = value;
      _clearError();
      notifyListeners();
      AppLogger.debug('📝 Beskrivning uppdaterad');
    }
  }

  void updateSelectedFriends(List<String> friendIds) {
    if (!listEquals(_selectedFriendIds, friendIds)) {
      _selectedFriendIds = List.from(friendIds);
      _clearError();
      notifyListeners();
      AppLogger.info('👥 Vänner valda: ${friendIds.length}');
    }
  }

  void clearForm() {
    _title = '';
    _description = '';
    _selectedFriendIds.clear();
    _clearError();
    notifyListeners();
    AppLogger.info('🗑️ Formulär rensat');
  }

  // ===== BUSINESS ACTIONS =====

  Future<String?> createSharedList() async {
    if (!canCreate) {
      _setError('Formuläret är inte komplett');
      return null;
    }

    // Kontrollera att användaren har en profil
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
      _setError('Du måste skapa en profil först');
      return null;
    }

    _setCreating(true);
    _clearError();

    try {
      AppLogger.info(
          '🔄 Skapar delad lista: "$trimmedTitle" med ${_selectedFriendIds.length} vänner');

      // Skapa member display names map från friend IDs
      final memberDisplayNames = <String, String>{};
      for (final friendId in _selectedFriendIds) {
        // Hämta displayName från friends service
        final friend = _friendsService.friendsList
            .where((f) => f.uid == friendId)
            .firstOrNull;
        memberDisplayNames[friendId] = friend?.displayName ?? 'Okänd vän';
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
        final serviceError = _shoppingService.error ?? 'Okänt fel vid skapande';
        _setError(serviceError);
        AppLogger.error('❌ Kunde inte skapa delad lista: $serviceError');
        return null;
      }
    } catch (e) {
      final errorMessage = 'Fel vid skapande av delad lista: $e';
      _setError(errorMessage);
      AppLogger.error('❌ Exception vid skapande av delad lista', e);
      return null;
    } finally {
      _setCreating(false);
    }
  }

  // ===== VALIDATION METHODS =====

  bool validateForm() {
    final titleValid = titleError == null && isTitleValid;
    final descriptionValid = descriptionError == null;
    final friendsValid = hasFriendsSelected;

    if (!titleValid) {
      _setError('Titel krävs och får inte vara tom');
      return false;
    }

    if (!descriptionValid) {
      _setError('Beskrivning för lång');
      return false;
    }

    if (!friendsValid) {
      _setError('Du måste välja minst en vän att dela med');
      return false;
    }

    return true;
  }

  // ===== ERROR HANDLING =====

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void clearError() {
    _clearError();
  }

  // ===== LOADING STATE =====

  void _setCreating(bool creating) {
    _isCreating = creating;
    notifyListeners();
  }

  // ===== ANALYTICS HELPERS =====

  Map<String, dynamic> get analyticsData => {
        'title_length': _title.length,
        'has_description': hasDescription,
        'selected_friends_count': _selectedFriendIds.length,
        'menu_days_count': _menu?.keys.length ?? 0,
      };

  // ===== DISPOSE =====

  @override
  void dispose() {
    AppLogger.info('🗑️ CreateSharedListViewModel disposed');
    super.dispose();
  }
}

//lib/viewmodels/create_group_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/events/group_events.dart';


class CreateGroupViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;

  // Form state
  String _name = '';
  String _description = '';
  String _emoji = '👥';
  final Set<String> _selectedFriendIds = {};

  // UI state
  bool _isCreating = false;
  String? _error;
  String? _nameError;

  CreateGroupViewModel({
    UnifiedFriendsService? friendsService,
  })  : _friendsService = friendsService ?? sl<UnifiedFriendsService>();

  // Getters
  String get name => _name;
  String get description => _description;
  String get emoji => _emoji;
  Set<String> get selectedFriendIds => _selectedFriendIds;
  bool get isCreating => _isCreating;
  String? get error => _error;
  String? get nameError => _nameError;
  int get selectedFriendsCount => _selectedFriendIds.length;

  // Setters med validering
  void updateName(String value) {
    _name = value;
    _validateName();
    notifyListeners();
  }

  void updateDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void updateEmoji(String value) {
    _emoji = value;
    notifyListeners();
  }

  void toggleFriend(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    notifyListeners();
  }

  // Validering
  void _validateName() {
    if (_name.trim().isEmpty) {
      _nameError = 'Gruppnamn krävs';
    } else if (_friendsService.categories.getCategoryByName(_name.trim()) != null) {
      _nameError = 'Det här gruppnamnet finns redan';
    } else {
      _nameError = null;
    }
  }

  bool get isValid => _nameError == null && _name.trim().isNotEmpty;

  // Skapa grupp
  Future<bool> createGroup() async {
    if (!isValid) return false;

    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      // Steg 1: Skapa tom grupp
      debugPrint('🔍 DEBUG: Skapar tom grupp "${_name.trim()}"');

      final categoryId = await _friendsService.categories.createCategory(
        name: _name.trim(),
        description: _description.trim().isEmpty ? null : _description.trim(),
        icon: _emoji,
        initialMemberIds: null, // Tom grupp
      );

      if (categoryId == null) {
        throw Exception(_friendsService.error ?? 'Kunde inte skapa grupp');
      }

      // Steg 2: Hämta skapad grupp
      final createdGroup = _friendsService.categories.getAllCategories()
          .where((group) => group.id == categoryId)
          .firstOrNull;

      if (createdGroup == null) {
        throw Exception('Kunde inte hitta den skapade gruppen');
      }

      debugPrint('🔍 DEBUG: Grupp skapad med ID: ${createdGroup.id}');

      // Steg 3: Skicka inbjudningar
      int invitationsSent = 0;
      if (_selectedFriendIds.isNotEmpty) {
        debugPrint(
            '🔍 DEBUG: Skickar inbjudningar till ${_selectedFriendIds.length} vänner');

        final invitationResults = <String, bool>{};
        for (final friendId in _selectedFriendIds.toList()) {
          final friend = _friendsService.management.getFriendById(friendId);
          if (friend != null) {
            // Use actual email if available, otherwise skip invitation
            if (friend.email.isNotEmpty && friend.email.contains('@')) {
              final success = await _friendsService.invitations.sendEmailInvitation(
                email: friend.email,
                customMessage: 'Hej! Jag bjuder in dig till min nya grupp "${createdGroup.name}". Välkommen! 😊',
              );
              invitationResults[friendId] = success;
            } else {
              debugPrint('🔍 DEBUG: Cannot send invitation to ${friend.displayName}: No valid email available');
              invitationResults[friendId] = false;
            }
          } else {
            invitationResults[friendId] = false;
          }
        }

        invitationsSent =
            invitationResults.values.where((success) => success).length;
        debugPrint(
            '🔍 DEBUG: $invitationsSent av ${_selectedFriendIds.length} inbjudningar skickade');
        
        // Log invitation results for user feedback
        final failedInvitations = _selectedFriendIds.length - invitationsSent;
        if (failedInvitations > 0) {
          debugPrint('🔍 DEBUG: $failedInvitations invitations failed - email service not implemented');
        }
      }

      // Trigga event
      GroupEventBus.groupCreated();

      _isCreating = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('🔍 DEBUG: Fel vid gruppskapande: $e');
      _error = e.toString();
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }
}

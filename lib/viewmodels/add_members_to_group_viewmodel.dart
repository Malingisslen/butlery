/// ViewModel managing group member addition with friend search, selection, and invitation sending.

// lib/viewmodels/add_members_to_group_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/add_members_to_group/member_search_manager.dart';
import 'package:butlery/viewmodels/add_members_to_group/member_selection_manager.dart';

class AddMembersToGroupViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;

  late final MemberSearchManager _searchManager;
  late final MemberSelectionManager _selectionManager;

  final String groupId;
  FriendCategory? _group;

  List<UserProfile> _availableFriends = [];

  bool _isSendingInvitations = false;
  String? _invitationError;
  final Map<String, String> _invitationStatus = {};

  bool _isLoading = false;
  String? _error;

  AddMembersToGroupViewModel({
    required this.groupId,
    required UnifiedFriendsService friendsService,
  })  : _friendsService = friendsService {
    _searchManager = MemberSearchManager();
    _selectionManager = MemberSelectionManager(() => _searchManager.filteredFriends);

    _searchManager.addListener(_onManagerChanged);
    _selectionManager.addListener(_onManagerChanged);

    AppLogger.info(
        '🔄 Initialiserar AddMembersToGroupViewModel för grupp: $groupId');
    _initializeData();
  }

  void _onManagerChanged() {
    notifyListeners();
  }

  FriendCategory? get group => _group;
  String get groupName => _group?.name ?? 'Grupp';

  List<UserProfile> get availableFriends => List.unmodifiable(_availableFriends);
  int get availableFriendsCount => _availableFriends.length;

  // Search manager delegations
  List<UserProfile> get filteredFriends => _searchManager.filteredFriends;
  String get searchQuery => _searchManager.searchQuery;
  bool get hasSearchQuery => _searchManager.hasSearchQuery;

  // Selection manager delegations
  Set<String> get selectedFriendIds => _selectionManager.selectedFriendIds;
  List<UserProfile> get selectedFriends => _selectionManager.selectedFriends;
  int get selectedCount => _selectionManager.selectedCount;
  bool get hasSelectedFriends => _selectionManager.hasSelectedFriends;

  bool get isSendingInvitations => _isSendingInvitations;
  String? get invitationError => _invitationError;
  Map<String, String> get invitationStatus => Map.unmodifiable(_invitationStatus);

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  bool get canSendInvitations => hasSelectedFriends && !_isSendingInvitations;
  bool get showEmptyState => _searchManager.filteredFriends.isEmpty && !_isLoading;

  // ===== INITIALIZATION =====

  Future<void> _initializeData() async {
    try {
      _setLoading(true);
      _clearError();

      // Hämta gruppinformation
      _group = _friendsService.categories.getCategoryById(groupId);
      if (_group == null) {
        _setError('Gruppen hittades inte');
        return;
      }

      // Hämta tillgängliga vänner (som inte redan är medlemmar)
      await _loadAvailableFriends();

      AppLogger.success(
          '✅ AddMembersToGroupViewModel initialiserad för "${_group!.name}"');
    } catch (e) {
      AppLogger.error(
          '❌ Fel vid initialisering av AddMembersToGroupViewModel', e);
      _setError('Kunde inte ladda data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadAvailableFriends() async {
    if (_group == null) {
      return;
    }

    // Hämta alla vänner
    final allFriends = _friendsService.management.getAllFriends();

    // Filtrera bort befintliga gruppmedlemmar och grupp-ägaren
    final currentMemberIds = _group!.friendUserIds.toSet();
    final currentUserId = _friendsService.currentUserId; // ✅ FIXED: Filter out group owner

    _availableFriends = allFriends
        .where((friend) =>
            !currentMemberIds.contains(friend.uid) &&
            friend.uid != currentUserId) // ✅ FIXED: Prevent owner from inviting themselves
        .toList();

    // ✅ NYTT: Filtrera även bort de som redan har väntande inbjudningar
    _availableFriends = _availableFriends.where((friend) {
      // Kontrollera om det redan finns en väntande inbjudan
      final existingInvitation = _friendsService.invitations.getSentInvitations()
          .where((inv) =>
              inv.toUserId == friend.uid &&
              inv.status == GroupInvitationStatus.pending)
          .isNotEmpty;

      return !existingInvitation;
    }).toList();

    // Sortera alfabetiskt
    _availableFriends.sort((a, b) => a.displayName.compareTo(b.displayName));

    // Uppdatera filtrerad lista i search manager
    _searchManager.setAvailableFriends(_availableFriends);

    AppLogger.info(
        '👥 ${_availableFriends.length} tillgängliga vänner att bjuda in (efter filtrering av väntande inbjudningar)');
  }

  // Search operations - delegate to search manager
  void updateSearch(String query) => _searchManager.updateSearch(query);
  void clearSearch() => _searchManager.clearSearch();

  // Selection operations - delegate to selection manager
  void toggleFriendSelection(String friendId) => _selectionManager.toggleFriendSelection(friendId);
  bool isFriendSelected(String friendId) => _selectionManager.isFriendSelected(friendId);
  void selectAllVisible() => _selectionManager.selectAllVisible();
  void clearAllSelections() => _selectionManager.clearAllSelections();

  // ===== INVITATION ACTIONS =====

  /// ✅ UPPDATERAD: Skicka RIKTIGA gruppinbjudningar till valda vänner
  Future<bool> sendInvitations({String? personalMessage}) async {
    if (!canSendInvitations || _group == null) {
      AppLogger.warning(
          '⚠️ Kan inte skicka inbjudningar - villkor inte uppfyllda');
      return false;
    }

    try {
      _isSendingInvitations = true;
      _clearInvitationError();
      _invitationStatus.clear();
      notifyListeners();

      final selectedUserIds = _selectionManager.selectedFriendIds.toList();
      AppLogger.info(
          '📨 Skickar RIKTIGA gruppinbjudningar till ${selectedUserIds.length} vänner');

      // ✅ FIXED: Use proper group invitation method that saves to Firebase
      final results = <String, bool>{};
      for (final userId in selectedUserIds) {
        final success = await _friendsService.invitations.sendGroupInvitationToUser(
          userId: userId,
          groupId: groupId,
          customMessage: personalMessage,
        );
        results[userId] = success;
      }

      // Uppdatera status baserat på resultat
      int successCount = 0;
      int failureCount = 0;

      results.forEach((userId, success) {
        if (success) {
          _invitationStatus[userId] = 'sent';
          successCount++;
        } else {
          _invitationStatus[userId] = 'failed';
          failureCount++;
        }
      });

      // Rapportera resultat
      if (successCount > 0) {
        AppLogger.success(
            '✅ $successCount av ${selectedUserIds.length} gruppinbjudningar skickade');
      }

      if (failureCount > 0) {
        AppLogger.warning('⚠️ $failureCount gruppinbjudningar misslyckades');

        // Visa specifikt fel från UnifiedFriendsService om det finns
        if (_friendsService.hasError) {
          _setInvitationError(_friendsService.error!);
        } else if (successCount == 0 && failureCount > 0) {
          // All invitations failed
          _setInvitationError('Kunde inte skicka gruppinbjudningar. Försök igen senare.');
        }
      }

      // Rensa val efter framgångsrika inbjudningar
      if (successCount > 0) {
        _selectionManager.clearAllSelections();

        // ✅ NYTT: Ladda om tillgängliga vänner för att ta bort de som nu har väntande inbjudningar
        await _loadAvailableFriends();
      }

      return successCount > 0;
    } catch (e) {
      AppLogger.error('❌ Kritiskt fel vid sändning av gruppinbjudningar', e);
      _setInvitationError('Fel vid sändning av gruppinbjudningar: $e');
      return false;
    } finally {
      _isSendingInvitations = false;
      notifyListeners();
    }
  }

  // ===== UTILITY METHODS =====

  /// Hämta status för en specifik inbjudan
  String? getInvitationStatusForUser(String userId) {
    return _invitationStatus[userId];
  }

  /// Kontrollera om en användare har väntande inbjudan
  bool hasInvitationStatus(String userId) {
    return _invitationStatus.containsKey(userId);
  }

  /// ✅ NYTT: Kontrollera om en användare redan har väntande gruppinbjudan
  bool hasExistingInvitation(String userId) {
    final hasInvitation = _friendsService.invitations.getSentInvitations()
        .where((inv) => inv.toUserId == userId && inv.status == GroupInvitationStatus.pending)
        .isNotEmpty;
    return hasInvitation;
  }

  /// ✅ NYTT: Hämta information om skickade inbjudningar för denna grupp
  List<dynamic> getSentInvitationsForGroup() {
    final invitations = _friendsService.invitations.getSentInvitations()
        .where((inv) => inv.groupId == groupId)
        .toList();
    return invitations;
  }

  /// Refresh data
  Future<void> refresh() async {
    AppLogger.info('🔄 Refreshar AddMembersToGroupViewModel data');

    // ✅ NYTT: Refresha även UnifiedFriendsService
    await _friendsService.refresh();

    await _initializeData();
  }

  // ===== PRIVATE HELPERS =====

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void _setInvitationError(String message) {
    _invitationError = message;
    notifyListeners();
  }

  void _clearInvitationError() {
    _invitationError = null;
  }

  /// Rensa fel
  void clearError() {
    _clearError();
    _clearInvitationError();
    notifyListeners();
  }

  @override
  void dispose() {
    _searchManager.removeListener(_onManagerChanged);
    _selectionManager.removeListener(_onManagerChanged);
    _searchManager.dispose();
    _selectionManager.dispose();
    AppLogger.info('🗑️ Disposing AddMembersToGroupViewModel');
    super.dispose();
  }
}

// lib/viewmodels/group_invitations_viewmodel.dart - UPPDATERAD med GroupInvitationService

import 'package:flutter/foundation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/error_handler.dart';


class GroupInvitationsViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;

  // ===== STATE =====
  List<FriendCategory> _availableGroups = [];
  final Map<String, List<UserProfile>> _groupMembers = {};
  final Set<String> _joiningGroupIds = {};
  List<GroupInvitation> _receivedInvitations = [];
  final Set<String> _respondingInvitationIds = {};

  // ===== GENERAL STATE =====
  bool _isLoading = false;
  String? _error;

  GroupInvitationsViewModel({
    required UnifiedFriendsService friendsService,
  })  : _friendsService = friendsService {
    _initializeData();
  }

  // ===== GETTERS =====

  /// ===== BEFINTLIGA GETTERS (för tillgängliga grupper) =====

  /// Tillgängliga grupper som användaren kan gå med i
  List<FriendCategory> get availableGroups =>
      List.unmodifiable(_availableGroups);

  /// Hämta medlemmar för en specifik grupp
  List<UserProfile> getMembersForGroup(String groupId) {
    return _groupMembers[groupId] ?? [];
  }

  /// Kontrollera om en specifik grupp håller på att joinas
  bool isJoiningGroup(String groupId) => _joiningGroupIds.contains(groupId);

  /// ===== NYA GETTERS (för gruppinbjudningar) =====

  /// Mottagna gruppinbjudningar (väntande)
  List<GroupInvitation> get receivedInvitations => List.unmodifiable(
      _receivedInvitations.where((inv) => inv.status == GroupInvitationStatus.pending).toList());

  /// Alla mottagna inbjudningar (inklusive avslutade)
  List<GroupInvitation> get allReceivedInvitations =>
      List.unmodifiable(_receivedInvitations);

  /// Antal väntande inbjudningar (för badge/notification)
  int get pendingInvitationsCount => receivedInvitations.length;

  /// Kontrollera om en specifik inbjudan håller på att besvaras
  bool isRespondingToInvitation(String invitationId) =>
      _respondingInvitationIds.contains(invitationId);

  /// ===== GENERAL GETTERS =====

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error state
  String? get error => _error;
  bool get hasError => _error != null;

  /// Aktuell användare
  String? get _currentUserId => ServiceLocator.get<PermissionService>().currentUserId;

  /// Kombinerat "har något att visa" state
  bool get hasContent =>
      availableGroups.isNotEmpty || receivedInvitations.isNotEmpty;

  // ===== INITIALIZATION =====

  Future<void> _initializeData() async {
    await Future.wait([
      _loadAvailableGroups(),
      _loadReceivedInvitations(),
    ]);
  }

  /// ===== BEFINTLIG LOGIK (för tillgängliga grupper) =====

  Future<void> _loadAvailableGroups() async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🔄 Laddar tillgängliga grupper för användare...');

      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        throw Exception('Ingen användare inloggad');
      }

      // Hämta alla grupper
      final allGroups = _friendsService.categories.getAllCategories();

      // Filtrera bort grupper där användaren redan är medlem eller admin
      _availableGroups = allGroups.where((group) {
        // Hoppa över grupper där användaren redan är medlem
        if (group.friendUserIds.contains(currentUserId)) {
          return false;
        }

        // Hoppa över grupper som användaren äger
        if (group.createdBy == currentUserId) {
          return false;
        }

        return true;
      }).toList();

      AppLogger.info(
        '📋 ${_availableGroups.length} tillgängliga grupper att gå med i',
      );

      // Ladda medlemmar för varje grupp
      await _loadMembersForGroups();
    } catch (e) {
      final failure = ErrorHandler().handleError(error: e, context: 'groupInvitationsOperation');
      AppLogger.error('❌ Kunde inte ladda tillgängliga grupper', e);
      _setError(failure.userMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadMembersForGroups() async {
    for (final group in _availableGroups) {
      try {
        // Hämta vänprofiler för gruppmedlemmar
        final allFriends = _friendsService.management.getAllFriends();
        final groupMembers = allFriends
            .where((friend) => group.friendUserIds.contains(friend.uid))
            .toList();

        _groupMembers[group.id] = groupMembers;

        AppLogger.info(
          '👥 ${groupMembers.length} medlemmar laddade för grupp "${group.name}"',
        );
      } catch (e) {
        AppLogger.warning(
          '⚠️ Kunde inte ladda medlemmar för grupp "${group.name}": $e',
        );
        _groupMembers[group.id] = [];
      }
    }
  }

  /// ===== NY LOGIK (för gruppinbjudningar) =====

  Future<void> _loadReceivedInvitations() async {
    try {
      AppLogger.info('🔄 Laddar mottagna gruppinbjudningar...');

      // Hämta inbjudningar från UnifiedFriendsService
      _receivedInvitations = _friendsService.invitations.getSentInvitations();


      AppLogger.info(
        '📨 ${_receivedInvitations.length} mottagna inbjudningar (${receivedInvitations.length} väntande)',
      );
    } catch (e) {
      AppLogger.error('❌ Kunde inte ladda mottagna inbjudningar', e);
      // Inte kritiskt fel - fortsätt med tomma inbjudningar
      _receivedInvitations = [];
    }
  }

  // ===== BEFINTLIGA ACTIONS (för tillgängliga grupper) =====

  /// Gå med i en grupp (befintlig funktionalitet)
  Future<void> joinGroup(String groupId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      _setError('Ingen användare inloggad');
      return;
    }

    if (_joiningGroupIds.contains(groupId)) {
      AppLogger.warning('⚠️ Redan håller på att gå med i grupp $groupId');
      return;
    }

    try {
      _joiningGroupIds.add(groupId);
      _clearError();
      notifyListeners();

      final group = _availableGroups.firstWhere(
        (g) => g.id == groupId,
        orElse: () => throw Exception('Gruppen hittades inte'),
      );

      AppLogger.info('🔄 Går med i grupp "${group.name}"...');

      // Använd UnifiedFriendsService för att lägga till användaren som medlem
      final success = await _friendsService.categories.assignFriendToCategory(
        currentUserId,
        groupId,
      );

      if (success) {
        AppLogger.success('✅ Gick med i grupp "${group.name}" framgångsrikt!');

        // Ta bort gruppen från tillgängliga grupper
        _availableGroups.removeWhere((g) => g.id == groupId);
        _groupMembers.remove(groupId);

        // Logga analytics event
        _logJoinGroupEvent(group);
      } else {
        final errorMessage =
            _friendsService.error ?? 'Kunde inte gå med i gruppen';
        throw Exception(errorMessage);
      }
    } catch (e) {
      final failure = ErrorHandler().handleError(error: e, context: 'groupInvitationsOperation');
      AppLogger.error('❌ Fel vid gruppmedlemskap', e);
      _setError(failure.userMessage);
    } finally {
      _joiningGroupIds.remove(groupId);
      notifyListeners();
    }
  }

  /// ===== NYA ACTIONS (för gruppinbjudningar) =====

  /// Acceptera gruppinbjudan
  Future<void> acceptInvitation(String invitationId) async {
    if (_respondingInvitationIds.contains(invitationId)) {
      AppLogger.warning(
          '⚠️ Redan håller på att besvara inbjudan $invitationId');
      return;
    }

    try {
      _respondingInvitationIds.add(invitationId);
      _clearError();
      notifyListeners();

      final invitation = _receivedInvitations.firstWhere(
        (inv) => inv.id == invitationId,
        orElse: () => throw Exception('Inbjudan hittades inte'),
      );

      AppLogger.info(
          '🔄 Accepterar inbjudan från "${invitation.fromUserName}"...');

      // Använd UnifiedFriendsService för att acceptera
      final success =
          await _friendsService.invitations.markInvitationAsViewed(invitationId);

      if (success) {
        AppLogger.success(
            '✅ Inbjudan accepterad från "${invitation.fromUserName}"');

        // Uppdatera lokal state - ta bort från väntande inbjudningar
        await _loadReceivedInvitations();

        // Uppdatera tillgängliga grupper (ta bort gruppen eftersom vi nu är medlemmar)
        await _loadAvailableGroups();

        // Logga analytics event
        _logAcceptInvitationEvent(invitation);
      } else {
        final errorMessage =
            _friendsService.error ?? 'Kunde inte acceptera inbjudan';
        throw Exception(errorMessage);
      }
    } catch (e) {
      final failure = ErrorHandler().handleError(error: e, context: 'groupInvitationsOperation');
      AppLogger.error('❌ Fel vid acceptans av inbjudan', e);
      _setError(failure.userMessage);
    } finally {
      _respondingInvitationIds.remove(invitationId);
      notifyListeners();
    }
  }

  /// Avvisa gruppinbjudan
  Future<void> rejectInvitation(String invitationId) async {
    if (_respondingInvitationIds.contains(invitationId)) {
      AppLogger.warning(
          '⚠️ Redan håller på att besvara inbjudan $invitationId');
      return;
    }

    try {
      _respondingInvitationIds.add(invitationId);
      _clearError();
      notifyListeners();

      final invitation = _receivedInvitations.firstWhere(
        (inv) => inv.id == invitationId,
        orElse: () => throw Exception('Inbjudan hittades inte'),
      );

      AppLogger.info(
          '🔄 Avvisar inbjudan från "${invitation.fromUserName}"...');

      // Använd UnifiedFriendsService för att avvisa
      final success =
          await _friendsService.invitations.cancelInvitation(invitationId);

      if (success) {
        AppLogger.info('❌ Inbjudan avvisad från "${invitation.fromUserName}"');

        // Uppdatera lokal state
        await _loadReceivedInvitations();

        // Logga analytics event
        _logRejectInvitationEvent(invitation);
      } else {
        final errorMessage =
            _friendsService.error ?? 'Kunde inte avvisa inbjudan';
        throw Exception(errorMessage);
      }
    } catch (e) {
      final failure = ErrorHandler().handleError(error: e, context: 'groupInvitationsOperation');
      AppLogger.error('❌ Fel vid avvisning av inbjudan', e);
      _setError(failure.userMessage);
    } finally {
      _respondingInvitationIds.remove(invitationId);
      notifyListeners();
    }
  }

  // ===== REFRESH & UTILITY METHODS =====

  /// Uppdatera data
  Future<void> refresh() async {
    AppLogger.info('🔄 Refreshar gruppinbjudningsdata...');

    try {
      // Refresha underliggande services först
      // UnifiedFriendsService hanterar refresh internt

      // Ladda om båda typerna av data
      await _initializeData();

      AppLogger.success('✅ Gruppinbjudningsdata refreshad');
    } catch (e) {
      AppLogger.error('❌ Fel vid refresh av gruppinbjudningsdata', e);
      // Visa inte fel här - användaren ser redan data från cache
    }
  }

  /// Hämta gruppstatistik (befintlig + ny data)
  Map<String, dynamic> getGroupStats() {
    return {
      'availableGroups': _availableGroups.length,
      'pendingInvitations': receivedInvitations.length,
      'totalInvitations': _receivedInvitations.length,
      'totalMembers':
          _groupMembers.values.expand((members) => members).toSet().length,
      'averageMembersPerGroup': _availableGroups.isEmpty
          ? 0
          : _availableGroups.map((g) => g.friendCount).reduce((a, b) => a + b) /
              _availableGroups.length,
    };
  }

  /// Kontrollera om en grupp är tillgänglig för medlemskap
  bool isGroupAvailable(String groupId) {
    return _availableGroups.any((group) => group.id == groupId);
  }

  /// Få gruppobjekt baserat på ID
  FriendCategory? getGroupById(String groupId) {
    try {
      return _availableGroups.firstWhere((group) => group.id == groupId);
    } catch (e) {
      return null;
    }
  }

  // ===== HELPER METHODS =====

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

  /// Rensa fel (public metod för UI)
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Logga analytics för gruppmedlemskap (befintlig)
  void _logJoinGroupEvent(FriendCategory group) {
    try {
      AppLogger.info(
        '📊 Analytics: Användare gick med i grupp "${group.name}" (${group.friendCount} medlemmar)',
      );
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte logga join group event: $e');
    }
  }

  /// ✅ NYTT: Logga analytics för accepterad inbjudan
  void _logAcceptInvitationEvent(GroupInvitation invitation) {
    try {
      AppLogger.info(
        '📊 Analytics: Användare accepterade inbjudan från ${invitation.fromUserName}',
      );
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte logga accept invitation event: $e');
    }
  }

  /// ✅ NYTT: Logga analytics för avvisad inbjudan
  void _logRejectInvitationEvent(GroupInvitation invitation) {
    try {
      AppLogger.info(
        '📊 Analytics: Användare avvisade inbjudan från ${invitation.fromUserName}',
      );
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte logga reject invitation event: $e');
    }
  }

  @override
  void dispose() {
    AppLogger.info('🗑️ GroupInvitationsViewModel disposed');
    super.dispose();
  }
}

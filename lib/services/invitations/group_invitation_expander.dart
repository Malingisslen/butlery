// lib/services/invitations/group_invitation_expander.dart

import '../../models/invitations/invitation_target.dart';
import '../../models/user_profile.dart';
import '../friend_categories_service.dart';
import '../friends_service.dart';
import '../../core/utils/logger.dart';


/// Resultat av gruppexpansion
class GroupExpansionResult {
  /// Alla individuella targets efter expansion
  final List<InvitationTarget> expandedTargets;

  /// Antal ursprungliga grupper som expanderades
  final int groupsExpanded;

  /// Antal individuella targets som redan fanns
  final int individualTargetsPreserved;

  /// Totalt antal användare efter expansion
  final int totalUsers;

  /// Grupper som var tomma eller misslyckades expandera
  final List<String> failedGroupIds;

  /// Varningar eller problem under expansionen
  final List<String> warnings;

  GroupExpansionResult({
    required this.expandedTargets,
    required this.groupsExpanded,
    required this.individualTargetsPreserved,
    required this.totalUsers,
    this.failedGroupIds = const [],
    this.warnings = const [],
  });

  /// Sammanfattning för logging
  String get summary =>
      'Expanderat $groupsExpanded grupper + $individualTargetsPreserved individer = $totalUsers användare totalt';

  /// Har expansion problem?
  bool get hasIssues => failedGroupIds.isNotEmpty || warnings.isNotEmpty;
}

/// GroupInvitationExpander - SINGLE RESPONSIBILITY: Gruppexpansion
///
/// Denna service hanterar BARA:
/// - Expansion av InvitationTarget grupper till individuella användare
/// - Deduplicering av användare från överlappande grupper
/// - Validering att användare fortfarande är vänner
/// - Robust felhantering för tomma/ogiltiga grupper
///
/// Den hanterar INTE:
/// - Skicka faktiska inbjudningar (det gör InvitationService)
/// - UI logic eller presentation
/// - Permission management
/// - Användargränssnitt för gruppval
class GroupInvitationExpander {
  final FriendCategoriesService _categoriesService;
  final FriendsService _friendsService;

  GroupInvitationExpander({
    required FriendCategoriesService categoriesService,
    required FriendsService friendsService,
  })  : _categoriesService = categoriesService,
        _friendsService = friendsService;

  // ===== CORE EXPANSION METHODS =====

  /// Expandera lista av InvitationTargets - grupper blir individuella användare
  ///
  /// Tar en blandad lista av individuella användare och grupper,
  /// returnerar bara individuella användare med alla grupper expanderade
  Future<GroupExpansionResult> expandTargets(
    List<InvitationTarget> targets,
  ) async {
    AppLogger.info('🔄 Expanderar ${targets.length} invitation targets...');

    try {
      final expandedTargets = <InvitationTarget>[];
      final processedUserIds = <String>{};
      final failedGroupIds = <String>[];
      final warnings = <String>[];
      int groupsExpanded = 0;
      int individualTargetsPreserved = 0;

      // Hämta alla vänner en gång för performance
      final allFriends = _friendsService.friends;
      final friendsMap = <String, UserProfile>{};
      for (final friend in allFriends) {
        friendsMap[friend.uid] = friend;
      }

      for (final target in targets) {
        if (target.isIndividual) {
          // Individuell användare - lägg till direkt om valid
          await _processIndividualTarget(
            target,
            friendsMap,
            processedUserIds,
            expandedTargets,
            warnings,
          );
          individualTargetsPreserved++;
        } else {
          // Grupp - expandera till medlemmar
          final groupResult = await _processGroupTarget(
            target,
            friendsMap,
            processedUserIds,
            expandedTargets,
            warnings,
          );

          if (groupResult.success) {
            groupsExpanded++;
          } else {
            failedGroupIds.add(target.targetId);
          }
        }
      }

      final result = GroupExpansionResult(
        expandedTargets: expandedTargets,
        groupsExpanded: groupsExpanded,
        individualTargetsPreserved: individualTargetsPreserved,
        totalUsers: expandedTargets.length,
        failedGroupIds: failedGroupIds,
        warnings: warnings,
      );

      AppLogger.success('✅ ${result.summary}');

      if (result.hasIssues) {
        AppLogger.warning('⚠️ Expansion hade problem: ${warnings.join(', ')}');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Fel vid gruppexpansion', e);

      // Return minimal result vid fel
      return GroupExpansionResult(
        expandedTargets: targets.where((t) => t.isIndividual).toList(),
        groupsExpanded: 0,
        individualTargetsPreserved: targets.where((t) => t.isIndividual).length,
        totalUsers: targets.where((t) => t.isIndividual).length,
        failedGroupIds:
            targets.where((t) => t.isGroup).map((t) => t.targetId).toList(),
        warnings: ['Fel vid gruppexpansion: $e'],
      );
    }
  }

  /// Expandera endast en specifik grupp
  ///
  /// Utility-metod för att expandera bara en grupp till dess medlemmar
  Future<List<InvitationTarget>> expandSingleGroup(
    String groupId,
  ) async {
    AppLogger.info('🔄 Expanderar grupp: $groupId');

    try {
      final category = _categoriesService.getCategoryById(groupId);
      if (category == null) {
        AppLogger.warning('⚠️ Grupp hittades inte: $groupId');
        return [];
      }

      final allFriends = _friendsService.friends;
      final friendsMap = <String, UserProfile>{};
      for (final friend in allFriends) {
        friendsMap[friend.uid] = friend;
      }

      final memberTargets = <InvitationTarget>[];

      for (final memberId in category.friendUserIds) {
        final friend = friendsMap[memberId];
        if (friend != null) {
          memberTargets.add(InvitationTarget.individual(friend));
        } else {
          AppLogger.warning('⚠️ Gruppmedlem inte längre vän: $memberId');
        }
      }

      AppLogger.success(
          '✅ Grupp ${category.name} expanderad till ${memberTargets.length} medlemmar');
      return memberTargets;
    } catch (e) {
      AppLogger.error('❌ Fel vid expansion av grupp $groupId', e);
      return [];
    }
  }

  // ===== VALIDATION METHODS =====

  /// Kontrollera om en grupp är giltig för delning
  Future<bool> isGroupValidForSharing(String groupId) async {
    try {
      final category = _categoriesService.getCategoryById(groupId);
      if (category == null) return false;

      // Grupp måste ha minst en medlem
      if (category.friendUserIds.isEmpty) return false;

      // Kontrollera att minst en medlem fortfarande är vän
      final allFriends = _friendsService.friends;
      final friendIds = allFriends.map((f) => f.uid).toSet();

      return category.friendUserIds
          .any((memberId) => friendIds.contains(memberId));
    } catch (e) {
      AppLogger.error('Fel vid validering av grupp $groupId', e);
      return false;
    }
  }

  /// Få antal giltiga medlemmar i grupp
  Future<int> getValidMemberCount(String groupId) async {
    try {
      final expandedTargets = await expandSingleGroup(groupId);
      return expandedTargets.length;
    } catch (e) {
      AppLogger.error('Fel vid räkning av gruppmedlemmar $groupId', e);
      return 0;
    }
  }

  /// Kontrollera för dubbletter mellan targets
  List<String> findDuplicateUsers(List<InvitationTarget> targets) {
    final userIds = <String>[];
    final duplicates = <String>[];

    for (final target in targets) {
      if (target.isIndividual) {
        if (userIds.contains(target.targetId)) {
          duplicates.add(target.targetId);
        } else {
          userIds.add(target.targetId);
        }
      } else {
        // För grupper, lägg till alla medlems-IDs
        for (final memberId in target.memberIds ?? []) {
          if (userIds.contains(memberId)) {
            duplicates.add(memberId);
          } else {
            userIds.add(memberId);
          }
        }
      }
    }

    return duplicates;
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Processera individuell target
  Future<void> _processIndividualTarget(
    InvitationTarget target,
    Map<String, UserProfile> friendsMap,
    Set<String> processedUserIds,
    List<InvitationTarget> expandedTargets,
    List<String> warnings,
  ) async {
    final userId = target.targetId;

    // Undvik dubbletter
    if (processedUserIds.contains(userId)) {
      warnings.add('Användare $userId redan vald');
      return;
    }

    // Kontrollera att användaren fortfarande är vän
    final friend = friendsMap[userId];
    if (friend == null) {
      warnings.add('Användare ${target.displayName} är inte längre vän');
      return;
    }

    expandedTargets.add(target);
    processedUserIds.add(userId);
  }

  /// Processera grupp target med result tracking
  Future<_GroupProcessResult> _processGroupTarget(
    InvitationTarget target,
    Map<String, UserProfile> friendsMap,
    Set<String> processedUserIds,
    List<InvitationTarget> expandedTargets,
    List<String> warnings,
  ) async {
    final groupId = target.targetId;

    try {
      final category = _categoriesService.getCategoryById(groupId);
      if (category == null) {
        warnings.add('Grupp ${target.displayName} hittades inte');
        return _GroupProcessResult(success: false);
      }

      if (category.friendUserIds.isEmpty) {
        warnings.add('Grupp ${target.displayName} är tom');
        return _GroupProcessResult(success: false);
      }

      int addedMembers = 0;

      for (final memberId in category.friendUserIds) {
        // Undvik dubbletter
        if (processedUserIds.contains(memberId)) {
          continue;
        }

        final friend = friendsMap[memberId];
        if (friend != null) {
          expandedTargets.add(InvitationTarget.individual(friend));
          processedUserIds.add(memberId);
          addedMembers++;
        } else {
          warnings.add('Gruppmedlem inte längre vän: $memberId');
        }
      }

      if (addedMembers == 0) {
        warnings.add('Inga giltiga medlemmar i grupp ${target.displayName}');
        return _GroupProcessResult(success: false);
      }

      return _GroupProcessResult(success: true, membersAdded: addedMembers);
    } catch (e) {
      warnings.add('Fel vid expansion av grupp ${target.displayName}: $e');
      return _GroupProcessResult(success: false);
    }
  }

  // ===== UTILITY METHODS =====

  /// Få sammanfattning av vad som kommer att delas
  Future<String> getExpansionPreview(List<InvitationTarget> targets) async {
    try {
      final result = await expandTargets(targets);

      final individual = targets.where((t) => t.isIndividual).length;
      final groups = targets.where((t) => t.isGroup).length;

      String preview = 'Delar med $individual användare';

      if (groups > 0) {
        preview += ' + $groups ${groups == 1 ? 'grupp' : 'grupper'} ';
        preview += '(totalt ${result.totalUsers} användare)';
      }

      if (result.hasIssues) {
        preview += ' ⚠️';
      }

      return preview;
    } catch (e) {
      return 'Fel vid förhandsvisning';
    }
  }

  /// Få detaljerad förklaring av expansion
  Future<List<String>> getExpansionDetails(
      List<InvitationTarget> targets) async {
    try {
      final details = <String>[];

      for (final target in targets) {
        if (target.isIndividual) {
          details.add('👤 ${target.displayName}');
        } else {
          final validMembers = await getValidMemberCount(target.targetId);
          details.add('👥 ${target.displayName} ($validMembers medlemmar)');
        }
      }

      return details;
    } catch (e) {
      return ['Fel vid detaljvisning'];
    }
  }
}

/// Intern hjälpklass för gruppprocessering
class _GroupProcessResult {
  final bool success;
  final int membersAdded;

  _GroupProcessResult({
    required this.success,
    this.membersAdded = 0,
  });
}

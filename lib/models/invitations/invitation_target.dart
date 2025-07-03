// lib/models/invitations/invitation_target.dart

import '../user_profile.dart';
import '../friend_category.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Invitation Target Model - Stödjer både individuell och gruppdelning
/// File: models/invitations/invitation_target.dart
/// Quick Guide: Ren datamodell för inbjudningsmål - BARA data och business logic
/// Dependencies IN: UserProfile, FriendCategory
/// Dependencies OUT: InvitationService, TargetDisplayWidgets (UI konsumerar denna data)
/// Data flow: UI target selection → InvitationTarget → Firebase invitation → Individual users
/// State management: Immutable data class med factory constructors
/// Purpose: Enhetlig representation av både individuella och grupp-mål för inbjudningar
/// Common issues: Säkerställ att gruppmedlemmar expanderas korrekt
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Efficient serialization, minimal overhead
/// Analytics: N/A - data model
/// Code smells: ✅ Single responsibility - bara data representation
/// Connected to: InvitationService, TargetDisplayWidgets
/// Used in phases: Fas 1 (Grundinfrastruktur) - Gruppstöd foundation

/// Typ av inbjudningsmål
enum InvitationTargetType {
  /// Individuell användare
  individual,

  /// Grupp av användare (FriendCategory)
  group,
}

/// Representerar vem som ska få en inbjudan - antingen en person eller en grupp
///
/// Denna klass är en ren datamodell och innehåller BARA:
/// - Data representation
/// - Business logic getters
/// - Serialization methods
/// - Utility methods för data manipulation
///
/// ❌ INNEHÅLLER INTE: UI widgets, styling, theme methods
class InvitationTarget {
  /// Typ av mål (person eller grupp)
  final InvitationTargetType type;

  /// ID för målet (userId för person, groupId för grupp)
  final String targetId;

  /// Visningsnamn för UI
  final String displayName;

  /// Avatarbild-URL (för personer) eller emoji (för grupper)
  final String? imageOrEmoji;

  /// Medlemsantal (bara för grupper)
  final int? memberCount;

  /// Lista över medlems-IDs (bara för grupper, för expansion)
  final List<String>? memberIds;

  /// Extra metadata för UI
  final Map<String, dynamic>? metadata;

  const InvitationTarget({
    required this.type,
    required this.targetId,
    required this.displayName,
    this.imageOrEmoji,
    this.memberCount,
    this.memberIds,
    this.metadata,
  });

  // ===== FACTORY CONSTRUCTORS =====

  /// Skapa target för individuell användare
  factory InvitationTarget.individual(UserProfile user) {
    return InvitationTarget(
      type: InvitationTargetType.individual,
      targetId: user.uid,
      displayName: user.displayName,
      imageOrEmoji: user.avatarUrl,
      memberCount: null,
      memberIds: null,
      metadata: {
        'bio': user.bio,
        'isSearchable': user.isSearchable,
        'friendsCount': user.friendsCount,
        'memberSince': user.memberSinceText,
      },
    );
  }

  /// Skapa target för grupp
  factory InvitationTarget.group(
    FriendCategory group,
    List<UserProfile> members,
  ) {
    return InvitationTarget(
      type: InvitationTargetType.group,
      targetId: group.id,
      displayName: group.name,
      imageOrEmoji: group.emoji ?? '👥',
      memberCount: members.length,
      memberIds: members.map((m) => m.uid).toList(),
      metadata: {
        'description': group.description,
        'createdAt': group.createdAt.toIso8601String(),
        'ownerId': group.ownerId,
      },
    );
  }

  // ===== BUSINESS LOGIC GETTERS =====

  /// Är detta en individuell användare?
  bool get isIndividual => type == InvitationTargetType.individual;

  /// Är detta en grupp?
  bool get isGroup => type == InvitationTargetType.group;

  /// Få emoji för UI (grupper har emoji, personer får default)
  String get displayEmoji {
    if (isGroup) {
      return imageOrEmoji ?? '👥';
    } else {
      return '👤'; // Default person emoji
    }
  }

  /// Få beskrivning för UI
  String get description {
    if (isGroup) {
      final count = memberCount ?? 0;
      return '$count medlem${count != 1 ? 'mar' : ''}';
    } else {
      return metadata?['bio'] as String? ?? '';
    }
  }

  /// Få subtitle för ListTile
  String get subtitle {
    if (isGroup) {
      return description;
    } else {
      final bio = metadata?['bio'] as String?;
      return bio?.isNotEmpty == true ? bio! : 'Butlery-användare';
    }
  }

  /// Kontrollera om target är giltigt
  bool get isValid {
    if (targetId.isEmpty || displayName.isEmpty) return false;

    if (isGroup) {
      // Grupper måste ha medlemmar
      return memberIds?.isNotEmpty == true;
    }

    return true;
  }

  /// Få lista över alla användar-IDs som denna target representerar
  List<String> get allUserIds {
    if (isIndividual) {
      return [targetId];
    } else {
      return memberIds ?? [];
    }
  }

  /// Få bio-text från metadata (för personer)
  String get bioText {
    return metadata?['bio'] as String? ?? '';
  }

  /// Få skapandedatum (för grupper)
  DateTime? get createdAt {
    final dateString = metadata?['createdAt'] as String?;
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  /// Få ägare-ID (för grupper)
  String? get ownerId {
    return metadata?['ownerId'] as String?;
  }

  /// Få vänantal (för personer)
  int get friendsCount {
    return metadata?['friendsCount'] as int? ?? 0;
  }

  /// Är användaren sökbar (för personer)
  bool get isSearchable {
    return metadata?['isSearchable'] as bool? ?? true;
  }

  // ===== SERIALIZATION =====

  /// Konvertera till Firestore-format
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'targetId': targetId,
      'displayName': displayName,
      'imageOrEmoji': imageOrEmoji,
      'memberCount': memberCount,
      'memberIds': memberIds,
      'metadata': metadata,
    };
  }

  /// Skapa från Firestore-dokument
  factory InvitationTarget.fromFirestore(Map<String, dynamic> data) {
    return InvitationTarget(
      type: InvitationTargetType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => InvitationTargetType.individual,
      ),
      targetId: data['targetId'] as String,
      displayName: data['displayName'] as String,
      imageOrEmoji: data['imageOrEmoji'] as String?,
      memberCount: data['memberCount'] as int?,
      memberIds: data['memberIds'] != null
          ? List<String>.from(data['memberIds'])
          : null,
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  /// JSON serialization för caching
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'targetId': targetId,
      'displayName': displayName,
      'imageOrEmoji': imageOrEmoji,
      'memberCount': memberCount,
      'memberIds': memberIds,
      'metadata': metadata,
    };
  }

  /// Skapa från JSON (för caching)
  factory InvitationTarget.fromJson(Map<String, dynamic> json) {
    return InvitationTarget(
      type: InvitationTargetType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => InvitationTargetType.individual,
      ),
      targetId: json['targetId'] as String,
      displayName: json['displayName'] as String,
      imageOrEmoji: json['imageOrEmoji'] as String?,
      memberCount: json['memberCount'] as int?,
      memberIds: json['memberIds'] != null
          ? List<String>.from(json['memberIds'])
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  // ===== UTILITY METHODS =====

  /// Skapa kopia med uppdaterade värden
  InvitationTarget copyWith({
    InvitationTargetType? type,
    String? targetId,
    String? displayName,
    String? imageOrEmoji,
    int? memberCount,
    List<String>? memberIds,
    Map<String, dynamic>? metadata,
  }) {
    return InvitationTarget(
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      displayName: displayName ?? this.displayName,
      imageOrEmoji: imageOrEmoji ?? this.imageOrEmoji,
      memberCount: memberCount ?? this.memberCount,
      memberIds: memberIds ?? this.memberIds,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Uppdatera metadata
  InvitationTarget withMetadata(Map<String, dynamic> newMetadata) {
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? {});
    updatedMetadata.addAll(newMetadata);

    return copyWith(metadata: updatedMetadata);
  }

  /// Ta bort specifik metadata-nyckel
  InvitationTarget withoutMetadata(String key) {
    if (metadata == null || !metadata!.containsKey(key)) {
      return this;
    }

    final updatedMetadata = Map<String, dynamic>.from(metadata!);
    updatedMetadata.remove(key);

    return copyWith(metadata: updatedMetadata);
  }

  // ===== EQUALITY & COMPARISON =====

  /// Jämför med annan target
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvitationTarget &&
        other.type == type &&
        other.targetId == targetId;
  }

  @override
  int get hashCode => Object.hash(type, targetId);

  @override
  String toString() {
    return 'InvitationTarget('
        'type: $type, '
        'targetId: $targetId, '
        'displayName: $displayName, '
        'memberCount: $memberCount'
        ')';
  }

  /// Jämför targets för sortering (grupper först, sedan alfabetiskt)
  int compareTo(InvitationTarget other) {
    // Grupper först
    if (isGroup && !other.isGroup) return -1;
    if (!isGroup && other.isGroup) return 1;

    // Alfabetisk sortering inom samma typ
    return displayName.compareTo(other.displayName);
  }

  // ===== STATIC UTILITY METHODS =====

  /// Konvertera lista av UserProfile till lista av InvitationTarget
  static List<InvitationTarget> fromUsers(List<UserProfile> users) {
    return users.map(InvitationTarget.individual).toList();
  }

  /// Konvertera lista av FriendCategory till lista av InvitationTarget
  static List<InvitationTarget> fromGroups(
    List<FriendCategory> groups,
    Map<String, List<UserProfile>> groupMembersMap,
  ) {
    return groups.map((group) {
      final members = groupMembersMap[group.id] ?? [];
      return InvitationTarget.group(group, members);
    }).toList();
  }

  /// Filtrera ut alla individuella användar-IDs från en lista av targets
  static Set<String> extractAllUserIds(List<InvitationTarget> targets) {
    final userIds = <String>{};

    for (final target in targets) {
      userIds.addAll(target.allUserIds);
    }

    return userIds;
  }

  /// Gruppera targets efter typ
  static Map<InvitationTargetType, List<InvitationTarget>> groupByType(
    List<InvitationTarget> targets,
  ) {
    final grouped = <InvitationTargetType, List<InvitationTarget>>{};

    for (final target in targets) {
      grouped.putIfAbsent(target.type, () => []).add(target);
    }

    return grouped;
  }

  /// Sortera targets för UI (grupper först, sedan alfabetiskt)
  static List<InvitationTarget> sortForUI(List<InvitationTarget> targets) {
    final sorted = List<InvitationTarget>.from(targets);
    sorted.sort((a, b) => a.compareTo(b));
    return sorted;
  }

  /// Filtrera targets baserat på söktext
  static List<InvitationTarget> filterBySearch(
    List<InvitationTarget> targets,
    String searchText,
  ) {
    if (searchText.isEmpty) return targets;

    final query = searchText.toLowerCase();

    return targets.where((target) {
      // Sök i namn
      if (target.displayName.toLowerCase().contains(query)) {
        return true;
      }

      // Sök i beskrivning/bio
      if (target.description.toLowerCase().contains(query)) {
        return true;
      }

      // För grupper: sök i beskrivning från metadata
      if (target.isGroup) {
        final description = target.metadata?['description'] as String? ?? '';
        if (description.toLowerCase().contains(query)) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  /// Filtrera targets efter typ
  static List<InvitationTarget> filterByType(
    List<InvitationTarget> targets,
    InvitationTargetType type,
  ) {
    return targets.where((target) => target.type == type).toList();
  }

  /// Få endast individuella targets
  static List<InvitationTarget> individualsOnly(
      List<InvitationTarget> targets) {
    return filterByType(targets, InvitationTargetType.individual);
  }

  /// Få endast grupp-targets
  static List<InvitationTarget> groupsOnly(List<InvitationTarget> targets) {
    return filterByType(targets, InvitationTargetType.group);
  }

  /// Räkna totalt antal användare i alla targets
  static int getTotalUserCount(List<InvitationTarget> targets) {
    return extractAllUserIds(targets).length;
  }

  /// Kontrollera om en userId finns i någon av targets
  static bool containsUser(List<InvitationTarget> targets, String userId) {
    return extractAllUserIds(targets).contains(userId);
  }
}

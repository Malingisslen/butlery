import 'dart:convert';

/// BUT-1203: the persistence contract for the group-creation draft, extracted
/// from `CreateGroupDialog` so the all-fields-empty → remove-key rule and the
/// JSON shape are unit-testable independently of the dialog's widget tree.
///
/// Used by the dialog's `AutoSaveManager<Map<String, dynamic>>` (encode/decode)
/// — the manager owns persistence; this owns the shape + emptiness semantics.
const String kGroupDraftDefaultEmoji = '👥';

/// Builds the persisted draft map from the current form fields. Centralises the
/// key names so the encoder, the decoder's call sites, and any test agree.
Map<String, dynamic> buildGroupDraft({
  required String name,
  required String description,
  required String emoji,
  required List<String> friendIds,
}) =>
    <String, dynamic>{
      'name': name,
      'description': description,
      'emoji': emoji,
      'friendIds': friendIds,
    };

/// Encodes a draft to its persisted string, or `null` when the form is in its
/// initial-empty state. Returning null makes [AutoSaveManager] remove the key,
/// so an opened-then-abandoned form leaves no useless empty blob behind.
String? encodeGroupDraft(Map<String, dynamic> draft) {
  final name = (draft['name'] as String?) ?? '';
  final description = (draft['description'] as String?) ?? '';
  final emoji = (draft['emoji'] as String?) ?? kGroupDraftDefaultEmoji;
  final friendIds = (draft['friendIds'] as List?) ?? const [];
  final isEmpty = name.isEmpty &&
      description.isEmpty &&
      emoji == kGroupDraftDefaultEmoji &&
      friendIds.isEmpty;
  return isEmpty ? null : jsonEncode(draft);
}

/// Decodes a persisted draft string back into the field map. Mirrors
/// [encodeGroupDraft]; a corrupt blob throws and is swallowed by the manager.
Map<String, dynamic> decodeGroupDraft(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

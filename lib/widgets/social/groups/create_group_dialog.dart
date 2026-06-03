// lib/widgets/social/groups/create_group_dialog.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/dialogs/dialog_form_fields.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';
import 'package:butlery/widgets/common/social_components.dart';

/// Dialog for creating a new group
/// Enhanced consolidation using DialogFormFields, eliminating 40+ lines of duplicate
/// form field patterns, validation logic, and styling inconsistencies.
class CreateGroupDialog extends StatefulWidget {
  final List<UserProfile>? preSelectedMembers;

  const CreateGroupDialog({super.key, this.preSelectedMembers});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  /// BUT-919: single multi-field JSON-encoded draft. Group-creation is
  /// one-at-a-time per session, no per-id multi-instance concern.
  static const String _draftPrefsKey = 'group_creation_draft_v1';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedEmoji = '👥';
  final Set<String> _selectedFriendIds = <String>{};
  List<UserProfile> _selectedFriends = <UserProfile>[];
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedMembers != null) {
      // Caller-provided pre-selection wins over any saved draft.
      _selectedFriends = List.from(widget.preSelectedMembers!);
      _selectedFriendIds
          .addAll(widget.preSelectedMembers!.map((member) => member.uid));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft());
    }
    _nameController.addListener(_saveDraft);
    _descriptionController.addListener(_saveDraft);
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftPrefsKey);
      if (raw == null || raw.isEmpty || !mounted) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedName = (json['name'] as String?).orEmpty();
      final savedDesc = (json['description'] as String?).orEmpty();
      final savedEmoji = json['emoji'] as String? ?? _selectedEmoji;
      final savedFriendIds =
          (json['friendIds'] as List?)?.whereType<String>().toList() ??
              const <String>[];

      // Resolve saved friend IDs back to UserProfile via the cached
      // friends list. IDs that don't resolve (e.g. unfriended since draft
      // was saved) are silently dropped — they'd just be inviting
      // strangers if we kept them.
      List<UserProfile> resolvedFriends = const [];
      try {
        final friendsService = ServiceLocator.get<UnifiedFriendsService>();
        final all = friendsService.friendsList;
        resolvedFriends =
            all.where((f) => savedFriendIds.contains(f.uid)).toList();
      } catch (e) {
        AppLogger.warning('CreateGroupDialog: friend resolve failed ($e)');
      }

      setState(() {
        _nameController.text = savedName;
        _descriptionController.text = savedDesc;
        _selectedEmoji = savedEmoji;
        _selectedFriends = resolvedFriends;
        _selectedFriendIds
          ..clear()
          ..addAll(resolvedFriends.map((f) => f.uid));
      });
    } catch (e) {
      AppLogger.warning('CreateGroupDialog: failed to load draft ($e)');
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'name': _nameController.text,
        'description': _descriptionController.text,
        'emoji': _selectedEmoji,
        'friendIds': _selectedFriendIds.toList(),
      };
      // Skip writing when the entire form is in its initial-empty state —
      // avoids leaving a useless empty JSON blob behind after dispose.
      final isEmpty = _nameController.text.isEmpty &&
          _descriptionController.text.isEmpty &&
          _selectedEmoji == '👥' &&
          _selectedFriendIds.isEmpty;
      if (isEmpty) {
        await prefs.remove(_draftPrefsKey);
      } else {
        await prefs.setString(_draftPrefsKey, jsonEncode(payload));
      }
    } catch (e) {
      AppLogger.warning('CreateGroupDialog: failed to save draft ($e)');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefsKey);
    } catch (e) {
      AppLogger.warning('CreateGroupDialog: failed to clear draft ($e)');
    }
  }

  void _onFriendSelectionChanged(List<UserProfile> selectedFriends) {
    if (mounted) {
      setState(() {
        _selectedFriends = selectedFriends;
        _selectedFriendIds.clear();
        _selectedFriendIds.addAll(selectedFriends.map((f) => f.uid));
      });
      _saveDraft();
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_saveDraft);
    _descriptionController.removeListener(_saveDraft);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (mounted) {
      setState(() {
        _isCreating = true;
        _error = null;
      });
    }

    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();

      final categoryId = await friendsService.categories.createCategory(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        icon: _selectedEmoji,
        initialMemberIds: _selectedFriendIds.toList(),
      );

      if (categoryId != null) {
        // Get the created category to return it
        final createdCategory =
            friendsService.categories.getCategoryById(categoryId);

        // BUT-919: user explicitly committed — drop the saved draft so
        // next "create group" opens blank.
        await _clearDraft();

        if (mounted) {
          Navigator.of(context).pop(createdCategory);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = context.l10n.errorCouldNotCreate(
                context.l10n.socialGroupName.toLowerCase());
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = context.l10n.errorWithContext(
              context.l10n.statusCreating.toLowerCase(), e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
            maxWidth: AppDimensions.dialogMaxWidthMedium,
            maxHeight: AppDimensions.dialogMaxHeightMedium),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              DialogHeader(
                title: context.l10n.groupCreateNew,
                icon: Icons.group_add,
                onClose: () => Navigator.of(context).pop(),
              ),

              // Content - Make scrollable to handle overflow
              // ✅ FIX: Use Flexible instead of Expanded to avoid layout conflicts
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji selection
                      EmojiSelector(
                        selectedEmoji: _selectedEmoji,
                        onEmojiSelected: (emoji) {
                          if (mounted) {
                            setState(() {
                              _selectedEmoji = emoji;
                            });
                            _saveDraft();
                          }
                        },
                      ),

                      const SizedBox(height: AppDimensions.spacingL),

                      // ✅ CONSOLIDATED: Group name using standardized form field
                      DialogFormFields.buildNameField(
                        context: context,
                        controller: _nameController,
                        labelText: context.l10n.socialGroupName,
                        hintText: context.l10n.groupNameHint,
                        prefixIcon: Icons.group,
                        maxLength: 50,
                      ),

                      // ✅ CONSOLIDATED: Description using standardized form field
                      DialogFormFields.buildDescriptionField(
                        context: context,
                        controller: _descriptionController,
                        labelText: context.l10n.groupDescriptionLabel,
                        hintText: context.l10n.groupDescriptionHint,
                        maxLength: 200,
                        maxLines: 3,
                      ),

                      const SizedBox(height: AppDimensions.spacingL),

                      // 🆕 FRIEND SELECTION UI
                      _buildFriendSelectionSection(),

                      // Selected members info
                      if (_selectedFriendIds.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.spacingM),
                        Text(
                          context.l10n
                              .groupSelectedMembers(_selectedFriendIds.length),
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: AppDimensions.spacingS),
                        Text(
                          context.l10n.groupInvitationNote,
                          style: AppTextStyles.bodySmall.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],

                      // Error display
                      if (_error != null) ...[
                        const SizedBox(height: AppDimensions.spacingM),
                        ErrorDisplayWidget(errorMessage: _error!),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              DialogFooter(
                primaryActionText: _isCreating
                    ? context.l10n.statusCreating
                    : context.l10n.socialCreateGroup,
                secondaryActionText: context.l10n.commonCancel,
                onPrimaryAction: _isCreating ? null : _createGroup,
                onSecondaryAction: () => Navigator.of(context).pop(),
                isLoading: _isCreating,
                primaryActionIcon: Icons.group_add,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendSelectionSection() {
    // ✅ FIX: Skip rebuilding friend list during creation to prevent freeze
    if (_isCreating) {
      return const SizedBox.shrink();
    }

    final friendsService = ServiceLocator.get<UnifiedFriendsService>();
    return StreamBuilder(
      stream: friendsService.stateStream,
      builder: (context, _) {
        final availableFriends = friendsService.friendsList;

        if (availableFriends.isEmpty) {
          return Column(
            children: [
              Text(
                context.l10n.groupSelectMembers,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingS),
              Text(
                context.l10n.groupNoFriendsToAdd,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        // Convert UserProfile to InvitationTarget for SocialComponents
        final availableTargets = availableFriends
            .map((friend) => InvitationTarget.individual(friend))
            .toList();

        final selectedTargets = _selectedFriends
            .map((friend) => InvitationTarget.individual(friend))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.groupSelectMembers,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              context.l10n.groupSelectFriendsToInvite,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SocialInvitationComponents.checkableTargetList(
                targets: availableTargets,
                selectedTargets: selectedTargets,
                onSelectionChanged: (selectedTargetsList) {
                  // Convert back to UserProfile
                  final selectedFriends = selectedTargetsList
                      .map((target) => availableFriends.firstWhere(
                          (friend) => friend.uid == target.targetId))
                      .toList();
                  _onFriendSelectionChanged(selectedFriends);
                },
                showSelectAll: true,
                selectAllText: context.l10n.commonSelectAll,
                selectNoneText: context.l10n.commonDeselectAll,
              ),
            ),
          ],
        );
      },
    );
  }
}

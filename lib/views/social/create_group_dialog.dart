// lib/views/social/create_group_dialog.dart - UPPDATERAD med GroupInvitationService

import 'package:flutter/material.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';
// ✅ NYTT: Import GroupInvitationService
import 'package:provider/provider.dart'; // <-- LÄGG TILL
import '../../viewmodels/create_group_viewmodel.dart'; // <-- LÄGG TILL

/// 🔍 AI INFO BLOCK:
/// Component: Create Group Dialog - UPPDATERAD med inbjudningssystem
/// File: views/social/create_group_dialog.dart
/// Quick Guide: Skapar grupp och skickar inbjudningar istället för direkt medlemskap
/// Dependencies IN: FriendsViewModel, UserAvatar, GroupDetailView, GroupInvitationService
/// Dependencies OUT: Skapa grupp + skicka inbjudningar via GroupInvitationService
/// Data flow: User input → Create empty group → Send invitations → Notify updates
/// State management: StatefulWidget med local state för formulär
/// Purpose: Konsekvent inbjudningssystem för både nya och befintliga grupper
/// Common issues: Group creation vs invitation sending, error handling
/// Test coverage: N/A (UI component)
/// Performance: ⚡ Minimal, endast form state
/// Analytics: ✅ Group creation + invitation tracking
/// Code smells: ✅ Konsekvent inbjudningssystem
/// Connected to: FriendsViewModel, FriendCategoriesService, GroupInvitationService
/// Used in phases: 18.4 - Konsekvent inbjudningssystem

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Fördefinierade emojis
  final List<String> _availableEmojis = [
    '👥',
    '🏠',
    '🍽️',
    '💼',
    '🎯',
    '⚽',
    '🎮',
    '📚',
    '🎵',
    '✈️',
    '🍕',
    '💪',
    '🛒',
    '🎉',
    '❤️',
    '⭐'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreateGroupViewModel(),
      child: Consumer2<CreateGroupViewModel, FriendsViewModel>(
        builder: (context, viewModel, friendsViewModel, child) {
          // Synka controllers
          if (_nameController.text != viewModel.name) {
            _nameController.text = viewModel.name;
          }
          if (_descriptionController.text != viewModel.description) {
            _descriptionController.text = viewModel.description;
          }

          return Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: AppTheme.containerHeightXLarge,
                maxHeight: MediaQuery.of(context).size.height *
                    AppTheme.cardOverlayOpacity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: AppTheme.sectionPadding,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppTheme.radiusMedium),
                        topRight: Radius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_add,
                          color: AppTheme.primaryColor,
                          size: AppTheme.iconSizeMedium,
                        ),
                        AppTheme.mediumHorizontalGap,
                        Expanded(
                          child: Text(
                            'Skapa ny grupp',
                            style: AppTheme.sectionTitleStyle,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppTheme.sectionPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gruppnamn
                          TextFormField(
                            controller: _nameController,
                            onChanged: viewModel.updateName,
                            decoration: InputDecoration(
                              labelText: 'Gruppnamn *',
                              hintText:
                                  'T.ex. Familjen, Jobbet, Träningskompisar',
                              errorText: viewModel.nameError,
                              prefixIcon: Container(
                                width: AppTheme.iconSizeDisplay,
                                height: AppTheme.iconSizeDisplay,
                                alignment: Alignment.center,
                                child: Text(
                                  viewModel.emoji,
                                  style: AppTheme.cardTitleStyle,
                                ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),

                          AppTheme.largeGap,

                          // Emoji-väljare
                          Text('Välj ikon för gruppen',
                              style: AppTheme.formLabelStyle),
                          AppTheme.smallGap,
                          Container(
                            padding: EdgeInsets.all(AppTheme.spacingSm),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: AppTheme.smallRadius,
                            ),
                            child: Wrap(
                              spacing: AppTheme.spacingSm,
                              runSpacing: AppTheme.spacingSm,
                              children: _availableEmojis.map((emoji) {
                                final isSelected = emoji == viewModel.emoji;
                                return GestureDetector(
                                  onTap: () => viewModel.updateEmoji(emoji),
                                  child: Container(
                                    width: AppTheme.iconSizeHero,
                                    height: AppTheme.iconSizeHero,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                              .withValues(alpha: 0.2)
                                          : null,
                                      borderRadius: AppTheme.smallRadius,
                                      border: isSelected
                                          ? Border.all(
                                              color: AppTheme.primaryColor)
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(emoji,
                                          style: AppTheme.sectionTitleStyle),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          AppTheme.largeGap,

                          // Beskrivning
                          TextFormField(
                            controller: _descriptionController,
                            onChanged: viewModel.updateDescription,
                            decoration: const InputDecoration(
                              labelText: 'Beskrivning (valfritt)',
                              hintText:
                                  'Beskriv vad den här gruppen är till för',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          AppTheme.largeGap,

                          // Inbjudningsförklaring
                          Container(
                            padding: AppTheme.cardPadding,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: AppTheme.smallRadius,
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                AppTheme.infoIcon(context,
                                    icon: Icons.info_outline),
                                AppTheme.smallGap,
                                Expanded(
                                  child: Text(
                                    'Vänner du väljer kommer få inbjudningar att gå med i gruppen.',
                                    style: AppTheme.bodyStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          AppTheme.mediumGap,

                          // Vänner att bjuda in
                          Text('Bjud in vänner till gruppen',
                              style: AppTheme.formLabelStyle),
                          AppTheme.smallGap,

                          if (friendsViewModel.friends.isEmpty)
                            Container(
                              padding: AppTheme.cardPadding,
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor
                                    .withValues(alpha: 0.1),
                                borderRadius: AppTheme.smallRadius,
                                border: Border.all(
                                  color: AppTheme.warningColor
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  AppTheme.warningIcon(context),
                                  AppTheme.smallGap,
                                  Expanded(
                                    child: Text(
                                      'Du har inga vänner än. Du kan skapa gruppen ändå.',
                                      style: AppTheme.bodyStyle,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              constraints: BoxConstraints(
                                  maxHeight: AppTheme.containerHeightSmall),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                borderRadius: AppTheme.smallRadius,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: friendsViewModel.friends.length,
                                itemBuilder: (context, index) {
                                  final friend =
                                      friendsViewModel.friends[index];
                                  final isSelected = viewModel.selectedFriendIds
                                      .contains(friend.uid);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (_) =>
                                        viewModel.toggleFriend(friend.uid),
                                    secondary: UserAvatar.small(
                                      imageUrl: friend.avatarUrl,
                                      displayName: friend.displayName,
                                    ),
                                    title: Text(friend.displayName),
                                    subtitle: friend.bio?.isNotEmpty == true
                                        ? Text(
                                            friend.bio!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                  );
                                },
                              ),
                            ),

                          if (viewModel.selectedFriendsCount > 0) ...[
                            AppTheme.smallGap,
                            Text(
                              '${viewModel.selectedFriendsCount} ${viewModel.selectedFriendsCount == 1 ? 'inbjudan kommer skickas' : 'inbjudningar kommer skickas'}',
                              style: AppTheme.captionStyle.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Footer buttons
                  Container(
                    padding: AppTheme.sectionPadding,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: viewModel.isCreating
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Avbryt'),
                          ),
                        ),
                        AppTheme.mediumHorizontalGap,
                        Expanded(
                          child: FilledButton(
                            onPressed: viewModel.isCreating
                                ? null
                                : () => _createGroup(context, viewModel),
                            child: viewModel.isCreating
                                ? AppTheme.smallLoadingIndicator(
                                    color: Colors.white)
                                : const Text('Skapa grupp'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createGroup(
      BuildContext context, CreateGroupViewModel viewModel) async {
    // Spara navigator-referens innan async
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await viewModel.createGroup();

    if (!mounted) return; // Kolla mounted efter async

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gruppen "${viewModel.name}" skapad! 🎉'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      navigator.pop();
    } else if (viewModel.error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(viewModel.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

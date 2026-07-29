// lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// List management operations for shopping lists
class ShoppingListOperations {
  /// BUT-1723: a conversion that kept BOTH lists blocks on a dialog, never a
  /// snackbar.
  ///
  /// The user has just confirmed a dangerous action whose dialog promised the
  /// other side disappears, and the outcome contradicts it. There is no undo
  /// path — the remedy is a manual delete — so `ui-conventions.md`'s
  /// class-2 rule applies: state the consequence and what to do, and make the
  /// user dismiss it. A 5-second `showError` snackbar is dismissed by walking
  /// away from the phone.
  ///
  /// [originatingContext] is the caller's context, or null when it has already
  /// unmounted — the caller owns that check, so the async-gap lint can see it.
  /// The outcome depends on a server round-trip and the user is free to leave
  /// the list meanwhile, so we fall back to the app-level navigator (the same
  /// escape hatch `incoming_share_handler` and `butlery_app` use to show UI
  /// from outside a live subtree). Silently dropping THIS warning would leave
  /// someone believing a list is private while every collaborator still has
  /// access. [buildMessage] takes whichever context actually renders.
  static Future<void> _warnConversionIncomplete(
    BuildContext? originatingContext,
    String Function(BuildContext) buildMessage,
  ) async {
    final host = originatingContext ?? appNavigatorKey.currentContext;
    if (host == null) {
      // Only reachable with no navigator at all (app tearing down). Nothing can
      // render, so leave a trail rather than pretending the warning was shown.
      AppLogger.error(
        'Conversion kept both lists but no context was available to warn the '
        'user — the shared list is still shared',
      );
      return;
    }

    await DialogFactory.showError(
      host,
      title: host.l10n.shoppingConvertIncompleteTitle,
      message: buildMessage(host),
    );
  }

  static Future<void> showCreateListDialog(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
  ) async {
    final name = await DialogFactory.showTextInput(
      context,
      title: context.l10n.shoppingCreateNewList,
      hintText: context.l10n.shoppingCreateNewListHint,
      confirmText: context.l10n.commonCreate,
      required: true,
    );

    if (name != null && name.isNotEmpty) {
      await viewModel.createPersonalList(name);
      if (context.mounted) onSuccess(context.l10n.shoppingListCreated(name));
    }
  }

  static Future<void> showClearCompletedConfirmation(
    BuildContext context,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    if (viewModel.boughtItems == 0) return;

    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingClearPurchasedTitle,
      message: context.l10n.shoppingClearPurchasedMessage(
        viewModel.boughtItems,
      ),
      confirmText: context.l10n.shoppingClear,
      isDangerous: true,
    );

    if (confirmed == true) {
      // BUT-1696: the bool is load-bearing. `clearBoughtItems` rolls the bought
      // rows back on failure (a shared-list permission denial is the realistic
      // trigger), so discarding it and always saying "Rensat" told the user a
      // destructive action succeeded while the rows reappeared. Consume the
      // reason before the mounted check — the read is what clears it.
      final success = await viewModel.clearBoughtItems();
      final reason = success ? null : viewModel.consumeMutationError();
      if (!context.mounted) return;
      if (success) {
        onSuccess(context.l10n.shoppingPurchasedCleared);
      } else {
        // Cause-neutral fallback — see the note in unified_shopping_view.
        onError(reason ?? context.l10n.errorGeneric);
      }
    }
  }

  static Future<void> showRenameListDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final textController = TextEditingController(text: list.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shoppingRenameList),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.shoppingCurrentName(list.name),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              StyledInput(
                controller: textController,
                autofocus: true,
                label: context.l10n.shoppingNewName,
                hint: context.l10n.shoppingNewNameHint,
                validator: (value) {
                  final requiredCheck = ValidationUtils.validateRequired(
                    value,
                    fieldName: context.l10n.commonName,
                  );
                  if (requiredCheck != null) return requiredCheck;
                  return ValidationUtils.validateLength(
                    value,
                    minLength: 2,
                    maxLength: 50,
                    fieldName: context.l10n.commonName,
                  );
                },
                maxLength: 50,
              ),
            ],
          ),
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonSave,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newName = textController.text.trim();
                Navigator.pop(context, newName);
              }
            },
          ),
        ],
      ),
    );

    if (result != null && result != list.name) {
      final success = await viewModel.renameList(list.id, result);
      if (context.mounted) {
        if (success) {
          onSuccess(context.l10n.shoppingListRenamed(result));
        } else {
          onError(context.l10n.shoppingCouldNotRenameList);
        }
      }
    }
  }

  static Future<void> showDeleteListConfirmationDialog(
    BuildContext context,
    UnifiedShoppingList list,
    UnifiedShoppingViewModel viewModel,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingDeleteList,
      message: list.items.isEmpty
          ? context.l10n.shoppingDeleteListConfirm(list.name)
          : context.l10n.shoppingDeleteListWithItemsConfirm(
              list.name,
              list.items.length,
            ),
      confirmText: context.l10n.commonDelete,
      cancelText: context.l10n.commonCancel,
      isDangerous: true,
    );

    if (confirmed == true) {
      final success = await viewModel.deleteList(list.id);
      if (context.mounted) {
        if (success) {
          onSuccess(context.l10n.shoppingListDeleted(list.name));
        } else {
          onError(context.l10n.shoppingCouldNotDeleteList);
        }
      }
    }
  }

  /// Shows friend picker dialog for converting a personal list to collaborative.
  /// Loads available friends, lets the user select members, then calls the
  /// backend conversion operation.
  static Future<void> showConvertToCollaborativeDialog(
    BuildContext context,
    UnifiedShoppingList list,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    try {
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      await friendsService.initialize();
      final availableFriends = friendsService.friends;

      if (availableFriends.isEmpty) {
        if (context.mounted) {
          onError(context.l10n.shoppingNoFriends);
        }
        return;
      }

      if (!context.mounted) return;

      final result = await showDialog<_ConvertToCollaborativeResult>(
        context: context,
        builder: (context) => _ConvertToCollaborativeDialog(
          friends: availableFriends,
        ),
      );

      if (result == null || result.selectedFriends.isEmpty) return;

      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final memberIds = result.selectedFriends.map((f) => f.uid).toList();
      final memberDisplayNames = {
        for (final f in result.selectedFriends) f.uid: f.displayName,
      };

      final outcome = await shoppingService.collaborative
          .convertPersonalToCollaborative(
            personalListId: list.id,
            memberIds: memberIds,
            memberDisplayNames: memberDisplayNames,
            description: result.description,
          );

      if (outcome.originalKept) {
        // BUT-1723: the copy could not be confirmed on the server, so the
        // source survives on purpose. Saying "converted" here would hide a
        // duplicate the user has to resolve by hand.
        await _warnConversionIncomplete(
          context.mounted ? context : null,
          (ctx) => ctx.l10n.shoppingConvertedOriginalKept,
        );
        return;
      }

      if (!context.mounted) return;
      if (outcome.newListId == null) {
        onError(context.l10n.shoppingConvertError);
      } else {
        onSuccess(context.l10n.shoppingConvertedToCollaborative);
      }
    } catch (e) {
      AppLogger.error('Error converting to collaborative: $e');
      if (context.mounted) {
        onError(context.l10n.shoppingConvertError);
      }
    }
  }

  /// Shows confirmation dialog for converting a collaborative list to personal.
  /// Warns that collaborators will lose access.
  static Future<void> showConvertToPersonalDialog(
    BuildContext context,
    UnifiedShoppingList list,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingConvertToPersonalTitle,
      message: context.l10n.shoppingConvertToPersonalWarning,
      confirmText: context.l10n.shoppingConvertToPersonal,
      isDangerous: true,
    );

    if (confirmed != true) return;

    try {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final outcome = await shoppingService.collaborative
          .convertCollaborativeToPersonal(list.id);

      if (outcome.originalKept) {
        // BUT-1723: the shared source is still there and every collaborator
        // still has access — the exact opposite of what the danger dialog just
        // promised. This must not be reported as a clean success, and it needs
        // its OWN wording: "the original is still there" does not tell an owner
        // who converted specifically to cut somebody off that they are still in.
        await _warnConversionIncomplete(
          context.mounted ? context : null,
          (ctx) => ctx.l10n.shoppingConvertedToPersonalOriginalKept,
        );
        return;
      }

      if (!context.mounted) return;
      if (outcome.newListId == null) {
        onError(context.l10n.shoppingConvertError);
      } else {
        onSuccess(context.l10n.shoppingConvertedToPersonal);
      }
    } catch (e) {
      AppLogger.error('Error converting to personal: $e');
      if (context.mounted) {
        onError(context.l10n.shoppingConvertError);
      }
    }
  }
}

/// Result from the convert-to-collaborative dialog
class _ConvertToCollaborativeResult {
  final List<UserProfile> selectedFriends;
  final String? description;

  _ConvertToCollaborativeResult({
    required this.selectedFriends,
    this.description,
  });
}

/// Stateful dialog for selecting friends when converting to collaborative list
class _ConvertToCollaborativeDialog extends StatefulWidget {
  final List<UserProfile> friends;

  const _ConvertToCollaborativeDialog({required this.friends});

  @override
  State<_ConvertToCollaborativeDialog> createState() =>
      _ConvertToCollaborativeDialogState();
}

class _ConvertToCollaborativeDialogState
    extends State<_ConvertToCollaborativeDialog> {
  final Set<String> _selectedIds = {};
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.shoppingConvertToCollaborativeTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.shoppingConvertToCollaborativeDescription,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            // Friend list with checkboxes
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.friends.length,
                itemBuilder: (context, index) {
                  final friend = widget.friends[index];
                  final isSelected = _selectedIds.contains(friend.uid);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(friend.uid);
                        } else {
                          _selectedIds.remove(friend.uid);
                        }
                      });
                    },
                    title: Text(
                      friend.displayName,
                      style: AppTextStyles.contentLabel,
                    ),
                    subtitle: friend.email.isNotEmpty
                        ? Text(
                            friend.email,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    secondary: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        friend.displayName.isNotEmpty
                            ? friend.displayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.contentLabel.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            // Optional description field
            StyledInput(
              controller: _descriptionController,
              label: context.l10n.shoppingDescriptionLabel,
              maxLength: 200,
            ),
          ],
        ),
      ),
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.pop(context),
        ),
        ActionButtons.primaryButton(
          context,
          label: context.l10n.shoppingConvertToCollaborative,
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final selected = widget.friends
                      .where((f) => _selectedIds.contains(f.uid))
                      .toList();
                  final description =
                      _descriptionController.text.trim().isNotEmpty
                      ? _descriptionController.text.trim()
                      : null;
                  Navigator.pop(
                    context,
                    _ConvertToCollaborativeResult(
                      selectedFriends: selected,
                      description: description,
                    ),
                  );
                },
        ),
      ],
    );
  }
}

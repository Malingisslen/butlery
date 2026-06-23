/// Selection-mode AppBar extracted from `mina_recept_view.dart` per
/// BUT-441. Active when the user is in bulk-selection mode; provides
/// close, select-all, and bulk-delete actions. Bulk-delete confirmation
/// + undo SnackBar live here (5-7s window via `commonUndo`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/views/personal_tags_view.dart';
import 'package:butlery/widgets/common/dialogs/slot_picker_dialog.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

/// Builds the selection-mode AppBar. Returned as a `PreferredSizeWidget`
/// so the parent Scaffold can drop it straight in.
PreferredSizeWidget buildMinaReceptSelectionAppBar(
  BuildContext context,
  RecipeListViewModel viewModel,
) {
  final cs = Theme.of(context).colorScheme;
  return AppBar(
    backgroundColor: cs.primaryContainer,
    leading: IconButton(
      icon: const Icon(Icons.close),
      onPressed: viewModel.clearSelection,
      tooltip: context.l10n.bulkCancelSelection,
    ),
    title: Text(
      context.l10n.bulkSelectedCount(viewModel.selectedCount),
      style: AppTextStyles.titleMedium,
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.select_all),
        tooltip: context.l10n.bulkSelectAll,
        onPressed: viewModel.selectAll,
      ),
      // BUT-933: bulk-share. BUT-1012 added bulk-tag below.
      IconButton(
        icon: const Icon(Icons.share_outlined),
        tooltip: context.l10n.bulkShare,
        onPressed: viewModel.selectedCount == 0
            ? null
            : () => _openBulkShareDialog(context, viewModel),
      ),
      IconButton(
        icon: const Icon(Icons.local_offer_outlined),
        tooltip: context.l10n.bulkTag,
        onPressed: viewModel.selectedCount == 0
            ? null
            : () => _openBulkTagPicker(context, viewModel),
      ),
      // BUT-1013: bulk-add-to-menu — open SlotPickerDialog (BUT-1029),
      // then loop selected recipes into chosen slot (single-slot
      // distributes day-by-day; multi-slot stacks).
      IconButton(
        icon: const Icon(Icons.calendar_month_outlined),
        tooltip: context.l10n.bulkAddToMenu,
        onPressed: viewModel.selectedCount == 0
            ? null
            : () => _openBulkAddToMenu(context, viewModel),
      ),
      // BUT-1014: bulk-export — clipboard markdown or share-sheet file.
      IconButton(
        icon: const Icon(Icons.ios_share),
        tooltip: context.l10n.bulkExport,
        onPressed: viewModel.selectedCount == 0
            ? null
            : () => _openBulkExport(context, viewModel),
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: context.l10n.bulkDelete,
        onPressed: () async {
          final count = viewModel.selectedCount;
          final confirmed = await CommonDialogActions.showDeleteConfirmation(
            context: context,
            itemName: '$count recept',
            itemType: 'recept',
            warningMessage: context.l10n.bulkDeleteConfirmMessage,
            icon: Icons.delete_sweep,
          );
          if (confirmed == true) {
            viewModel.deleteSelected();
            viewModel.clearSelection();
            if (context.mounted) {
              SnackBarUtils.showSuccessWithAction(
                context,
                context.l10n.bulkDeleteSuccess(count),
                actionLabel: context.l10n.commonUndo,
                onAction: () => viewModel.undoBulkDelete(),
                duration: const Duration(seconds: 7),
              );
            }
          }
        },
      ),
    ],
  );
}

/// BUT-933: open the bulk-share dialog with the selected recipes.
/// `UniversalShareDialog.bulkShare` already accepts a list — no Cloud
/// Function changes needed. Friends + groups are fetched best-effort
/// matching `recipe_social_handler.showSocialShareDialog`.
Future<void> _openBulkShareDialog(
  BuildContext context,
  RecipeListViewModel viewModel,
) async {
  final recipes = viewModel.selectedRecipes;
  if (recipes.isEmpty) return;

  final shareViewModel = ServiceLocator.get<UniversalShareDialogViewModel>();
  final friendsService = ServiceLocator.get<UnifiedFriendsService>();

  List<UserProfile> availableFriends = const [];
  try {
    availableFriends = friendsService.friends;
  } catch (_) {
    // Silently continue with empty friends list.
  }
  final List<FriendCategory> availableGroups = friendsService.categoriesList;

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => ChangeNotifierProvider.value(
      value: shareViewModel,
      child: UniversalShareDialog.bulkShare(
        contentItems: recipes,
        primaryContentType: ShareContentType.recipe,
        viewModel: shareViewModel,
        availableFriends: availableFriends,
        availableGroups: availableGroups,
      ),
    ),
  );
}

/// BUT-1013: bulk-add-to-menu handler. Opens SlotPickerDialog (BUT-1029),
/// receives a (weekStart, day, slot) triple, distributes selected recipes
/// across slots via `WeeklyMenuPlanService.bulkAssignRecipes`, and surfaces
/// added/overflow counts via snackbar. Selection mode exits on success.
///
/// BUT-1034: on overflow the snackbar gets an action button that cascades
/// the remaining recipes into the following week (single hop, no recursion
/// past 2 weeks — the recursion guard means the action button is only
/// offered on the first overflow, never on a second-week overflow).
Future<void> _openBulkAddToMenu(
  BuildContext context,
  RecipeListViewModel viewModel,
) async {
  final recipes = viewModel.selectedRecipes;
  if (recipes.isEmpty) return;

  final selection = await showSlotPickerDialog(context);
  if (selection == null || !context.mounted) return;

  await _runBulkAddToMenu(
    context,
    viewModel,
    recipes: recipes,
    weekStart: selection.weekStart,
    startDay: selection.day,
    slot: selection.slot,
    isCascade: false,
  );
}

/// BUT-1034: shared bulk-add runner used by both the initial call and the
/// snackbar-triggered next-week cascade. `isCascade=true` disables the
/// action button on a follow-up overflow (recursion guard, 2-week cap) and
/// swaps in cascade-specific snackbar copy.
Future<void> _runBulkAddToMenu(
  BuildContext context,
  RecipeListViewModel viewModel, {
  required List<Recipe> recipes,
  required DateTime weekStart,
  required DayOfWeek startDay,
  required MealSlot slot,
  required bool isCascade,
}) async {
  try {
    final service = ServiceLocator.get<WeeklyMenuPlanService>();
    final result = await service.bulkAssignRecipes(
      weekStart: weekStart,
      startDay: startDay,
      slot: slot,
      recipes: recipes,
    );

    if (!context.mounted) return;
    if (!isCascade) viewModel.clearSelection();

    if (result.overflowed > 0) {
      if (isCascade) {
        // Second-week overflow: surface the unplaced count without offering
        // a third week — the user already opted into the cascade once.
        SnackBarUtils.showInfo(
          context,
          context.l10n.bulkAddToMenuOverflowedTwoWeeks(result.overflowed),
        );
      } else {
        // First-week overflow: offer the cascade. The remaining recipes are
        // `recipes.sublist(result.added)` because bulkAssignRecipes processes
        // the list in order (verified in weekly_menu_plan_service.dart:247).
        final remaining = recipes.sublist(result.added);
        final nextWeek = weekStart.add(const Duration(days: 7));
        SnackBarUtils.showInfo(
          context,
          context.l10n.bulkAddToMenuOverflowed(result.added, recipes.length),
          actionLabel: context.l10n.bulkAddToMenuOverflowedAction,
          onAction: () => _runBulkAddToMenu(
            context,
            viewModel,
            recipes: remaining,
            weekStart: nextWeek,
            startDay: DayOfWeek.mon,
            slot: slot,
            isCascade: true,
          ),
        );
      }
    } else {
      SnackBarUtils.showSuccess(
        context,
        isCascade
            ? context.l10n.bulkAddToMenuSuccessNextWeek(result.added)
            : context.l10n.bulkAddToMenuSuccess(
                result.added,
                slot.displayLabel,
                startDay.displayLabel,
              ),
      );
    }
  } catch (e) {
    AppLogger.error('Bulk add-to-menu failed', e);
    if (!context.mounted) return;
    SnackBarUtils.showError(context, e.toString());
  }
}

/// BUT-1014: bulk-export handler. Bottom sheet offers two outputs —
/// clipboard markdown (single tap) or share-sheet file via `share_plus`.
/// Markdown format is the same for both paths so users can switch between
/// outputs without re-formatting; file extension is `.md`.
Future<void> _openBulkExport(
  BuildContext context,
  RecipeListViewModel viewModel,
) async {
  final recipes = viewModel.selectedRecipes;
  if (recipes.isEmpty) return;

  final choice = await showModalBottomSheet<_ExportChoice>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(sheetContext.l10n.bulkExportCopyClipboard),
            onTap: () =>
                Navigator.of(sheetContext).pop(_ExportChoice.clipboard),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(sheetContext.l10n.bulkExportShareFile),
            onTap: () =>
                Navigator.of(sheetContext).pop(_ExportChoice.shareFile),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final markdown = _formatRecipesAsMarkdown(recipes);

  try {
    if (choice == _ExportChoice.clipboard) {
      await Clipboard.setData(ClipboardData(text: markdown));
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(
        context,
        context.l10n.bulkExportCopied(recipes.length),
      );
    } else {
      // share_plus handles file vs text uniformly on mobile; web falls back
      // to text-share which is acceptable for desktop browsers.
      await SharePlus.instance.share(
        ShareParams(
          text: markdown,
          subject: 'Recept (${recipes.length} st)',
        ),
      );
    }
    if (!context.mounted) return;
    viewModel.clearSelection();
  } catch (e) {
    AppLogger.error('Bulk export failed', e);
    if (!context.mounted) return;
    SnackBarUtils.showError(context, e.toString());
  }
}

enum _ExportChoice { clipboard, shareFile }

/// BUT-1014: format a list of recipes as markdown. Sections per recipe
/// separated by `---`. Skips empty fields. Stays Swedish-labelled because
/// the app's UI is Swedish (per CLAUDE.local.md).
String _formatRecipesAsMarkdown(List<Recipe> recipes) {
  final buffer = StringBuffer();
  for (var i = 0; i < recipes.length; i++) {
    final r = recipes[i];
    buffer.writeln('# ${r.title}');
    buffer.writeln();
    if (r.description.isNotEmpty) {
      buffer.writeln(r.description);
      buffer.writeln();
    }
    if (r.portions != null) buffer.writeln('**Portioner:** ${r.portions}');
    if (r.timeMinutes != null) {
      buffer.writeln('**Tid:** ${r.timeMinutes} min');
    }
    buffer.writeln();
    if (r.ingredients.isNotEmpty) {
      buffer.writeln('## Ingredienser');
      for (final ing in r.ingredients) {
        buffer.writeln('- $ing');
      }
      buffer.writeln();
    }
    if (r.instructions.isNotEmpty) {
      buffer.writeln('## Instruktioner');
      for (var step = 0; step < r.instructions.length; step++) {
        buffer.writeln('${step + 1}. ${r.instructions[step]}');
      }
      buffer.writeln();
    }
    if (i < recipes.length - 1) {
      buffer.writeln('---');
      buffer.writeln();
    }
  }
  return buffer.toString();
}

/// BUT-1012: open a single-select tag picker for the current selection.
/// On pick, merge (don't replace) the chosen tag into each selected recipe's
/// personalTagIds, then surface a success snackbar with an undo action that
/// restores per-recipe snapshots. Bulk semantic is "add this one tag to many
/// recipes" — multi-tag bulk edits would raise merge/replace questions that
/// are out of scope for this ticket.
Future<void> _openBulkTagPicker(
  BuildContext context,
  RecipeListViewModel viewModel,
) async {
  final selectedCount = viewModel.selectedCount;
  if (selectedCount == 0) return;

  final picked = await showModalBottomSheet<({String id, String name})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _BulkTagPicker(selectedCount: selectedCount),
  );

  if (picked == null || !context.mounted) return;

  final modified = await viewModel.bulkApplyPersonalTag(
    tagId: picked.id,
    tagName: picked.name,
  );

  if (!context.mounted) return;
  viewModel.clearSelection();

  if (modified == 0) {
    SnackBarUtils.showInfo(context, context.l10n.bulkTagAllAlreadyTagged);
    return;
  }
  SnackBarUtils.showSuccessWithAction(
    context,
    context.l10n.bulkTagSuccess(modified),
    actionLabel: context.l10n.commonUndo,
    onAction: () => viewModel.undoBulkApplyPersonalTag(),
    duration: const Duration(seconds: 7),
  );
}

/// BUT-1012: bottom-sheet single-select tag picker for bulk apply.
///
/// Lists every PersonalTag from the singleton [PersonalTagViewModel]; tap a
/// chip and the sheet pops with the chosen `(id, name)`. Empty state offers
/// a button that navigates to [PersonalTagsView] for creating the first tag.
class _BulkTagPicker extends StatefulWidget {
  final int selectedCount;

  const _BulkTagPicker({required this.selectedCount});

  @override
  State<_BulkTagPicker> createState() => _BulkTagPickerState();
}

class _BulkTagPickerState extends State<_BulkTagPicker> {
  late final PersonalTagViewModel _tagVm;

  @override
  void initState() {
    super.initState();
    _tagVm = ServiceLocator.get<PersonalTagViewModel>();
  }

  void _selectTag(PersonalTag tag) {
    Navigator.of(context).pop((id: tag.id, name: tag.name));
  }

  void _navigateToManageTags() {
    // Capture navigator once: after pop() the sheet's context is unmounted,
    // so a fresh `Navigator.of(context)` would resolve against a different
    // tree (or throw if the sheet's element is already deactivated).
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(builder: (_) => const PersonalTagsView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (sheetContext, scrollController) {
        final cs = Theme.of(context).colorScheme;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusM),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: AppDimensions.paddingM),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadius2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        context.l10n.bulkTagDialogTitle(widget.selectedCount),
                        style: AppTextStyles.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.commonCancel),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    final tags = _tagVm.tags;
    if (tags.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.label_outline, size: 64),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                context.l10n.bulkTagNoTagsAvailable,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              FilledButton.icon(
                onPressed: _navigateToManageTags,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.taggingCreateTag),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      children: [
        Wrap(
          spacing: AppDimensions.spacingSm,
          runSpacing: AppDimensions.spacingSm,
          children: tags
              .map(
                (tag) => ActionChip(
                  label: Text(tag.name),
                  onPressed: () => _selectTag(tag),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        Center(
          child: TextButton.icon(
            onPressed: _navigateToManageTags,
            icon: const Icon(Icons.settings, size: AppDimensions.iconSize18),
            label: Text(context.l10n.taggingManageTags),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
      ],
    );
  }
}

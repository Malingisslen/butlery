/// What the buttons and rows on a tag's page do, kept out of the view so it
/// stays a layout.
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/tagging/rule_builder_sheet.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

abstract final class TagDetailActions {
  static Future<void> rename(
    BuildContext context,
    PersonalTag tag,
    String name,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
    // updateTag reports a failure by returning false, not by throwing.
    final saved = await viewModel.updateTag(tag.copyWith(name: name));
    if (!context.mounted) return;
    if (saved) {
      SnackBarUtils.showSuccess(context, context.l10n.tagDetailUpdated);
    } else {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.tagDetailCouldNotUpdate,
      );
    }
  }

  static Future<void> addRule(BuildContext context, PersonalTag tag) async {
    final result = await _showRuleBuilderSheet(context, tag, null);
    if (result == null || !context.mounted) return;
    final viewModel = context.read<PersonalTagViewModel>();
    try {
      await viewModel.createRule(tag.id, result);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.tagDetailRuleCreated);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.tagDetailCouldNotCreateRule,
        );
      }
    }
  }

  static Future<void> editRule(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final result = await _showRuleBuilderSheet(context, tag, rule);
    if (result == null || !context.mounted) return;
    final viewModel = context.read<PersonalTagViewModel>();
    try {
      await viewModel.updateRule(tag.id, result);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.tagDetailRuleUpdated);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.tagDetailCouldNotUpdateRule,
        );
      }
    }
  }

  static Future<PersonalTagRule?> _showRuleBuilderSheet(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule? existingRule,
  ) {
    return showButlerySheet<PersonalTagRule>(
      context: context,
      builder: (context) =>
          RuleBuilderSheet(tag: tag, existingRule: existingRule),
    );
  }

  static Future<void> toggleRule(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final viewModel = context.read<PersonalTagViewModel>();
    try {
      await viewModel.toggleRuleEnabled(tag.id, rule.id);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.tagDetailRuleUpdated);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.tagDetailCouldNotChangeRuleStatus,
        );
      }
    }
  }

  static Future<void> deleteRule(
    BuildContext context,
    PersonalTag tag,
    PersonalTagRule rule,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      title: context.l10n.tagDetailDeleteRuleConfirm,
      message: context.l10n.tagDetailDeleteRuleMessage(rule.name),
      confirmText: context.l10n.tagDetailRuleDeleteAction,
    );
    if (!confirmed || !context.mounted) return;
    final viewModel = context.read<PersonalTagViewModel>();
    try {
      await viewModel.deleteRule(tag.id, rule.id);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.tagDetailRuleDeleted);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.tagDetailCouldNotDeleteRule,
        );
      }
    }
  }

  static Future<void> applyRulesToRecipes(BuildContext context) async {
    final viewModel = context.read<PersonalTagViewModel>();

    showButleryDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        // The plate line with its text, never a spinner (produktregler.md
        // :163, :304; beslutslogg B-18).
        content: PlateLineMessage(message: context.l10n.tagDetailApplyingRules),
      ),
    );

    try {
      final result = await viewModel.applyRulesToExistingRecipes();

      if (context.mounted) {
        Navigator.pop(context);
        SnackBarUtils.showSuccess(
          context,
          result.hasChanges
              ? context.l10n.tagDetailRulesAppliedSuccess(
                  result.tagsApplied,
                  result.recipesModified,
                )
              : context.l10n.tagDetailNoRecipesMatched,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to apply rules to recipes',
        e,
        'TagDetailView',
        stackTrace,
      );
      if (context.mounted) {
        Navigator.pop(context);
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.tagDetailCouldNotApplyRules,
        );
      }
    }
  }

  static Future<void> deleteTag(BuildContext context, PersonalTag tag) async {
    // BUT-929: cascade preview — show how many recipes will lose this tag.
    final viewModel = context.read<PersonalTagViewModel>();
    final confirmed = await _confirmDelete(
      context,
      title: context.l10n.tagDetailDeleteTagConfirm,
      message: [
        context.l10n.personalTagDeleteTagMessageWithCount(
          tag.name,
          viewModel.getUsageCount(tag.name),
        ),
        if (tag.isCookbook) context.l10n.cookbookDeleteTagWarning,
      ].join('\n\n'),
      confirmText: context.l10n.tagDetailDeleteTagAction,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await viewModel.deleteTag(tag.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        SnackBarUtils.showSuccess(context, context.l10n.tagDetailDeleted);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.tagDetailCouldNotDelete,
        );
      }
    }
  }

  static Future<bool> _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: title,
      message: message,
      primaryActionText: confirmText,
    );
    return confirmed == true;
  }
}

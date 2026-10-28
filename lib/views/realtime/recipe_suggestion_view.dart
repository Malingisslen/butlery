/// P5-U27b: one suggestion to a shared recipe, field by field.
///
/// produktregler.md:103: the owner's version wins and the other person's
/// change is kept as a suggestion, reached through "Se ditt förslag", for 7
/// days. produktregler.md:241: the owner accepts or dismisses it.
///
/// Two readers, one view. The suggester sees what they suggested against the
/// recipe as it is now, and when it is kept until. The owner sees the same
/// and decides: "Använd förslaget" or "Avvisa förslaget".
///
/// What is drawn and what is built: no drawing shows a suggestion. The field
/// rows are the conflict view's, named "Förslaget"
/// and "Nu"; the decision
/// bar is the conflict view's bottom bar with the primary action first and
/// the outlined one under it (one primary action per
/// view). Recorded as interpretations in the P5-U27b commit.
library;

import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/content_time_labels.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/views/realtime/conflict_field_label.dart';
import 'package:butlery/widgets/common/bold_in_text.dart';
import 'package:butlery/widgets/common/diff_field_row.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/state_widget.dart';

class RecipeSuggestionView extends StatefulWidget {
  const RecipeSuggestionView({
    super.key,
    required this.suggestion,
    required this.asOwner,
  });

  final RecipeSuggestion suggestion;

  /// True for the recipe's owner, who decides; false for the suggester, who
  /// only looks.
  final bool asOwner;

  /// Pushes the view as a full-screen route, as the conflict view is.
  static Future<void> show(
    BuildContext context,
    RecipeSuggestion suggestion, {
    required bool asOwner,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            RecipeSuggestionView(suggestion: suggestion, asOwner: asOwner),
      ),
    );
  }

  /// Stable keys for the two decisions, never found by their text.
  static const acceptKey = ValueKey('recipeSuggestion.accept');
  static const dismissKey = ValueKey('recipeSuggestion.dismiss');

  @override
  State<RecipeSuggestionView> createState() => _RecipeSuggestionViewState();
}

enum _Decision { accept, dismiss }

class _RecipeSuggestionViewState extends State<RecipeSuggestionView> {
  RecipeSuggestionService? get _service =>
      ServiceLocator.tryGet<RecipeSuggestionService>();

  late Future<ConflictDiff> _diff = _load();
  _Decision? _busy;

  bool get _decidesHere => widget.asOwner && widget.suggestion.isPending;

  Future<ConflictDiff> _load() {
    final svc = _service;
    if (svc == null) {
      return Future.error(StateError('No suggestion service'));
    }
    return svc.diffAgainstLive(widget.suggestion);
  }

  String _keptUntil(BuildContext context) => ContentTimeLabels.dateLabel(
    context.l10n,
    widget.suggestion.expiresAt,
    clock.now(),
  );

  Future<void> _decide(_Decision decision) async {
    final svc = _service;
    if (svc == null || _busy != null) return;
    setState(() => _busy = decision);
    final l = context.l10n;
    final keptUntil = _keptUntil(context);
    try {
      if (decision == _Decision.accept) {
        await svc.accept(widget.suggestion);
      } else {
        await svc.dismiss(widget.suggestion);
      }
      if (!mounted) return;
      // Shown before the pop: the app's messenger carries the snackbar to the
      // recipe underneath.
      SnackBarUtils.showSuccess(
        context,
        decision == _Decision.accept
            ? l.recipeSuggestionAccepted
            : l.recipeSuggestionDismissed,
      );
      Navigator.of(context).pop();
    } on RecipeSuggestionTargetMissing {
      if (!mounted) return;
      setState(() => _busy = null);
      // Trying again cannot bring the recipe back, so Stäng, not a retry.
      SnackBarUtils.showFailure(context, what: l.recipeSuggestionRecipeGone);
    } on RecipeSuggestionChanged {
      // Q6-12 = B: the suggester replaced it while it was open. Nothing was
      // decided; the owner goes back and opens the new one, so no retry
      // here decides on content they have not seen.
      if (!mounted) return;
      setState(() => _busy = null);
      SnackBarUtils.showFailure(
        context,
        what: l.recipeSuggestionChangedSinceOpened,
      );
    } catch (e) {
      AppLogger.error('Suggestion decision failed', e);
      if (!mounted) return;
      setState(() => _busy = null);
      SnackBarUtils.showFailure(
        context,
        what: decision == _Decision.accept
            ? l.recipeSuggestionAcceptFailed
            : l.recipeSuggestionDismissFailed,
        preserved: l.recipeSuggestionKeptUntil(keptUntil),
        action: FailureAction.retry(() => _decide(decision)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final decides = _decidesHere;
    return ButleryPage.undersida(
      title: l.recipeSuggestionTitle,
      body: FutureBuilder<ConflictDiff>(
        future: _diff,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return StateWidget.loading(message: l.recipeSuggestionLoading);
          }
          final error = snap.error;
          if (error is RecipeSuggestionTargetMissing) {
            return StateWidget.error(message: l.recipeSuggestionRecipeGone);
          }
          if (error != null || !snap.hasData) {
            return StateWidget.error(
              message: l.recipeSuggestionLoadFailed,
              actionLabel: l.commonRetry,
              onAction: () => setState(() => _diff = _load()),
            );
          }
          return _content(context, snap.data!);
        },
      ),
      bottomNavigationBar: decides ? _decisionBar(context) : null,
    );
  }

  Widget _content(BuildContext context, ConflictDiff diff) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final saffron = context.modeColors.textAccent;
    final name = RecipeSuggestionService.suggesterNameOf(widget.suggestion);
    // Q6-12 = B: both readers are told when it replaced an earlier one.
    final replaced = widget.suggestion.wasReplaced;
    final who = storedNameOr(name, l.displayUnknownUser);
    // The recipe's own title: a suggestion that renames it must not rename
    // the sentence about it.
    final recipeTitle =
        diff.changedFields
            .where((f) => f.fieldKey == 'title')
            .map((f) => f.remoteText)
            .firstOrNull ??
        (widget.suggestion.suggestion['title'] as String?).orEmpty();
    final intro = widget.asOwner
        ? (replaced
              ? l.recipeSuggestionIntroOwnerUpdated(who, recipeTitle)
              : l.recipeSuggestionIntroOwner(who, recipeTitle))
        : (replaced
              ? l.recipeSuggestionIntroMineUpdated(recipeTitle)
              : l.recipeSuggestionIntroMine(recipeTitle));
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.space16),
      children: [
        BoldInText(intro, bold: [if (widget.asOwner) who, recipeTitle]),
        const SizedBox(height: AppDimensions.space16),
        if (diff.isEmpty)
          Text(
            l.recipeSuggestionNoChanges,
            style: AppTextStyles.contentLabel.copyWith(
              color: cs.onSurfaceVariant,
            ),
          )
        else
          for (final field in diff.changedFields) ...[
            const ButleryDivider(),
            const SizedBox(height: AppDimensions.space12),
            DiffFieldRow(
              title: conflictFieldLabel(l, field.fieldKey),
              emptyText: l.conflictDiffEmptyValue,
              versions: [
                DiffVersion(
                  name: l.recipeSuggestionSuggestedLabel,
                  text: field.localText,
                  marker: saffron,
                ),
                DiffVersion(
                  name: l.recipeSuggestionCurrentLabel,
                  text: field.remoteText,
                  marker: cs.onSurface,
                  emphasised: true,
                  badge: l.conflictDiffApplies,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space12),
          ],
        if (!_decidesHere)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.space8),
            child: _keptNote(context),
          ),
      ],
    );
  }

  Widget _keptNote(BuildContext context) => Text(
    context.l10n.recipeSuggestionKeptNote(_keptUntil(context)),
    textAlign: TextAlign.center,
    style: AppTextStyles.bodyMedium.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _decisionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final accepting = _busy == _Decision.accept;
    final dismissing = _busy == _Decision.dismiss;
    return Material(
      color: cs.surface,
      elevation: AppDimensions.elevationMedium,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _keptNote(context),
              const SizedBox(height: AppDimensions.space12),
              // The view's one primary action. Busy
              // keeps its name and draws the plate line.
              FormButton(
                key: RecipeSuggestionView.acceptKey,
                label: l.recipeSuggestionAccept,
                busy: accepting,
                onPressed: _busy != null
                    ? PlateLineButton.ignore
                    : () => _decide(_Decision.accept),
              ),
              const SizedBox(height: AppDimensions.space8),
              ActionButtons.outlinedButton(
                context,
                key: RecipeSuggestionView.dismissKey,
                label: l.recipeSuggestionDismiss,
                isExpanded: true,
                isLoading: dismissing,
                onPressed: _busy != null
                    ? PlateLineButton.ignore
                    : () => _decide(_Decision.dismiss),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

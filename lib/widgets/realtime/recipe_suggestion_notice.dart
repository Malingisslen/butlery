/// P5-U27b: the suggestion line in recipe detail.
///
/// produktregler.md:103 keeps a suggestion 7 days behind "Se ditt förslag";
/// produktregler.md:241 lets the owner accept or dismiss it. The conflict
/// banner that first says so is dismissable, so this line is how both people
/// reach the suggestion for the rest of its 7 days:
/// - the owner sees suggestions waiting for a decision ("Se förslaget");
/// - the suggester sees their newest suggestion and what became of it
///   ("Se ditt förslag").
///
/// Nothing shows when there is nothing kept, or when the store is not
/// registered. Which suggestion is opened comes from its document id, never
/// from its position or text.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/realtime/recipe_suggestion_view.dart';
import 'package:butlery/widgets/realtime/restore_overwritten_version.dart';

class RecipeSuggestionNotice extends StatefulWidget {
  const RecipeSuggestionNotice({
    super.key,
    required this.recipeId,
    required this.isOwner,
  });

  /// The recipe's id, the same one the conflict banner is scoped by.
  final String recipeId;

  /// Whether the signed-in user owns the recipe, from its owner id.
  final bool isOwner;

  static const noticeKey = ValueKey('recipeSuggestion.notice');
  static const openKey = ValueKey('recipeSuggestion.open');

  /// Opens the suggester's own suggestion [suggestionId] on [recipeId], as the
  /// conflict banner's "Se ditt förslag" does. Found by id in the suggester's
  /// own list; a suggestion that is no longer kept says so.
  static Future<void> openMine(
    BuildContext context, {
    required String recipeId,
    required String suggestionId,
  }) async {
    final svc = ServiceLocator.tryGet<RecipeSuggestionService>();
    if (svc == null) return;
    RecipeSuggestion? found;
    try {
      final mine = await svc.watchMine(recipeId).first;
      found = mine.where((s) => s.id == suggestionId).firstOrNull;
    } catch (e) {
      AppLogger.error('Could not read the suggestion', e);
    }
    if (!context.mounted) return;
    if (found == null) {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.recipeSuggestionLoadFailed,
      );
      return;
    }
    await RecipeSuggestionView.show(context, found, asOwner: false);
  }

  @override
  State<RecipeSuggestionNotice> createState() => _RecipeSuggestionNoticeState();
}

class _RecipeSuggestionNoticeState extends State<RecipeSuggestionNotice> {
  StreamSubscription<List<RecipeSuggestion>>? _sub;
  List<RecipeSuggestion> _rows = const [];

  @override
  void initState() {
    super.initState();
    final svc = ServiceLocator.tryGet<RecipeSuggestionService>();
    final stream = svc == null
        ? null
        : widget.isOwner
        ? svc.watchPendingToMe(widget.recipeId)
        : svc.watchMine(widget.recipeId);
    _sub = stream?.listen(
      (rows) {
        if (mounted) setState(() => _rows = rows);
      },
      onError: (Object e) => AppLogger.error('Could not read suggestions', e),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  String _text(BuildContext context, List<RecipeSuggestion> rows) {
    final l = context.l10n;
    final newest = rows.first;
    if (widget.isOwner) {
      if (rows.length > 1) return l.recipeSuggestionFromMany(rows.length);
      final name = newest.suggesterName;
      return name.isEmpty
          ? l.recipeSuggestionFromOneUnnamed
          : l.recipeSuggestionFromOne(name);
    }
    final until = RestoreOverwrittenVersion.dateLabel(
      l,
      newest.expiresAt,
      clock.now(),
    );
    return switch (newest.status) {
      RecipeSuggestionStatus.pending => l.recipeSuggestionMinePending(until),
      RecipeSuggestionStatus.accepted => l.recipeSuggestionMineAccepted,
      RecipeSuggestionStatus.dismissed => l.recipeSuggestionMineDismissed(
        until,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Filtered on every build, so a suggestion never outlives its 7 days on
    // a screen left open.
    final rows = RecipeSuggestionService.stillKept(_rows);
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    // A neutral notice: surface.base with a 1 px border.subtle outline and
    // the 8 px control radius, text.body (the conflict banner's anatomy,
    // Komponentark v1:755-757, without the danger colour: nothing is lost).
    // colorScheme.surface is surface.base (#F5F4ED / #17251D,
    // tokens.json:104-106), outlineVariant is border.subtle (#CCD1C2 /
    // rgba(245,244,237,0.18), tokens.json:124-127) and AppModeColors.textBody
    // is text.body (#37453A / #F5F4ED, tokens.json:58-60).
    return Padding(
      key: RecipeSuggestionNotice.noticeKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          side: BorderSide(
            color: cs.outlineVariant,
            width: AppDimensions.borderWidthStandard,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingModerate,
            AppDimensions.paddingS,
            AppDimensions.spacingXs,
            AppDimensions.paddingS,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _text(context, rows),
                  style: AppTextStyles.captionBase.copyWith(
                    color: AppModeColors.textBody(theme.brightness),
                  ),
                ),
              ),
              TextButton(
                key: RecipeSuggestionNotice.openKey,
                onPressed: () => RecipeSuggestionView.show(
                  context,
                  rows.first,
                  asOwner: widget.isOwner,
                ),
                child: Text(
                  widget.isOwner
                      ? l.recipeSuggestionSee
                      : l.recipeSuggestionSeeMine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

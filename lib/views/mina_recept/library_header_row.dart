/// Q6-16 = B (fas2/produktbeslut-2026-09-27b.json, after the prototype
/// 2026-09-27-prototyp-hem.html): Hem has no "Mina recept" top bar. The
/// greeting stands at the top, and "Välj", the ingredient search and the
/// grid/list toggle sit in the library's own header row, "Dina recept · N",
/// under the Ikväll band.
///
/// B-46 on Hem (beslutslogg.md:53; produktregler.md:870-874): "Välj" is the
/// multi-select entry "i toppfältet" on the six surfaces. On Hem it stands
/// in this row instead, the library's own header, since Hem has no top bar
/// (Q6-16 = B; B-46 is to get a line saying so). The rule behind it holds
/// here: the row changes content, not height. In selection mode the counter
/// replaces the heading and Avbryt comes first, with the same bulk actions
/// the selection bar has (produktregler.md:873, :876, :886-889; Skarmar v12
/// etapp 9 #flervalingang, #flerbar).
///
/// The drawing (Skarmar v12 del 1 #hemrecept :152-155) heads the library
/// with a 2 px ink rule over a 12 px label in text.secondary. Built so:
/// the rule is text.primary (colorScheme.onSurface: #24382C light, #F5F4ED
/// dark; tokens.json:54-56), the label captionBase in text.secondary
/// (onSurfaceVariant: #627061 / #93A48D; tokens.json:62-65). Interpretation:
/// the label at this spot is drawn as "Ditt bibliotek" (#hemrecept :153),
/// and the decision names no label ("bibliotekets rubrikrad"). The row says
/// "Dina recept · N": Hem's section label as drawn in Skarmar v12 del 4
/// :729, with the count the removed top bar carried.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

class MinaReceptLibraryHeader extends StatelessWidget {
  const MinaReceptLibraryHeader({
    required this.viewModel,
    required this.actions,
    super.key,
  });

  final RecipeListViewModel viewModel;

  /// The row's actions outside selection mode: "Välj" first, then the
  /// ingredient search and the grid/list toggle (minaReceptRootActions).
  final List<Widget> actions;

  static const rowKey = ValueKey('mina-recept-library-header');
  static const headingKey = ValueKey('mina-recept-library-heading');
  static const counterKey = ValueKey('mina-recept-library-counter');

  /// The drawn rule over the row (#hemrecept: border-top 2px).
  static const double ruleWidth = 2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final side = ButleryTopBar.sideMargin(context);
    final selecting = viewModel.isSelectionMode;
    // The actions take the ink the top bar gave them: text.primary, and an
    // action off at zero in the disabled role, never faded
    // (produktregler.md:876; tokens.json:71-74, :198).
    final foreground = cs.onSurface;

    final selectionRow = Row(
      children: [
        buildMinaReceptSelectionCancel(context, viewModel),
        const SizedBox(width: AppDimensions.spacingXs),
        Expanded(
          child: Semantics(
            header: true,
            // One line, scaled down rather than wrapped or cut: on a
            // 320 dp phone Avbryt and the actions leave the counter
            // little room, and a second line would make the row taller
            // than the one it replaces.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.bulkSelectedCount(viewModel.selectedCount),
                key: counterKey,
                maxLines: 1,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        ...buildMinaReceptSelectionActions(context, viewModel),
      ],
    );
    final libraryRow = Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              l10n.hemLibraryHeading(viewModel.recipes.length),
              key: headingKey,
              style: AppTextStyles.captionBase.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        ...actions,
      ],
    );

    return Padding(
      key: rowKey,
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        AppDimensions.spacingModerate,
        side - AppDimensions.spacingSm,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: foreground, width: ruleWidth),
          ),
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: foreground,
                disabledForegroundColor: AppModeColors.textDisabled(
                  cs.brightness,
                ),
              ).merge(IconButtonTheme.of(context).style),
            ),
            // One height in both modes, so entering selection does not move
            // the library (produktregler.md:873): both contents are laid
            // out and the row takes the taller one's height, at any text
            // size. The hidden one takes no pointer, focus or semantics.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  _Shown(visible: !selecting, child: libraryRow),
                  _Shown(visible: selecting, child: selectionRow),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps its child's size while hidden, and hides it from pointer, focus
/// and semantics.
class _Shown extends StatelessWidget {
  const _Shown({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: visible,
    maintainSize: true,
    maintainAnimation: true,
    maintainState: true,
    child: child,
  );
}

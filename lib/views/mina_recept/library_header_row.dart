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
/// The label is the shared
/// [SectionHeading] (Malin 2026-10-11: only this label on Hem takes heading
/// style). The row says "Dina recept · N": Hem's section label as drawn in
/// Skarmar v12 del 4 :729, with the count the removed top bar carried.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';
import 'package:butlery/widgets/common/buttons/butlery_icon_button_scope.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/section_heading.dart';

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
        const SizedBox(width: AppDimensions.space4),
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
                style: AppTextStyles.bodyBold.copyWith(
                  color: foreground,
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
          child: SectionHeading(
            l10n.hemLibraryHeading(viewModel.libraryTotal),
            key: headingKey,
          ),
        ),
        ...actions,
      ],
    );

    return Padding(
      key: rowKey,
      padding: EdgeInsetsDirectional.fromSTEB(
        side,
        AppDimensions.space12,
        side - AppDimensions.space8,
        0,
      ),
      child: ButleryIconButtonScope(
        foreground: foreground,
        // One height in both modes, so entering selection does not move
        // the library (produktregler.md): both contents are laid
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

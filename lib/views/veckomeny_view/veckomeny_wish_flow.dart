import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/viewmodels/menu_wishes_viewmodel.dart';
import 'package:butlery/widgets/menu/menu_wishes_sheet.dart';
import 'package:butlery/widgets/menu/veckomeny_quick_picks.dart';

/// BUT-2529: what the week menu does with wishes around a generation, and
/// the "Mina önskemål" sheet.
mixin VeckomenyWishFlow<T extends StatefulWidget> on State<T> {
  late final MenuWishesViewModel wishesVm = MenuWishesViewModel();

  /// The wish the prompt field still holds; null once the text was edited.
  MenuWishFill? get activeFill;

  /// A fill into the prompt field, as the chips make it.
  void pickWish(MenuWishFill fill);

  void disposeWishFlow() => wishesVm.dispose();

  /// A live menu has no prompt field to remember a wish from.
  bool get remembersWishes => true;

  Future<void> openWishesSheet() async {
    final fill = await showMenuWishesSheet(context, viewModel: wishesVm);
    if (fill == null) return;
    // Filling the field in the frame that pops the sheet failed a semantics
    // assertion in the widget tests; one frame later it does not.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) pickWish(fill);
  }

  /// Called once per successful generation from the prompt field. A built-in
  /// fill the user did not edit is neither remembered nor offered for saving:
  /// its dish count is worked out from the weekday, so it would be stale next
  /// week.
  Future<void> afterMenuGenerated({
    required String text,
    required bool pantryFocus,
  }) async {
    if (!remembersWishes) return;
    final fill = activeFill;
    final unchangedBuiltIn =
        fill != null &&
        fill.text == text.trim() &&
        (fill.sourceId == VeckomenyQuickPicks.fastSourceId ||
            fill.sourceId == VeckomenyQuickPicks.pantrySourceId);
    await wishesVm.rememberLast(
      text,
      pantryFocus: pantryFocus,
      unchangedBuiltIn: unchangedBuiltIn,
    );
    if (!mounted || unchangedBuiltIn) return;
    final clean = text.trim();
    if (clean.isEmpty || wishesVm.isSaved(clean) || wishesVm.isFull) return;
    SnackBarUtils.showInfo(
      context,
      context.l10n.menuWishSavePrompt,
      actionLabel: context.l10n.commonSave,
      onAction: () => unawaited(_saveWish(clean)),
    );
  }

  Future<void> _saveWish(String text) async {
    final ok = await wishesVm.save(text);
    if (!mounted) return;
    if (ok) {
      SnackBarUtils.showSuccess(context, context.l10n.menuWishSaved);
    } else {
      SnackBarUtils.showFailure(
        context,
        what: wishesVm.error ?? context.l10n.menuWishSaveFailed,
      );
    }
  }
}

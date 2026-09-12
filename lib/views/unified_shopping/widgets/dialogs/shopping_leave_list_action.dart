// lib/views/unified_shopping/widgets/dialogs/shopping_leave_list_action.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;

/// BUT-1718: confirm and perform "leave this shared list".
///
/// Its own file rather than a method on the sharing dialog, which is already
/// past the 500-line limit — and the caller is a `StatelessWidget` that pops
/// itself before this finishes, so the work cannot live in its `State` either.
/// It draws no layout of its own: the question goes through the shared confirm
/// dialog and the outcome through a snackbar.
///
/// Class 2 under `ui-conventions.md`: a confirm dialog and NO undo snackbar.
/// Coming back requires the owner to invite you again, so there is nothing to
/// offer an "Ångra" for, and the copy says so rather than implying otherwise.
class ShoppingLeaveListAction {
  /// Asks, then leaves. Returns true only when the server accepted it.
  ///
  /// [context] belongs to the caller and may unmount during the round-trip —
  /// the sharing dialog pops itself on tap — so the outcome is reported through
  /// the app-level navigator when it does. Dropping the message silently is the
  /// worse failure here: the list vanishes from the picker either way, and
  /// without a word the user cannot tell a completed departure from a refused
  /// one.
  /// [onConfirmed] runs after the user says yes and before the write — the
  /// caller's chance to close whatever is rendering the list. It must not run
  /// EARLIER: the confirm dialog is pushed on [context], so tearing that down
  /// first takes the question with it.
  static Future<bool> confirmAndLeave(
    BuildContext context,
    UnifiedShoppingList list, {
    VoidCallback? onConfirmed,
  }) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.shoppingLeaveList,
      message: context.l10n.shoppingLeaveListConfirm(list.name),
      confirmText: context.l10n.shoppingLeave,
      isDangerous: true,
    );
    if (confirmed != true) return false;

    if (context.mounted) onConfirmed?.call();

    final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    final left = await shoppingService.collaborative.leaveList(list.id);
    // Consume BEFORE any mounted check: the READ is what clears the parked
    // reason, so an early return would leave it to surface as the cause of
    // some later, unrelated failure.
    final reason = left ? null : shoppingService.consumeMutationError();

    // The mounted check is HERE rather than inside the reporter so the
    // async-gap lint can see it: the caller pops its own dialog above, so this
    // context is usually gone by now and the app navigator is the live one.
    _report(
      context.mounted ? context : appNavigatorKey.currentContext,
      left
          ? (l10n) => l10n.shoppingLeftList(list.name)
          : (l10n) => reason ?? l10n.shoppingCouldNotLeaveList,
      isError: !left,
    );
    return left;
  }

  static void _report(
    BuildContext? target,
    String Function(AppLocalizations l10n) buildMessage, {
    required bool isError,
  }) {
    if (target == null) return;

    final cs = Theme.of(target).colorScheme;
    ScaffoldMessenger.of(target).showSnackBar(
      SnackBar(
        content: Text(buildMessage(target.l10n)),
        backgroundColor: isError ? cs.error : cs.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

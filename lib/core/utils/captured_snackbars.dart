/// The ink snackbar shown on a messenger captured up front.
///
/// [CapturedSnackBars.capture] resolves the [ScaffoldMessengerState], the
/// strings and the accessibility setting while the [BuildContext] is alive.
/// The `show` methods then touch no context, so they are safe after
/// `Navigator.pop`, after an `await`, or from a sheet's callback once the
/// sheet is gone. [SnackBarUtils] shows its confirmations, warnings and
/// failures through this class.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';

/// Snackbars for a messenger captured while its context was alive.
class CapturedSnackBars {
  CapturedSnackBars._(this._messenger, this._l10n, this._assistive);

  /// Resolves everything the `show` methods need from [context]. Without a
  /// ScaffoldMessenger every `show` is a no-op.
  factory CapturedSnackBars.capture(BuildContext context) {
    return CapturedSnackBars._(
      ScaffoldMessenger.maybeOf(context),
      context.l10n,
      MediaQuery.maybeAccessibleNavigationOf(context) ?? false,
    );
  }

  final ScaffoldMessengerState? _messenger;
  final AppLocalizations _l10n;

  /// Whether assistive technology drives navigation. A screen-reader user is
  /// not raced by a timer (PQ-21 = A, produktbeslut 2026-09-23).
  final bool _assistive;

  /// A confirmation: something happened and nothing went wrong.
  ///
  /// Q4-01 = B (produktbeslut 2026-09-24): without an action of its own it
  /// carries "Stäng" (content-style-guide.md § Felmeddelandets struktur)
  /// and still closes by itself after [duration]. A caller's own action
  /// replaces "Stäng" and stays until the user acts. [showCloseButton] true
  /// keeps the "Stäng" notice on screen until it is closed; false shows no
  /// action at all.
  void showConfirmation(
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    bool? showCloseButton,
  }) {
    if (actionLabel != null && onAction != null) {
      show(
        message,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      );
      return;
    }
    if (showCloseButton == false) {
      show(message, duration: duration);
      return;
    }
    show(
      message,
      duration: duration,
      actionLabel: _l10n.commonClose,
      // "Stäng" only closes: the action itself hides the snackbar.
      onAction: () {},
      persist: showCloseButton == true || _assistive,
    );
  }

  /// A failure, in the three parts of content-style-guide.md
  /// § Felmeddelandets struktur: [what] happened, what was [preserved] when
  /// something was at stake, and the [action]. Without an action it is
  /// "Stäng", never "OK". It has the alert role and stays until the user
  /// acts.
  void showFailure({
    required String what,
    String? preserved,
    FailureAction? action,
    Duration duration = const Duration(seconds: 5),
  }) {
    show(
      SnackBarUtils.failureMessage(what, preserved),
      duration: duration,
      actionLabel: action?.label(_l10n) ?? _l10n.commonClose,
      onAction: action?.onPressed ?? () {},
      alert: true,
    );
  }

  /// The one builder of the ink snackbar (Komponentark v1:745-750).
  ///
  /// [alert] gives it the alert role, for a failure. [persist] left out means
  /// a snackbar with an action stays until the user acts. [jumpQueue] removes
  /// whatever is on screen or queued first, so this one is at the head of the
  /// queue and its [duration] starts now.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    String message, {
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    bool alert = false,
    bool? persist,
    bool jumpQueue = false,
  }) {
    final messenger = _messenger;
    if (messenger == null || !messenger.mounted) {
      AppLogger.warning('Snackbar had no mounted ScaffoldMessenger: $message');
      return null;
    }
    if (jumpQueue) {
      messenger
        ..clearSnackBars()
        ..removeCurrentSnackBar();
    }
    var acted = false;
    final action = (actionLabel != null && onAction != null)
        ? InkSnackBarAction(
            label: actionLabel,
            onPressed: () {
              if (acted) return;
              acted = true;
              messenger.hideCurrentSnackBar(
                reason: SnackBarClosedReason.action,
              );
              onAction();
            },
          )
        : null;
    final Widget content = InkSnackBar(message: message, action: action);
    return messenger.showSnackBar(
      SnackBar(
        // An error is an alert, everything else a status (Butlery
        // tillganglighetshandoff.dc.html, "status (fel: alert)"). The
        // SnackBar's own node is the live region; Flutter forbids a role and
        // a live region on one node, so the role is a node of its own.
        content: alert
            ? Semantics(
                container: true,
                role: SemanticsRole.alert,
                child: content,
              )
            : content,
        padding: InkSnackBar.padding,
        duration: duration,
        // The action sits in the content, so Flutter's default
        // (`persist ?? action != null`) no longer sees it.
        persist: persist ?? action != null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

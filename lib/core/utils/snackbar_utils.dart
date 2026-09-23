/// Snackbar utilities for standardized user feedback (success, error, warning, info).
///
/// Every snackbar has one look: the ink snackbar of Komponentark v1:745-750
/// (produktbeslut PQ-09 = A, 2026-09-23). The surface, text colour, radius
/// and dark-mode edge come from the global snackBarTheme
/// (lib/theme/components/feedback_themes.dart); this file builds the
/// content: the message and, when there is one, the action in light saffron
/// with its own paper focus ring. The action is never "OK" (Komponentark
/// v1:750): Ångra, Försök igen, Öppna inställningar or Stäng.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/components/feedback_themes.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/utils/undo_window.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// Centralized snackbar utilities for consistent user feedback throughout the application.
class SnackBarUtils {
  // Prevent instantiation
  SnackBarUtils._();

  /// A confirmation. The ink look carries no status colour (Komponentark
  /// v1:300, "Aldrig fylld yta i statusfärg"); the message says what
  /// happened.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        duration: duration ?? const Duration(seconds: 5),
        actionLabel:
            actionLabel ?? (showCloseButton ? context.l10n.commonClose : null),
        onAction: onAction ?? (showCloseButton ? () => hide(context) : null),
      );

      AppLogger.debug('Success snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show success snackbar: $e');
    }
  }

  static void showSuccessWithAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
  }) {
    showSuccess(
      context,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// An error. With [showCloseButton] the action is "Stäng", never "OK"
  /// (Komponentark v1:750).
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = true,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        duration: duration ?? const Duration(seconds: 5),
        actionLabel:
            actionLabel ?? (showCloseButton ? context.l10n.commonClose : null),
        onAction: onAction ?? (showCloseButton ? () => hide(context) : null),
      );

      AppLogger.debug('Error snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show error snackbar: $e');
    }
  }

  static void showErrorWithRetry(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
    Duration? duration,
  }) {
    showError(
      context,
      message,
      actionLabel: context.l10n.commonRetry,
      onAction: onRetry,
      duration: duration,
    );
  }

  /// No connection. The action is "Försök igen" with [onRetry], else
  /// "Stäng" (Komponentark v1:750, never "OK").
  static void showNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
    Duration? duration,
  }) {
    showError(
      context,
      context.l10n.snackbarNoInternet,
      actionLabel: onRetry != null
          ? context.l10n.commonRetry
          : context.l10n.commonClose,
      onAction: onRetry ?? (() => hide(context)),
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        duration: duration ?? const Duration(seconds: 4),
        actionLabel:
            actionLabel ?? (showCloseButton ? context.l10n.commonClose : null),
        onAction: onAction ?? (showCloseButton ? () => hide(context) : null),
      );

      AppLogger.debug('Warning snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show warning snackbar: $e');
    }
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        duration: duration ?? const Duration(seconds: 4),
        actionLabel:
            actionLabel ?? (showCloseButton ? context.l10n.commonClose : null),
        onAction: onAction ?? (showCloseButton ? () => hide(context) : null),
      );

      AppLogger.debug('Info snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show info snackbar: $e');
    }
  }

  /// Work in progress: the message with the plate line under it in the
  /// snackbar's own text colour, never a spinner (produktregler.md:163,
  /// B-18). Interpretation: the drawing has no loading snackbar; the line
  /// takes the in-button form, in paper on ink.
  static void showLoading(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    try {
      final theme = Theme.of(context).snackBarTheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            label: message,
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message, style: theme.contentTextStyle),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ButtonPlateLine(color: theme.contentTextStyle?.color),
                ],
              ),
            ),
          ),
          padding: InkSnackBar.padding,
          duration: duration ?? const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      AppLogger.debug('Loading snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show loading snackbar: $e');
    }
  }

  /// A snackbar with a caller's message and action.
  ///
  /// [backgroundColor], [textColor] and [icon] no longer change anything:
  /// every snackbar is the ink snackbar (PQ-09 = A). They stay in the
  /// signature so the existing call sites keep compiling; package 7 removes
  /// them.
  static void showCustom(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
    bool showCloseButton = false,
  }) {
    try {
      _showSnackBar(
        context,
        message: message,
        duration: duration ?? const Duration(seconds: 3),
        actionLabel:
            actionLabel ?? (showCloseButton ? context.l10n.commonClose : null),
        onAction: onAction ?? (showCloseButton ? () => hide(context) : null),
      );

      AppLogger.debug('Custom snackbar shown: $message');
    } catch (e) {
      AppLogger.error('Failed to show custom snackbar: $e');
    }
  }

  /// BUT-1360: when the device is offline, replace a write's normal success
  /// feedback with a "saved locally, will sync" hint so the user knows the
  /// change is queued (Firestore applied it to the local cache but it hasn't
  /// reached the server). Returns true when the offline hint was shown, so the
  /// caller can skip its plain success snackbar; returns false when online (or
  /// the OfflineService isn't available), leaving normal feedback to the caller.
  ///
  /// Call this ONLY on a write's SUCCESS branch — a successful local write while
  /// offline is genuinely queued. A thrown exception is a real failure
  /// (permission/validation/etc.); `isOnline == false` does not prove it was a
  /// queued write, so error/catch branches must surface the real error instead.
  ///
  /// Known limitation (web): the Firestore JS SDK does not resolve a write's
  /// Future until server-ack, so a caller that `await`s the write while
  /// web-offline never reaches its success branch — and this hint won't fire —
  /// until reconnect. The hint fires reliably on mobile (the primary offline
  /// scenario, where writes resolve against the local cache immediately);
  /// web-offline hint fidelity is the accepted gap.
  static bool showPendingSyncIfOffline(BuildContext context) {
    final offline = ServiceLocator.tryGet<OfflineService>();
    if (offline != null && !offline.isOnline) {
      showInfo(context, context.l10n.pendingSyncOffline);
      return true;
    }
    return false;
  }

  static void hide(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppLogger.debug('Snackbar hidden');
    } catch (e) {
      AppLogger.error('Failed to hide snackbar: $e');
    }
  }

  static void clearAll(BuildContext context) {
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      AppLogger.debug('All snackbars cleared');
    } catch (e) {
      AppLogger.error('Failed to clear snackbars: $e');
    }
  }

  /// Show error with a user-friendly message derived from the exception.
  ///
  /// Logs the technical error and shows a categorized Swedish message.
  static void showUserFriendlyError(
    BuildContext context,
    dynamic error, {
    String? contextAction,
    VoidCallback? onRetry,
  }) {
    AppLogger.error('${contextAction ?? 'Operation'} failed', error);
    final message = userFriendlyMessage(context, error);
    if (onRetry != null) {
      showErrorWithRetry(context, message, onRetry: onRetry);
    } else {
      showError(context, message);
    }
  }

  /// Convert a technical error/exception to a user-friendly Swedish message.
  /// Delegates to [sanitizeErrorForUser] for consistent categorization.
  static String userFriendlyMessage(BuildContext context, dynamic error) {
    return sanitizeErrorForUser(error);
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
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
    messenger.showSnackBar(
      SnackBar(
        content: InkSnackBar(message: message, action: action),
        padding: InkSnackBar.padding,
        duration: duration ?? const Duration(seconds: 3),
        // The action sits in the content, so Flutter's default
        // (`persist ?? action != null`) no longer sees it. A snackbar with
        // an action stays until the user acts, as it did with SnackBarAction.
        persist: action != null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// The one undo primitive (produktregler.md:125-140, § 2.4).
  ///
  /// Class 1 (`add`, `delete`: data disappears) calls this; class 3 (`update`,
  /// `check`, `assign`, `reorder`: a state flips) calls nothing at all on
  /// success. The window is always [kUndoWindow] (7 s) and the action label is
  /// always `commonUndo` ("Ångra"): neither can be passed in, which is how the
  /// hand-rolled copies drifted apart to 4, 5 and 7 seconds.
  ///
  /// Use [UndoSnackBar.capture] instead when the snackbar must be shown after
  /// [context] may be gone (a dismissed row, a popped route).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    UndoSnackBarLook look = UndoSnackBarLook.plain,
  }) {
    return UndoSnackBar.capture(
      context,
    ).show(message, onUndo: onUndo, look: look);
  }

  /// [showUndo] for a delete whose commit waits for the undo window.
  ///
  /// [onCommit] runs once the snackbar has closed without Ångra, never on a
  /// timer of its own. See [UndoSnackBar.showDeferred].
  static void showUndoDeferred(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    required FutureOr<void> Function() onCommit,
    UndoSnackBarLook look = UndoSnackBarLook.plain,
  }) {
    UndoSnackBar.capture(context).showDeferred(
      message,
      onUndo: onUndo,
      onCommit: onCommit,
      look: look,
    );
  }
}

/// The content of the ink snackbar (Komponentark v1:745-750): the message,
/// and the action to its right.
///
/// The surface is the snackBarTheme's; the message takes its
/// contentTextStyle. The action stands on ink in both modes, so its focus
/// ring is paper in both ([FocusRingSurface] dark, tokens.json focusRing
/// dark #F5F4ED; Komponentark v1:747, `outline:2px solid #F5F4ED;
/// outline-offset:3px`).
class InkSnackBar extends StatelessWidget {
  const InkSnackBar({required this.message, this.action, super.key});

  /// What happened, for example "Varan togs bort."
  final String message;

  /// The one action, or null.
  final InkSnackBarAction? action;

  /// Komponentark v1:746: `padding:12px 14px`. 14 is not on the spacing
  /// scale (tokens.json space.scale); interpretation: 12 on the scale's 12
  /// vertically and 16 horizontally.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: AppDimensions.space16,
    vertical: AppDimensions.space12,
  );

  /// Komponentark v1:746: `gap:12px` between the message and the action.
  static const double gap = AppDimensions.space12;

  /// The message. The key is for tests, not identity.
  static const Key messageKey = ValueKey<String>('inkSnackBar.message');

  @override
  Widget build(BuildContext context) {
    final style =
        Theme.of(context).snackBarTheme.contentTextStyle ??
        FeedbackThemes.inkSnackBarMessageStyle;
    final action = this.action;
    return Row(
      children: [
        Expanded(
          child: Text(message, key: messageKey, style: style),
        ),
        if (action != null) ...[
          const SizedBox(width: gap),
          action,
        ],
      ],
    );
  }
}

/// The ink snackbar's action: 13/700 in light saffron (text accent on ink,
/// #E09D50, 5.43:1 on surface.ink; Komponentark v1:747), at least 48 dp
/// tall, with its own paper focus ring.
class InkSnackBarAction extends StatelessWidget {
  const InkSnackBarAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Ångra, Försök igen, Öppna inställningar or Stäng. Never "OK".
  final String label;

  /// What the action does. The caller closes the snackbar.
  final VoidCallback onPressed;

  /// The action. The key is for tests, not identity.
  static const Key actionKey = ValueKey<String>('inkSnackBar.action');

  /// Komponentark v1:747: `border-radius:4px`. Interpretation: 4 is the
  /// spacing scale's smallest step; the radius scale has no 4.
  static const double radius = AppDimensions.space4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).snackBarTheme;
    return FocusRingSurface(
      brightness: Brightness.dark,
      child: TextButton(
        key: actionKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: theme.actionTextColor,
          textStyle: FeedbackThemes.inkSnackBarActionStyle,
          minimumSize: const Size(
            AppDimensions.minTouchTarget,
            AppDimensions.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// How an undo snackbar looks. Both values give the ink snackbar
/// (Komponentark v1:745-750, PQ-09 = A): the app never shows two snackbar
/// looks at once. The value stays so the call sites keep compiling; it is
/// removed in package 7.
enum UndoSnackBarLook {
  /// The ink snackbar.
  plain,

  /// The ink snackbar. Used to be the green confirmation look.
  confirmation,
}

/// An undo snackbar whose context lookups are done up front.
///
/// [capture] resolves the [ScaffoldMessengerState], the `commonUndo` label and
/// the accessibility setting while [BuildContext] is still alive. [show] then
/// touches no context, so it is safe from `Dismissible.onDismissed` (which
/// fires after the row's element is deactivated) or after `Navigator.pop`.
class UndoSnackBar {
  UndoSnackBar._(this._messenger, this._undoLabel, this._persist);

  /// Resolves everything [show] needs from [context]. A missing
  /// ScaffoldMessenger makes [show] a no-op, as `messenger?.showSnackBar` did;
  /// [showDeferred] then rolls the optimistic change back instead.
  factory UndoSnackBar.capture(BuildContext context) {
    return UndoSnackBar._(
      ScaffoldMessenger.maybeOf(context),
      context.l10n.commonUndo,
      MediaQuery.maybeAccessibleNavigationOf(context) ?? false,
    );
  }

  final ScaffoldMessengerState? _messenger;
  final String _undoLabel;

  /// Whether the snackbar stays until the user acts.
  ///
  /// When assistive technology drives navigation
  /// (`MediaQuery.accessibleNavigation`), the snackbar stays until the user
  /// acts: presses Ångra or swipes it away (produktbeslut PQ-21 = A,
  /// 2026-09-23; option A as decided: "Står kvar tills man agerar när
  /// skärmläsare är på, 7 sekunder för alla andra"). Leaving the view also
  /// closes it: SnackbarRouteObserver calls `clearSnackBars` on every push,
  /// pop and replace, which hides the current snackbar (Grafisk manual
  /// v6:647, "tills vyn lämnas"). For everyone else the window is
  /// [kUndoWindow] and it pauses and extends ([UndoWindowTimer]).
  final bool _persist;

  /// Shows [message] with an "Ångra" action. Returns the controller so a
  /// deferred-commit caller can await `closed`.
  ///
  /// The window is [kUndoWindow] (7 s, produktregler.md:131-132), and it is
  /// not hard (Grafisk manual v6:647): it pauses while the snackbar has
  /// focus, is hovered or has the screen reader's focus, and every new
  /// interaction with it starts the full window again. Flutter's own timer
  /// cannot pause, so the snackbar persists and [UndoWindowTimer] closes it
  /// with [SnackBarClosedReason.timeout].
  ///
  /// Whatever snackbar is on screen or queued is removed first, so this one
  /// is always at the head of the messenger's queue. That matters twice.
  /// A queued snackbar's window only starts once it reaches the head, and
  /// `ScaffoldMessengerState.clearSnackBars` (called on every route change by
  /// SnackbarRouteObserver) drops queued snackbars without ever completing
  /// their `closed`, which would strand a deferred commit. The head is always
  /// closed properly, and closing it is what commits its delete.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    String message, {
    required VoidCallback onUndo,
    UndoSnackBarLook look = UndoSnackBarLook.plain,
  }) {
    final messenger = _messenger;
    if (messenger == null) return null;
    AppLogger.debug('Undo snackbar shown: $message');
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    var acted = false;
    final window = UndoWindowTimer(
      window: kUndoWindow,
      onTimeout: () {
        if (!messenger.mounted) return;
        messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
      },
    );
    final controller = messenger.showSnackBar(
      SnackBar(
        content: UndoWindowRegion(
          window: window,
          child: InkSnackBar(
            message: message,
            action: InkSnackBarAction(
              label: _undoLabel,
              onPressed: () {
                if (acted) return;
                acted = true;
                window.close();
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
                onUndo();
              },
            ),
          ),
        ),
        padding: InkSnackBar.padding,
        duration: kUndoWindow,
        // Always persist: the window is UndoWindowTimer's, not Flutter's.
        persist: true,
        onVisible: _persist ? null : window.start,
        behavior: SnackBarBehavior.floating,
      ),
    );
    unawaited(controller.closed.then((_) => window.close()));
    return controller;
  }

  /// Shows the undo snackbar and runs [onCommit] once it has closed, unless
  /// Ångra was pressed.
  ///
  /// The commit is driven by the snackbar's own lifecycle, so Ångra can never
  /// be pressed after the commit: it lands after the snackbar has left the
  /// screen (timeout, swipe, or replaced by the next snackbar). When no
  /// ScaffoldMessenger is found, no undo can be offered, so [onUndo] rolls
  /// the optimistic change back instead of deleting without one.
  void showDeferred(
    String message, {
    required VoidCallback onUndo,
    required FutureOr<void> Function() onCommit,
    UndoSnackBarLook look = UndoSnackBarLook.plain,
  }) {
    var undone = false;
    final controller = show(
      message,
      look: look,
      onUndo: () {
        if (undone) return;
        undone = true;
        onUndo();
      },
    );
    if (controller == null) {
      AppLogger.error(
        'Undo snackbar had no ScaffoldMessenger; rolled back: $message',
      );
      undone = true;
      onUndo();
      return;
    }
    unawaited(
      controller.closed.then((reason) async {
        if (undone || reason == SnackBarClosedReason.action) return;
        await onCommit();
      }),
    );
  }
}

/// The undo window: [window] long, pausable and extendable (Grafisk manual
/// v6:647).
///
/// It starts when the snackbar is on screen ([start]). [pause] stops it
/// while the snackbar has focus, is hovered or has the screen reader's
/// focus; [resume] starts the full window again, and so does [extend] on
/// every new interaction. Interpretation: "förlängs vid varje ny
/// interaktion" is read as "the full window starts again", not as a fixed
/// number of seconds added. [close] ends it for good.
///
/// The window only runs while its content is on screen. Every mounted
/// [UndoWindowRegion] counts once ([attach] / [detach]); Flutter shows one
/// snackbar on every root Scaffold at once (a popping route and the view
/// below it), so the window runs while at least one copy is mounted and
/// nothing holds it. No timer outlives the snackbar or its messenger.
class UndoWindowTimer {
  UndoWindowTimer({required this.window, required this.onTimeout});

  /// The window: kUndoWindow.
  final Duration window;

  /// Closes the snackbar with SnackBarClosedReason.timeout.
  final VoidCallback onTimeout;

  Timer? _timer;
  bool _started = false;
  // Interaction holds: focus, hover, screen-reader focus.
  int _pauses = 0;
  // Copies of the content on screen. The window waits for the first.
  int _mounted = 0;
  bool _closed = false;

  bool get _held => _pauses > 0 || _mounted == 0;

  /// Whether the window is running.
  bool get isRunning => _timer?.isActive ?? false;

  /// Whether the window has ended, by timeout or otherwise.
  bool get isClosed => _closed;

  /// Starts the window once the snackbar is visible. Later calls do nothing.
  void start() {
    if (_started || _closed) return;
    _started = true;
    _restart();
  }

  /// Stops the window while something holds the snackbar. Pauses nest, so
  /// focus and hover together need both to end.
  void pause() {
    if (_closed) return;
    _pauses++;
    _timer?.cancel();
    _timer = null;
  }

  /// Ends one pause. When nothing holds the window any more, the full
  /// window starts again.
  void resume() {
    if (_closed || _pauses == 0) return;
    _pauses--;
    if (!_held) _restart();
  }

  /// A new interaction: the full window starts again, unless held.
  void extend() {
    if (_closed || _held) return;
    _restart();
  }

  /// One copy of the content is on screen. The first copy lets the window
  /// run.
  void attach() {
    if (_closed) return;
    _mounted++;
    if (_mounted == 1 && !_held) _restart();
  }

  /// One copy of the content left the screen. When none is left, the window
  /// stops.
  void detach() {
    if (_closed || _mounted == 0) return;
    _mounted--;
    if (_mounted == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Ends the window for good.
  void close() {
    _closed = true;
    _timer?.cancel();
    _timer = null;
  }

  void _restart() {
    if (!_started || _closed || _held) return;
    _timer?.cancel();
    _timer = Timer(window, () {
      if (_closed) return;
      close();
      onTimeout();
    });
  }
}

/// Feeds the undo snackbar's focus, hover, screen-reader focus and taps to
/// its [UndoWindowTimer].
class UndoWindowRegion extends StatefulWidget {
  const UndoWindowRegion({
    required this.window,
    required this.child,
    super.key,
  });

  /// The window this snackbar's interactions pause and extend.
  final UndoWindowTimer window;

  /// The snackbar content.
  final Widget child;

  @override
  State<UndoWindowRegion> createState() => _UndoWindowRegionState();
}

class _UndoWindowRegionState extends State<UndoWindowRegion> {
  bool _focused = false;
  bool _hovered = false;
  bool _a11yFocused = false;

  @override
  void initState() {
    super.initState();
    widget.window.attach();
  }

  @override
  void dispose() {
    // Release every hold this region took, then take this copy off the
    // count: nothing runs for a snackbar that is not on screen.
    if (_focused) widget.window.resume();
    if (_hovered) widget.window.resume();
    if (_a11yFocused) widget.window.resume();
    widget.window.detach();
    super.dispose();
  }

  void _set(bool was, bool now) {
    if (was == now) return;
    now ? widget.window.pause() : widget.window.resume();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) {
        _set(_focused, has);
        _focused = has;
      },
      child: MouseRegion(
        onEnter: (_) {
          _set(_hovered, true);
          _hovered = true;
        },
        onExit: (_) {
          _set(_hovered, false);
          _hovered = false;
        },
        child: Listener(
          onPointerDown: (_) => widget.window.extend(),
          child: Semantics(
            onDidGainAccessibilityFocus: () {
              _set(_a11yFocused, true);
              _a11yFocused = true;
            },
            onDidLoseAccessibilityFocus: () {
              _set(_a11yFocused, false);
              _a11yFocused = false;
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Extension methods for convenient snackbar usage
extension SnackBarExtensions on BuildContext {
  void showSuccess(String message, {Duration? duration}) {
    SnackBarUtils.showSuccess(this, message, duration: duration);
  }

  void showError(String message, {Duration? duration}) {
    SnackBarUtils.showError(this, message, duration: duration);
  }

  void showWarning(String message, {Duration? duration}) {
    SnackBarUtils.showWarning(this, message, duration: duration);
  }

  void showInfo(String message, {Duration? duration}) {
    SnackBarUtils.showInfo(this, message, duration: duration);
  }

  void hideSnackBar() {
    SnackBarUtils.hide(this);
  }
}

/// Snackbar configuration constants
/// UI Redesign: default duration is 5 seconds per interview.
class SnackBarConfig {
  static const Duration shortDuration = Duration(seconds: 3);
  static const Duration normalDuration = Duration(seconds: 5); // UI Redesign
  static const Duration longDuration = Duration(seconds: 7);
  static const Duration persistentDuration = Duration(seconds: 10);

  static const EdgeInsets defaultMargin = EdgeInsets.all(
    AppDimensions.spacingMd,
  );
  static const double defaultBorderRadius = AppDimensions.borderRadius8;
}

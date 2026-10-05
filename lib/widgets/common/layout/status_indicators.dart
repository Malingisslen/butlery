// lib/widgets/common/layout/status_indicators.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Status indicators for app state display
/// This module provides widgets for displaying app status like
/// offline indicators and connection status.
class StatusIndicators {
  /// Offline banner. See [OfflineIndicator] for [pendingCount] and [onTap].
  static Widget offlineIndicator({int? pendingCount, VoidCallback? onTap}) {
    return OfflineIndicator(pendingCount: pendingCount, onTap: onTap);
  }

  /// Small offline status icon for app bar
  static Widget offlineStatusIcon() {
    return const OfflineStatusIcon();
  }
}

/// The offline banner.
///
/// Anatomy: a borderless tinted surface (surface.tint.warning, B83-2 = A), a
/// wifi-off glyph in text.warning, and a bold 12.5 title in text.primary. It is a banner, never a dialog or an
/// illustration, and the glyph is wifi-off, never the cloche
/// (produktregler.md:162). The title is a single line, as in Skarmar v12
/// del 4 #hemoffline: "Ingen anslutning", followed by " · N ändringar väntar"
/// only when [pendingCount] is above zero (flows-roles-budget.md:111).
///
/// With [onTap] the banner is a control (produktregler.md:300): button
/// semantics, a chevron and a 48 dp floor. Without it, it is a status and
/// nothing is tappable.
///
/// Screen readers hear it once per offline/online transition, not
/// continuously, and the glyph is decorative (tillganglighetshandoff:177).
/// Only a banner on the current route
/// announces, and only one banner announces per transition app-wide.
///
/// Uses ServiceLocator to access OfflineService directly so it works in any
/// route without requiring a ChangeNotifierProvider ancestor.
class OfflineIndicator extends StatefulWidget {
  /// How many changes wait to be sent. Null or zero shows the title only.
  final int? pendingCount;

  /// Where the banner leads (the queue view). Null keeps it a plain status.
  final VoidCallback? onTap;

  const OfflineIndicator({super.key, this.pendingCount, this.onTap});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  /// Set by the first banner that announces a transition and cleared after
  /// the current notification round, so the other listeners notified in the
  /// same round stay quiet.
  static bool _transitionAnnounced = false;

  /// Null before a signed-in user's services exist: the e-mail
  /// verification screen can show before then (BUT-2182). The banner then
  /// shows nothing.
  OfflineService? _offlineService;
  bool _wasOffline = false;
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(OfflineIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attach();
  }

  void _attach() {
    if (_offlineService != null) return;
    final service = ServiceLocator.tryGet<OfflineService>();
    if (service == null) return;
    _offlineService = service..addListener(_onConnectivityChanged);
    _wasOffline = !service.isOnline;
  }

  @override
  void dispose() {
    _offlineService?.removeListener(_onConnectivityChanged);
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  void _onConnectivityChanged() {
    final isOnline = _offlineService?.isOnline ?? true;
    final wasOffline = _wasOffline;
    _wasOffline = !isOnline;
    // OfflineService also notifies for other changes (the current user).
    // Only a change of connectivity is a transition.
    if (!mounted || isOnline != wasOffline) return;
    if (isOnline) {
      _backOnlineTimer?.cancel();
      _backOnlineTimer = Timer(AppDimensions.snackbarDuration, () {
        if (mounted) setState(() => _showBackOnline = false);
      });
    } else {
      _backOnlineTimer?.cancel();
    }
    setState(() => _showBackOnline = isOnline);
    _announceTransition(isOnline);
  }

  void _announceTransition(bool isOnline) {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    if (_transitionAnnounced) return;
    _transitionAnnounced = true;
    scheduleMicrotask(() => _transitionAnnounced = false);
    final message = isOnline
        ? context.l10n.indicatorBackOnline
        : _offlineLabel(context, spoken: true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  String _offlineLabel(BuildContext context, {required bool spoken}) {
    final l10n = context.l10n;
    final title = l10n.indicatorOfflineMode;
    final count = widget.pendingCount ?? 0;
    if (count <= 0) return title;
    final pending = l10n.offlineBannerPending(count);
    return spoken
        ? l10n.offlineBannerWithPendingA11y(title, pending)
        : l10n.offlineBannerWithPending(title, pending);
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = !(_offlineService?.isOnline ?? true);
    final cs = Theme.of(context).colorScheme;

    Widget? banner;
    if (isOffline) {
      banner = _BannerFrame(
        key: const ValueKey('offline'),
        // text.warning (tokens.json): the glyph carries the kind, as the
        // dark tints are all the same colour.
        tint: context.modeColors.surfaceTintWarning,
        accent: AppModeColors.textWarning(cs.brightness),
        icon: ButleryIcons.wifiOff,
        title: _offlineLabel(context, spoken: false),
        semanticsLabel: _offlineLabel(context, spoken: true),
        onTap: widget.onTap,
      );
    } else if (_showBackOnline) {
      banner = _BannerFrame(
        key: const ValueKey('online'),
        // text.success (colorScheme.tertiary): circle-check is the "klart"
        // status glyph (Komponentark v1:764).
        tint: context.modeColors.surfaceTintSuccess,
        accent: cs.tertiary,
        icon: ButleryIcons.circleCheck,
        title: context.l10n.indicatorBackOnline,
        semanticsLabel: context.l10n.indicatorBackOnline,
      );
    }

    return AnimatedSwitcher(
      duration: AppDimensions.animationDurationCommon,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1.0,
        child: child,
      ),
      child: banner ?? const SizedBox.shrink(),
    );
  }
}

/// One banner: a [tint] surface without a border, a glyph in [accent], one
/// title line.
class _BannerFrame extends StatelessWidget {
  const _BannerFrame({
    required this.tint,
    required this.accent,
    required this.icon,
    required this.title,
    required this.semanticsLabel,
    this.onTap,
    super.key,
  });

  final Color tint;
  final Color accent;
  final IconData icon;
  final String title;
  final String semanticsLabel;
  final VoidCallback? onTap;

  static const _radius = BorderRadius.all(
    Radius.circular(AppDimensions.radiusControl),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tappable = onTap != null;

    Widget content = Row(
      children: [
        ExcludeSemantics(
          child: ButleryIcon(
            icon,
            color: accent,
            size: AppDimensions.iconSize18,
          ),
        ),
        const SizedBox(width: AppDimensions.space8),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        if (tappable) ...[
          const SizedBox(width: AppDimensions.space8),
          ExcludeSemantics(
            child: ButleryIcon(
              ButleryIcons.chevronRight,
              color: accent,
              size: AppDimensions.iconSize18,
            ),
          ),
        ],
      ],
    );

    content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: tappable ? AppDimensions.minTouchTarget : 0,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space12,
          vertical: AppDimensions.paddingM,
        ),
        child: content,
      ),
    );

    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: _radius,
      ),
      child: tappable
          ? Material(
              type: MaterialType.transparency,
              // One step darker than the warning tint (R8-2 = A): raised in
              // light mode; in dark mode the tint is raised itself, so the
              // step on raised.
              child: PressFill(
                surface: Theme.of(context).brightness == Brightness.dark
                    ? PressSurface.raised
                    : PressSurface.base,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: _radius,
                  child: content,
                ),
              ),
            )
          : content,
    );

    if (tappable) {
      box = ButleryFocusRing(borderRadius: _radius, child: box);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingLg,
        vertical: AppDimensions.spacingSm,
      ),
      child: Semantics(
        container: true,
        role: tappable ? null : SemanticsRole.status,
        button: tappable,
        onTap: onTap,
        label: semanticsLabel,
        excludeSemantics: true,
        child: box,
      ),
    );
  }
}

/// Small offline status icon for app bar: wifi-off in text.warning
/// (Komponentark v1:764; tokens.json:92-95).
/// Uses ServiceLocator to access OfflineService directly so it works in any
/// route without requiring a ChangeNotifierProvider ancestor.
class OfflineStatusIcon extends StatelessWidget {
  const OfflineStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final offlineService = ServiceLocator.get<OfflineService>();

    return ListenableBuilder(
      listenable: offlineService,
      builder: (context, child) {
        if (offlineService.isOnline) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsetsDirectional.only(
            end: AppDimensions.space4,
          ),
          child: ButleryIcon(
            ButleryIcons.wifiOff,
            color: AppModeColors.textWarning(Theme.of(context).brightness),
            size: AppDimensions.iconSizeAction,
          ),
        );
      },
    );
  }
}

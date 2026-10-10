import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/version_info.dart';
import 'package:butlery/services/whats_new/whats_new_catalog.dart';
import 'package:butlery/services/whats_new/whats_new_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/utils/shared_preferences_safe.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Shows the sheet once after an update that has catalog entries. Never throws
/// and shows nothing when storage or the app version is unavailable.
Future<void> showWhatsNewIfDue(
  BuildContext context, {
  String? appVersion,
  List<WhatsNewRelease> catalog = whatsNewReleases,
}) async {
  try {
    final version = appVersion ?? VersionInfo.appVersion;
    if (version == 'unknown') return;
    final prefs = await tryGetSharedPreferences(logTag: 'WhatsNew');
    if (prefs == null) return;
    final releases = await WhatsNewService(
      prefs: prefs,
      currentVersion: version,
      catalog: catalog,
    ).releasesToShow();
    if (releases.isEmpty || !context.mounted) return;
    await showWhatsNewSheet(context, releases);
  } catch (e) {
    AppLogger.warning('WhatsNew: skipped ($e)');
  }
}

/// [releases] newest first. A tapped item closes the sheet and opens its route
/// on the navigator below, so Back returns to where the user was.
Future<void> showWhatsNewSheet(
  BuildContext context,
  List<WhatsNewRelease> releases,
) {
  final navigator = Navigator.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (sheetContext) => WhatsNewSheet(
      releases: releases,
      onOpenRoute: (route) {
        Navigator.of(sheetContext).pop();
        unawaited(navigator.pushNamed(route));
      },
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({
    required this.releases,
    required this.onOpenRoute,
    required this.onClose,
    super.key,
  });

  final List<WhatsNewRelease> releases;
  final ValueChanged<String> onOpenRoute;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final items = releases.expand((r) => r.items).toList();
    final newest = releases.first.version;
    final oldest = releases.last.version;
    final eyebrow = newest == oldest
        ? l10n.settingsAboutVersion(newest)
        : l10n.whatsNewVersionRange(oldest, newest);

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.layoutMargin,
        0,
        AppDimensions.layoutMargin,
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: AppTextStyles.overline.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Semantics(
            header: true,
            child: Text(l10n.whatsNewTitle, style: AppTextStyles.titleLarge),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          for (var i = 0; i < items.length; i++)
            _ItemRow(
              key: ValueKey('whats-new-item-$i'),
              number: i + 1,
              item: items[i],
              onOpenRoute: onOpenRoute,
            ),
          const SizedBox(height: AppDimensions.spacingMd),
          FilledButton(
            onPressed: onClose,
            child: Text(l10n.whatsNewDone),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.number,
    required this.item,
    required this.onOpenRoute,
    super.key,
  });

  final int number;
  final WhatsNewItem item;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final route = item.route;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppDimensions.spacingLg,
              child: ExcludeSemantics(
                child: Text(
                  '$number',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title(l10n),
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.body(l10n),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (route != null) ...[
              const SizedBox(width: AppDimensions.spacingSm),
              ButleryIcon(
                ButleryIcons.chevronRight,
                color: cs.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );

    if (route == null) return content;
    return Semantics(
      button: true,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(onTap: () => onOpenRoute(route), child: content),
      ),
    );
  }
}

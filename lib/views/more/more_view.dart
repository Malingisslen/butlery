// lib/views/more/more_view.dart
//
// PQ-17 = A: the shell's fourth tab. Skarmar v12 del 2 #mer: "Mer-fliken —
// nav till allt som inte får plats i botten: socialt, familj, notiser,
// inställningar." Drawn as a root bar ("Mer" with the avatar) and three
// sections of rows: Tillsammans (Vänner & grupper, Meddelanden, Min familj),
// Ditt kök (Delat med mig, Egna taggar, Samlingsstatistik) and App & konto
// (Notiser, Inställningar).
//
// "Väntar på synk" lives here too: "Mer → Väntar på synk"
// (produktregler.md:190). It is not in the #mer drawing; it is placed under
// App & konto, before Inställningar (interpretation). Help and legal stay in
// Inställningar (Skarmar v12 del 1 #installningar: "Språk & om", "Vanliga
// frågor").
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social_components/recipe_list_avatar_badge.dart';
import 'package:butlery/widgets/common/sync/sync_queue_indicator.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class MoreView extends StatelessWidget {
  const MoreView({super.key, this.avatar = const RecipeListAvatarBadge()});

  /// The avatar at the end of the bar (#mer draws the user's initial).
  /// Replaceable so the view can be tested without the social providers.
  final Widget avatar;

  /// The key of the row that opens [route]. Identity is the destination.
  static Key rowKey(String route) => ValueKey<String>('more-row-$route');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      // Mönster 1 · Rotnivå (Komponentark v1:60-68).
      appBar: ButleryTopBar.rot(title: l10n.moreTitle, trailing: avatar),
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            // Max line length holds on a wide screen (produktregler.md:1050).
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: ButleryTopBar.sideMargin(context),
                vertical: AppDimensions.spacingSm,
              ),
              children: [
                _Section(
                  title: l10n.moreSectionTogether,
                  rows: [
                    _MoreRow(
                      label: l10n.socialFriendsAndGroups,
                      route: Routes.friends,
                    ),
                    _MoreRow(
                      label: l10n.messagingTitle,
                      route: Routes.messages,
                    ),
                    _MoreRow(
                      label: l10n.moreFamily,
                      route: Routes.settingsFamily,
                    ),
                  ],
                ),
                _Section(
                  title: l10n.moreSectionKitchen,
                  rows: [
                    _MoreRow(
                      label: l10n.profileSharedWithMe,
                      route: Routes.shared,
                    ),
                    _MoreRow(
                      label: l10n.morePersonalTags,
                      route: Routes.settingsPersonalTags,
                    ),
                    _MoreRow(
                      label: l10n.moreCollectionStats,
                      route: Routes.collectionStats,
                    ),
                  ],
                ),
                _Section(
                  title: l10n.moreSectionAppAccount,
                  rows: [
                    _MoreRow(
                      label: l10n.moreNotifications,
                      route: Routes.notifications,
                    ),
                    QueueCountsBuilder(
                      builder: (context, counts) => _MoreRow(
                        label: l10n.syncQueueTitle,
                        route: Routes.syncQueue,
                        arguments: l10n.moreTitle,
                        // PQ-04 = B: a count only when something needs
                        // the user.
                        count: counts.needsUser,
                      ),
                    ),
                    _MoreRow(
                      label: l10n.commonSettings,
                      route: Routes.settings,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A section: its overline and its rows, a divider between rows but not
/// after the last (#mer).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppDimensions.spacingMd,
            bottom: AppDimensions.spacingXs,
          ),
          child: Semantics(
            header: true,
            // The overline in text.success (#3F6B4F light, #8FB89A dark;
            // tokens.json semantic), as drawn (#mer: #3f6b4f).
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: cs.tertiary),
            ),
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          // border.subtle between rows (#mer: #ccd1c2; colorScheme
          // .outlineVariant, 18 % paper in dark mode).
          if (i < rows.length - 1)
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        ],
      ],
    );
  }
}

/// One row: the destination's name, an optional saffron count and a
/// chevron. The whole row is one control named by its text.
class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.label,
    required this.route,
    this.arguments,
    this.count = 0,
  });

  final String label;
  final String route;

  /// Passed to [route] (the queue view takes the name Back leads to).
  final Object? arguments;

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      identifier: 'more-row-$route',
      // The count is read as words, not as a bare number.
      value: count > 0 ? context.l10n.syncQueueNeedsYouHeader(count) : null,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          key: MoreView.rowKey(route),
          onTap: () =>
              Navigator.of(context).pushNamed(route, arguments: arguments),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (count > 0) ...[
                    ExcludeSemantics(child: SaffronCount(count: count)),
                    const SizedBox(width: AppDimensions.spacingSm),
                  ],
                  ExcludeSemantics(
                    child: ButleryIcon(
                      ButleryIcons.chevronRight,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

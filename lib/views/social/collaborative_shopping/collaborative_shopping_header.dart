// lib/views/social/collaborative_shopping/collaborative_shopping_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/avatar_stack.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/surfaces/butlery_disc.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/core/utils/stored_display_name.dart';

/// Focused widget for collaborative shopping list header
/// This widget handles ONLY header display responsibilities:
/// - The people on the list, its state and its activity
/// - Description display
/// - Progress tracking and visualization
/// ❌ DOES NOT CONTAIN: Item management, actions, business logic
class CollaborativeShoppingHeader extends StatelessWidget {
  final CollaborativeShoppingViewModel viewModel;

  const CollaborativeShoppingHeader({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    // #inkop: no tinted card; the title is in the bar, so the header is the
    // people, the state and the progress, on the page.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.layoutMargin,
        AppDimensions.space4,
        AppDimensions.layoutMargin,
        AppDimensions.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeopleSection(context),
          if (viewModel.hasDescription) ...[
            const SizedBox(height: AppDimensions.space8),
            _buildDescriptionSection(context),
          ],
          if (viewModel.hasActiveShoppers) ...[
            const SizedBox(height: AppDimensions.space4),
            _buildPresenceSection(context),
          ],
          const SizedBox(height: AppDimensions.space12),
          _buildProgressSection(context),
        ],
      ),
    );
  }

  Widget _buildPeopleSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatars = AvatarStack(
      names: viewModel.participantNames,
      extra: viewModel.participantsWithoutName,
    );
    final summary = Text(
      '${viewModel.memberCountText} · ${viewModel.activitySummary}',
      style: AppTextStyles.labelMedium.copyWith(color: cs.onSurfaceVariant),
      maxLines: isLargeText(context) ? null : 2,
      overflow: isLargeText(context) ? null : TextOverflow.ellipsis,
    );
    // The summary beside the avatars and the badge is left with a word's
    // width at large text, so it takes its own line there.
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              avatars,
              const Spacer(),
              _buildStatusBadge(context),
            ],
          ),
          const SizedBox(height: AppDimensions.space4),
          summary,
        ],
      );
    }
    return Row(
      children: [
        avatars,
        const SizedBox(width: AppDimensions.space8),
        Expanded(child: summary),
        const SizedBox(width: AppDimensions.space8),
        _buildStatusBadge(context),
      ],
    );
  }

  /// BUT-238: "Anna handlar nu" + green dot per active peer.
  Widget _buildPresenceSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shoppers = viewModel.activeShoppers;
    return Wrap(
      spacing: AppDimensions.space4,
      runSpacing: AppDimensions.space4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final shopper in shoppers)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButleryDisc(size: 8, color: cs.onSurface),
              const SizedBox(width: AppDimensions.space4),
              Text(
                context.l10n.handlarNu(
                  storedNameOr(
                    shopper['displayName'] as String?,
                    context.l10n.shoppingUnknownUser,
                  ),
                ),
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = viewModel.getStatusColor(cs, context.modeColors);
    return Text(
      viewModel.statusText,
      style: AppTextStyles.labelLarge.copyWith(color: color),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Text(
      viewModel.listDescription,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final progress = viewModel.completionPercentage / 100;
    final cs = Theme.of(context).colorScheme;
    final butlery = context.modeColors;
    final progressColor = viewModel.getProgressColor(cs, butlery);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressStats(context, progressColor),
        const SizedBox(height: AppDimensions.space4),
        _buildProgressBar(context, progress, progressColor),
      ],
    );
  }

  Widget _buildProgressStats(BuildContext context, Color progressColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.collaborativeCompletedOf(
            viewModel.completedItems,
            viewModel.totalItems,
          ),
          style: AppTextStyles.bodyBold,
        ),
        Text(
          '${viewModel.completionPercentage.toStringAsFixed(0)}%',
          style: AppTextStyles.bodyBold.copyWith(
            color: progressColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    double progress,
    Color progressColor,
  ) {
    // The list's progress is the determinate plate line: progressIndicator
    // on progressTrack, per mode (Komponentark v1:305; B-18). The count next
    // to it carries the number, so the line is not read twice.
    return ExcludeSemantics(child: PlateLine(value: progress));
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_frozen_viewmodel.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/views/admin/moderator_evidence_section.dart';
import 'package:butlery/views/admin/moderator_freeze_sheet.dart';
import 'package:butlery/views/admin/moderator_labels.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/button_row.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// The "Sparade" tab: copies a moderator keeps past their case, soonest to
/// expire first, with a way to extend or release each.
class ModeratorFrozenTab extends StatelessWidget {
  const ModeratorFrozenTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<ModeratorFrozenViewModel>();
    if (vm.hasError) {
      return StateWidget.error(
        message: l10n.moderatorFrozenLoadFailed,
        onAction: vm.retry,
      );
    }
    if (!vm.hasLoaded) {
      return StateWidget.loading(message: l10n.loadingReports);
    }
    if (vm.items.isEmpty) {
      return StateWidget.empty(title: l10n.moderatorFrozenEmpty);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.space12),
      itemCount: vm.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.space4),
      itemBuilder: (_, i) => _FrozenCard(
        key: ValueKey('frozen-${vm.items[i].reportId}'),
        evidence: vm.items[i],
      ),
    );
  }
}

class _FrozenCard extends StatelessWidget {
  const _FrozenCard({required this.evidence, super.key});

  final ReportEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = ContentType.fromWire(evidence.contentType);
    return StyledCard(
      padding: const EdgeInsets.all(AppDimensions.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (type != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: Text(
                moderatorContentTypeLabel(l10n, type).toUpperCase(),
                style: AppTextStyles.labelLarge,
              ),
            ),
          ModeratorEvidenceSection(state: ReportEvidenceLoaded(evidence)),
          const SizedBox(height: AppDimensions.space12),
          ButtonRow(
            children: [
              ActionButtons.outlinedButton(
                context,
                key: const ValueKey('frozen-extend'),
                label: l10n.moderatorFrozenExtend,
                onPressed: () => _extend(context),
                isExpanded: true,
              ),
              ActionButtons.outlinedButton(
                context,
                key: const ValueKey('frozen-release'),
                label: l10n.moderatorFrozenRelease,
                onPressed: () => _release(context),
                isExpanded: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _extend(BuildContext context) async {
    final vm = context.read<ModeratorFrozenViewModel>();
    final reason = await showModeratorFreezeSheet(
      context,
      confirmLabel: context.l10n.moderatorFrozenExtend,
      initial: evidence.frozen?.reason,
    );
    if (reason == null || !context.mounted) return;
    final result = await vm.extend(evidence, reason);
    if (!context.mounted) return;
    showFreezeResult(context, result, retry: () => _extend(context));
  }

  Future<void> _release(BuildContext context) async {
    final vm = context.read<ModeratorFrozenViewModel>();
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialogs.showConfirmationDialog(
      context,
      title: l10n.moderatorFrozenReleaseTitle,
      message: l10n.moderatorFrozenReleaseBody,
      confirmText: l10n.moderatorFrozenRelease,
      cancelText: l10n.commonCancel,
    );
    if (!confirmed || !context.mounted) return;
    final result = await vm.release(evidence);
    if (!context.mounted) return;
    showFreezeResult(context, result, retry: () => _release(context));
  }
}

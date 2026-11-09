import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/tagging/config/occasion_lists.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/tag_rules_viewmodel.dart';
import 'package:butlery/views/admin/occasion_list_edit_dialog.dart';
import 'package:butlery/views/admin/occasion_list_labels.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// The word lists the tagger reads, grouped, each with a way to propose a
/// change. The words shown are the ones compiled into this build.
class OccasionListsSection extends StatelessWidget {
  const OccasionListsSection({required this.viewModel, super.key});

  final TagRulesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final groups = <String, List<OccasionList>>{};
    for (final list in kOccasionLists) {
      groups.putIfAbsent(list.group, () => []).add(list);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.adminOccasionListsTitle, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.space8),
        Text(l10n.adminOccasionListsInfo, style: AppTextStyles.bodyMedium),
        for (final entry in groups.entries) ...[
          const SizedBox(height: AppDimensions.space16),
          Text(
            occasionGroupLabel(l10n, entry.key),
            style: AppTextStyles.titleSmall,
          ),
          for (final list in entry.value)
            Container(
              key: ValueKey('occasion-list-${list.key}'),
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.space8,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      occasionFieldLabel(l10n, list.field),
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      list.words.join(', '),
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                  ButleryTextButton(
                    key: ValueKey('occasion-edit-${list.key}'),
                    label: l10n.adminOccasionListEdit,
                    onPressed: () => showOccasionListEditDialog(
                      context,
                      list: list,
                      viewModel: viewModel,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

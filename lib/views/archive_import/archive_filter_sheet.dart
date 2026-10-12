// lib/views/archive_import/archive_filter_sheet.dart
//
// The filters the archive page has no room for beside its three tag pills
// (Skarmar v12 'Importera från arkiv', "Fler"): every tag and the time limit.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/choice_option.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

Future<void> showArchiveFilterSheet(
  BuildContext context,
  ArchiveImportViewModel viewModel,
) {
  return showButlerySheet<void>(
    context: context,
    builder: (sheetContext) => ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => _ArchiveFilterSheet(viewModel: viewModel),
    ),
  );
}

class _ArchiveFilterSheet extends StatelessWidget {
  const _ArchiveFilterSheet({required this.viewModel});

  final ArchiveImportViewModel viewModel;

  static const _limits = {
    TimeFilter.under15: 15,
    TimeFilter.under30: 30,
    TimeFilter.under60: 60,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tags = viewModel.availableTags.toList()..sort();
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppDimensions.layoutMarginOf(context),
        0,
        AppDimensions.layoutMarginOf(context),
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.importFiltersTitle,
              style: AppTextStyles.subpageTitle,
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          SectionHeading(l10n.importTimeHeading),
          const SizedBox(height: AppDimensions.space8),
          ChoiceOptionWrap<TimeFilter>(
            values: TimeFilter.values,
            labelOf: (filter) => filter == TimeFilter.all
                ? l10n.importFilterAll
                : l10n.importUpToMinutes(_limits[filter]!),
            selected: viewModel.timeFilter,
            onChanged: viewModel.setTimeFilter,
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space24),
            SectionHeading(l10n.importTagsHeading),
            const SizedBox(height: AppDimensions.space8),
            Wrap(
              spacing: AppDimensions.space8,
              runSpacing: AppDimensions.space8,
              children: [
                for (final tag in tags)
                  ChoiceOption(
                    label: tag,
                    selected: viewModel.selectedTags.contains(tag),
                    onSelected: () => viewModel.toggleTag(tag),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

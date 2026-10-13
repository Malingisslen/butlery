/// A single personal tag: its key figures, automation rules and recipes.
/// Everything that can be done to the tag is reachable from here.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/tag_detail/tag_detail_actions.dart';
import 'package:butlery/views/tag_detail/tag_edit_sheet.dart';
import 'package:butlery/widgets/common/stat_row.dart';
import 'package:butlery/widgets/tagging/tag_detail_recipes_section.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/tagging/tag_detail_rules_section.dart';

class TagDetailView extends StatelessWidget {
  final String tagId;

  const TagDetailView({super.key, required this.tagId});

  @override
  Widget build(BuildContext context) {
    final vm = ServiceLocator.get<PersonalTagViewModel>();
    return ChangeNotifierProvider<PersonalTagViewModel>.value(
      value: vm,
      child: _TagDetailViewContent(tagId: tagId),
    );
  }
}

class _TagDetailViewContent extends StatefulWidget {
  final String tagId;

  const _TagDetailViewContent({required this.tagId});

  @override
  State<_TagDetailViewContent> createState() => _TagDetailViewContentState();
}

class _TagDetailViewContentState extends State<_TagDetailViewContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PersonalTagViewModel>();
      if (!viewModel.isLoadingRuleStats) {
        viewModel.loadRuleEffectiveness();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PersonalTagViewModel>(
      builder: (context, viewModel, _) {
        final tag = viewModel.getTagById(widget.tagId);

        if (viewModel.isLoading && tag == null) {
          return _stateScaffold(
            context,
            StateWidget.loading(message: context.l10n.loadingTag),
          );
        }

        if (tag == null) {
          return _stateScaffold(
            context,
            StateWidget.error(
              message: context.l10n.tagDetailNotFound,
              onAction: () => Navigator.of(context).maybePop(),
            ),
          );
        }

        return ButleryPage.undersida(
          title: tag.name,
          backTo: context.l10n.morePersonalTags,
          actions: [
            TextButton(
              onPressed: () => showTagEditSheet(
                context,
                tag: tag,
                viewModel: viewModel,
              ),
              child: Text(context.l10n.cookbookEdit),
            ),
          ],
          body: Column(
            children: [
              LayoutComponents.offlineIndicator(),
              Expanded(child: _buildBody(context, viewModel, tag)),
            ],
          ),
        );
      },
    );
  }

  Widget _stateScaffold(BuildContext context, Widget body) {
    return ButleryPage.undersida(
      title: context.l10n.tagDetailDefaultTitle,
      backTo: context.l10n.morePersonalTags,
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context,
    PersonalTagViewModel viewModel,
    PersonalTag tag,
  ) {
    final l10n = context.l10n;
    final margin = ButleryTopBar.sideMargin(context);

    return ListView(
      padding: EdgeInsetsDirectional.only(
        start: margin,
        end: margin,
        top: AppDimensions.space16,
        bottom: AppDimensions.space24,
      ),
      children: [
        StatRow(
          items: [
            StatRowItem(
              value: '${viewModel.getUsageCount(tag.name)}',
              label: l10n.cookbookStatRecipes,
            ),
            StatRowItem(
              value: l10n.tagDetailStatRulesValue(
                tag.rules.where((r) => r.isEnabled).length,
                tag.rules.length,
              ),
              label: l10n.tagDetailStatRules(tag.rules.length),
            ),
            StatRowItem(
              value: DateFormat.MMMd(
                Localizations.localeOf(context).toString(),
              ).format(tag.updatedAt),
              label: l10n.tagDetailStatChanged,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.space16),
        TagDetailRulesSection(
          tag: tag,
          viewModel: viewModel,
          onEditRule: (rule) => TagDetailActions.editRule(context, tag, rule),
          onDeleteRule: (rule) =>
              TagDetailActions.deleteRule(context, tag, rule),
          onToggleRule: (rule) =>
              TagDetailActions.toggleRule(context, tag, rule),
          onAddRule: () => TagDetailActions.addRule(context, tag),
        ),
        const SizedBox(height: AppDimensions.space16),
        OutlinedButton(
          onPressed: () => TagDetailActions.applyRulesToRecipes(context),
          child: Text(l10n.tagDetailRunRulesAll),
        ),
        const SizedBox(height: AppDimensions.space24),
        TagDetailRecipesSection(
          tagId: tag.id,
          recipeCount: viewModel.getUsageCount(tag.name),
        ),
      ],
    );
  }
}

/// A single personal tag: its name, group and automation rules. Everything
/// that can be done to the tag is reachable from here.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/tag_detail/tag_detail_actions.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/tagging/tag_detail_header.dart';
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
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_saveNameOnBlur);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PersonalTagViewModel>();
      if (!viewModel.isLoadingRuleStats) {
        viewModel.loadRuleEffectiveness();
      }
    });
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_saveNameOnBlur);
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNameOnBlur() async {
    if (_nameFocusNode.hasFocus) return;
    final tag = context.read<PersonalTagViewModel>().getTagById(widget.tagId);
    if (tag == null) return;
    final newName = _nameController.text.trim();
    if (newName == tag.name) return;
    if (newName.isEmpty) {
      _nameController.text = tag.name;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.tagDetailNameRequired,
      );
      return;
    }
    await TagDetailActions.rename(context, tag, newName);
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

        if (!_nameFocusNode.hasFocus && _nameController.text != tag.name) {
          _nameController.text = tag.name;
        }

        return Scaffold(
          appBar: ButleryTopBar.undersida(
            title: tag.name,
            backTo: context.l10n.morePersonalTags,
            actions: [
              IconButton(
                icon: const ButleryIcon(ButleryIcons.moreVertical),
                tooltip: context.l10n.personalTagOptions,
                onPressed: () => _openMenu(context, tag),
              ),
            ],
          ),
          bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
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
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: context.l10n.tagDetailDefaultTitle,
        backTo: context.l10n.morePersonalTags,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
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
    final group = viewModel.groups
        .where((g) => g.id == tag.groupId)
        .firstOrNull;

    return SafeArea(
      child: ButleryPageBody(
        width: PageWidth.text,
        child: ListView(
          padding: EdgeInsetsDirectional.only(
            start: margin,
            end: margin,
            top: AppDimensions.space16,
            bottom: AppDimensions.space24,
          ),
          children: [
            // Saves when the field loses focus; Done on the keyboard
            // releases the focus, so submit and blur are one path.
            StyledInput(
              label: l10n.commonName,
              hint: l10n.tagDetailNameHint,
              controller: _nameController,
              focusNode: _nameFocusNode,
              textInputAction: TextInputAction.done,
            ),
            TagDetailHeader(
              tag: tag,
              usageCount: viewModel.getUsageCount(tag.name),
            ),
            ButleryListSection(
              title: l10n.tagDetailGroupLabel,
              rows: [
                ButleryListRow(
                  label: l10n.tagDetailGroupLabel,
                  value: group?.name ?? l10n.personalTagNoGroup,
                  onTap: () => PersonalTagDialogs.showMoveTagToGroupDialog(
                    context,
                    tag,
                  ),
                ),
              ],
            ),
            TagDetailRulesSection(
              tag: tag,
              viewModel: viewModel,
              onEditRule: (rule) =>
                  TagDetailActions.editRule(context, tag, rule),
              onDeleteRule: (rule) =>
                  TagDetailActions.deleteRule(context, tag, rule),
              onToggleRule: (rule) =>
                  TagDetailActions.toggleRule(context, tag, rule),
              onAddRule: () => TagDetailActions.addRule(context, tag),
            ),
            const SizedBox(height: AppDimensions.space24),
            OutlinedButton(
              onPressed: () => TagDetailActions.applyRulesToRecipes(context),
              child: Text(l10n.tagDetailRunRulesAll),
            ),
          ],
        ),
      ),
    );
  }

  void _openMenu(BuildContext context, PersonalTag tag) {
    final l10n = context.l10n;
    final hasRules = tag.rules.isNotEmpty;
    final enabled = tag.rules.where((r) => r.isEnabled).length;
    showButleryListSheet<void>(
      context,
      title: tag.name,
      rows: (sheetContext) => [
        ButleryListRow(
          label: l10n.tagDetailShareTag,
          onTap: () {
            Navigator.pop(sheetContext);
            PersonalTagDialogs.showShareTagDialog(context, tag);
          },
        ),
        if (hasRules && enabled < tag.rules.length)
          ButleryListRow(
            label: l10n.personalTagEnableAllRules,
            onTap: () {
              Navigator.pop(sheetContext);
              PersonalTagDialogs.showToggleAllRulesDialog(
                context,
                tag,
                enable: true,
              );
            },
          ),
        if (hasRules && enabled > 0)
          ButleryListRow(
            label: l10n.personalTagDisableAllRules,
            onTap: () {
              Navigator.pop(sheetContext);
              PersonalTagDialogs.showToggleAllRulesDialog(
                context,
                tag,
                enable: false,
              );
            },
          ),
        ButleryListRow.danger(
          label: l10n.tagDetailDeleteTagAction,
          onTap: () {
            Navigator.pop(sheetContext);
            TagDetailActions.deleteTag(context, tag);
          },
        ),
      ],
    );
  }
}

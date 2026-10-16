/// What "Redigera" on a tag's page opens: the tag's name and group, and the
/// things that can be done to the tag as a whole.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/tag_detail/tag_detail_actions.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

Future<void> showTagEditSheet(
  BuildContext context, {
  required PersonalTag tag,
  required PersonalTagViewModel viewModel,
}) {
  return showButlerySheet<void>(
    context: context,
    builder: (sheetContext) =>
        _TagEditSheet(pageContext: context, tag: tag, viewModel: viewModel),
  );
}

class _TagEditSheet extends StatefulWidget {
  const _TagEditSheet({
    required this.pageContext,
    required this.tag,
    required this.viewModel,
  });

  final BuildContext pageContext;
  final PersonalTag tag;
  final PersonalTagViewModel viewModel;

  @override
  State<_TagEditSheet> createState() => _TagEditSheetState();
}

class _TagEditSheetState extends State<_TagEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.tag.name,
  );

  late String _savedName = widget.tag.name;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty || name == _savedName) return;
    _savedName = name;
    await TagDetailActions.rename(widget.pageContext, widget.tag, name);
  }

  Future<void> _closeThen(Future<void> Function() action) async {
    await _saveName();
    if (!mounted) return;
    Navigator.pop(context);
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tag = widget.tag;
    final page = widget.pageContext;
    final hasRules = tag.rules.isNotEmpty;
    final enabled = tag.rules.where((r) => r.isEnabled).length;
    final group = widget.viewModel.groups
        .where((g) => g.id == tag.groupId)
        .firstOrNull;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveName();
      },
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppDimensions.layoutMarginOf(context),
          0,
          AppDimensions.layoutMarginOf(context),
          MediaQuery.viewInsetsOf(context).bottom + AppDimensions.layoutMargin,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(l10n.tagEditSheetTitle)),
            const SizedBox(height: AppDimensions.space16),
            StyledInput(
              label: l10n.commonName,
              hint: l10n.tagDetailNameHint,
              controller: _name,
              textInputAction: TextInputAction.done,
            ),
            ButleryListSection(
              rows: [
                ButleryListRow(
                  label: l10n.tagDetailGroupLabel,
                  value: group?.name ?? l10n.personalTagNoGroup,
                  onTap: () => _closeThen(
                    () =>
                        PersonalTagDialogs.showMoveTagToGroupDialog(page, tag),
                  ),
                ),
                ButleryListRow(
                  label: l10n.tagDetailShareTag,
                  onTap: () => _closeThen(
                    () => PersonalTagDialogs.showShareTagDialog(page, tag),
                  ),
                ),
                if (hasRules && enabled < tag.rules.length)
                  ButleryListRow(
                    label: l10n.personalTagEnableAllRules,
                    onTap: () => _closeThen(
                      () => PersonalTagDialogs.showToggleAllRulesDialog(
                        page,
                        tag,
                        enable: true,
                      ),
                    ),
                  ),
                if (hasRules && enabled > 0)
                  ButleryListRow(
                    label: l10n.personalTagDisableAllRules,
                    onTap: () => _closeThen(
                      () => PersonalTagDialogs.showToggleAllRulesDialog(
                        page,
                        tag,
                        enable: false,
                      ),
                    ),
                  ),
                ButleryListRow.danger(
                  label: l10n.tagDetailDeleteTagAction,
                  onTap: () =>
                      _closeThen(() => TagDetailActions.deleteTag(page, tag)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

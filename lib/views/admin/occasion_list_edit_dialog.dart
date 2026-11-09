import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/tagging/config/occasion_lists.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/tag_rules_viewmodel.dart';
import 'package:butlery/views/admin/occasion_list_labels.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

/// Opens the editor for [list]. Resolves to true when a proposal was saved.
Future<bool?> showOccasionListEditDialog(
  BuildContext context, {
  required OccasionList list,
  required TagRulesViewModel viewModel,
}) => showButleryDialog<bool>(
  context: context,
  builder: (_) => OccasionListEditDialog(list: list, viewModel: viewModel),
);

class OccasionListEditDialog extends StatefulWidget {
  const OccasionListEditDialog({
    required this.list,
    required this.viewModel,
    super.key,
  });

  final OccasionList list;
  final TagRulesViewModel viewModel;

  @override
  State<OccasionListEditDialog> createState() => _OccasionListEditDialogState();
}

class _OccasionListEditDialogState extends State<OccasionListEditDialog> {
  late final TextEditingController _words = TextEditingController(
    text: widget.list.words.join('\n'),
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _words.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> parsed) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final snackBars = CapturedSnackBars.capture(context);
    final saved = await widget.viewModel.proposeWordList(
      widget.list,
      parsed,
      note: _note.text,
    );
    if (!saved) return;
    snackBars.showConfirmation(l10n.adminOccasionSaved);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([_words, _note, widget.viewModel]),
      builder: (context, _) {
        final vm = widget.viewModel;
        final parsed = parseOccasionWords(_words.text);
        final problem = validateOccasionWords(parsed);
        final unchanged = TagRulesViewModel.sameWords(
          widget.list.words,
          parsed,
        );
        final noteOk = vm.noteIsValid(_note.text);
        final canSave = problem == null && !unchanged && noteOk;
        return ButleryDialog(
          title: l10n.adminOccasionEditTitle(
            occasionListLabel(l10n, widget.list.key),
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StyledInput.multiline(
                  key: const ValueKey('occasion-words'),
                  controller: _words,
                  label: l10n.adminOccasionWordsLabel,
                  helperText: l10n.adminOccasionWordsHelp,
                  errorText: problem == null
                      ? null
                      : occasionWordsErrorText(l10n, problem),
                  semanticLabel: l10n.adminOccasionWordsLabel,
                  minLines: 6,
                  maxLines: 12,
                ),
                const SizedBox(height: AppDimensions.space8),
                if (problem == null && !unchanged)
                  _Preview(old: widget.list.words, now: parsed, l10n: l10n),
                if (unchanged)
                  Text(
                    l10n.adminProposalNothingChanged,
                    style: AppTextStyles.bodySmall,
                  ),
                const SizedBox(height: AppDimensions.space8),
                StyledInput.multiline(
                  key: const ValueKey('occasion-note'),
                  controller: _note,
                  label: l10n.adminProposalNoteLabel,
                  helperText: l10n.adminProposalNoteHelp,
                  errorText: noteOk
                      ? null
                      : l10n.adminProposalNoteTooLong(
                          TagRulesViewModel.maxNoteLength,
                        ),
                  semanticLabel: l10n.adminProposalNoteLabel,
                  minLines: 2,
                  maxLines: 4,
                ),
                if (vm.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.space8),
                    child: Text(
                      key: const ValueKey('occasion-error'),
                      vm.error!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            DialogCancelButton(enabled: !vm.isLoading),
            ButleryDialogPrimary(
              key: const ValueKey('occasion-save'),
              label: l10n.adminProposalSave,
              busy: vm.isLoading,
              onPressed: canSave ? () => _save(parsed) : null,
            ),
          ],
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.old, required this.now, required this.l10n});

  final List<String> old;
  final List<String> now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (:added, :removed) = wordListDiff(old, now);
    return Column(
      key: const ValueKey('occasion-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (added.isNotEmpty)
          Text(
            l10n.adminOccasionWordsAdded(added.join(', ')),
            style: AppTextStyles.bodySmall,
          ),
        if (removed.isNotEmpty)
          Text(
            l10n.adminOccasionWordsRemoved(removed.join(', ')),
            style: AppTextStyles.bodySmall,
          ),
        if (added.isEmpty && removed.isEmpty)
          Text(
            l10n.adminOccasionWordsReordered,
            style: AppTextStyles.bodySmall,
          ),
      ],
    );
  }
}

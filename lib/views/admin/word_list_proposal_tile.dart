import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/admin/occasion_list_labels.dart';

/// What a word-list proposal changes: the words added, the words removed and,
/// on a conflict, what the app's list holds now. The card around it supplies
/// the title, status and actions.
class WordListProposalTile extends StatelessWidget {
  const WordListProposalTile({required this.proposal, super.key});

  final IngredientChangeRequest proposal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (:added, :removed) = wordListDiff(
      proposal.oldWords,
      proposal.newWords,
    );
    final main = proposal.status == IngredientChangeStatus.conflict
        ? proposal.mainWords
        : null;
    Widget line(Key key, String text) => Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space4),
      child: SelectableText(key: key, text),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (added.isNotEmpty)
          line(
            const ValueKey('words-added'),
            l10n.adminOccasionWordsAdded(added.join(', ')),
          ),
        if (removed.isNotEmpty)
          line(
            const ValueKey('words-removed'),
            l10n.adminOccasionWordsRemoved(removed.join(', ')),
          ),
        if (added.isEmpty && removed.isEmpty)
          line(
            const ValueKey('words-reordered'),
            l10n.adminOccasionWordsReordered,
          ),
        if (main != null)
          line(
            const ValueKey('words-main'),
            l10n.adminOccasionWordsMain(main.join(', ')),
          ),
      ],
    );
  }
}

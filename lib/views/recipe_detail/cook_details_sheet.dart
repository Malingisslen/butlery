import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/cook_event.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';

/// What the user filled in after a cook. Both fields are optional.
class CookDetails {
  const CookDetails({this.rating, this.note});

  final int? rating;
  final String? note;

  bool get isEmpty => rating == null && (note == null || note!.isEmpty);
}

/// "Hur blev det?" after a cook. [askRating] is false when the household
/// already rated through the family entry, so the cook is not rated twice.
/// Returns null when skipped or dismissed.
Future<CookDetails?> showCookDetailsSheet(
  BuildContext context, {
  required String recipeTitle,
  required bool askRating,
}) {
  return showButlerySheet<CookDetails>(
    context: context,
    builder: (_) =>
        _CookDetailsSheet(recipeTitle: recipeTitle, askRating: askRating),
  );
}

class _CookDetailsSheet extends StatefulWidget {
  const _CookDetailsSheet({required this.recipeTitle, required this.askRating});

  final String recipeTitle;
  final bool askRating;

  @override
  State<_CookDetailsSheet> createState() => _CookDetailsSheetState();
}

class _CookDetailsSheetState extends State<_CookDetailsSheet> {
  final _note = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final note = _note.text.trim();
    Navigator.of(context).pop(
      CookDetails(
        rating: _rating == 0 ? null : _rating,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space24,
        0,
        AppDimensions.space24,
        AppDimensions.space16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.cookDetailsTitle, style: AppTextStyles.bodyLargeBold),
            const SizedBox(height: AppDimensions.space4),
            Text(
              widget.recipeTitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (widget.askRating) ...[
              const SizedBox(height: AppDimensions.space16),
              Text(l10n.cookDetailsRatingLabel, style: AppTextStyles.bodySmall),
              const SizedBox(height: AppDimensions.space4),
              Align(
                alignment: Alignment.centerLeft,
                child: StarRatingRow(
                  rating: _rating.toDouble(),
                  size: AppDimensions.iconSizeL,
                  slot: AppDimensions.minTouchTarget,
                  solidEmpty: true,
                  onRatingChanged: (v) => setState(() => _rating = v.toInt()),
                  semanticsLabel: l10n.cookDetailsRateStars,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.space16),
            StyledInput(
              label: l10n.cookDetailsNoteLabel,
              hint: l10n.cookDetailsNoteHint,
              controller: _note,
              maxLines: 3,
              minLines: 1,
              maxLength: CookEvent.maxNoteLength,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppDimensions.space16),
            Row(
              children: [
                Expanded(
                  child: ActionButtons.outlinedButton(
                    context,
                    label: l10n.cookDetailsSkip,
                    onPressed: () => Navigator.of(context).pop(),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: ActionButtons.primaryButton(
                    context,
                    label: l10n.cookDetailsSave,
                    onPressed: _save,
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

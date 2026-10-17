import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';

/// Lists everyone who can see a comment. A person whose name did not resolve
/// still counts: the total is always disclosed, never hidden.
Future<void> showCommentAudienceDialog(
  BuildContext context, {
  required List<String> resolved,
  required int total,
}) {
  final unresolved = total - resolved.length;
  return showButleryDialog<void>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return ButleryDialog.notice(
        title: ctx.l10n.recipeCommentAudienceTitle,
        titleIcon: ButleryIcons.eye,
        scrollable: false,
        content: resolved.isEmpty
            ? Text(
                ctx.l10n.recipeCommentVisiblePeople(total),
                style: AppTextStyles.bodyMedium,
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final name in resolved)
                      ButleryItemRow(
                        padded: false,
                        leadingIcon: ButleryIcons.user,
                        title: name,
                      ),
                    if (unresolved > 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppDimensions.space4,
                        ),
                        child: Text(
                          ctx.l10n.recipeCommentAudienceOthers(unresolved),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      );
    },
  );
}

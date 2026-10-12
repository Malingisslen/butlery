// lib/widgets/social/decision_row.dart
//
// The one row for a moderation matter (Mina anmälningar, Beslut om mitt
// innehåll): a glyph for the kind of content, the title and its status pill,
// who and when, the outcome in a quiet note, and the way to appeal.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class DecisionRow extends StatelessWidget {
  const DecisionRow({
    required this.title,
    required this.status,
    required this.onTap,
    this.contentType,
    this.subtitle,
    this.outcome,
    this.onAppeal,
    super.key,
  });

  final String title;

  /// The status pill, at the end of the title line.
  final Widget status;

  final ContentType? contentType;
  final String? subtitle;

  /// What was decided, in a note under the row opening with "Utfall:".
  final String? outcome;

  /// Set only where an appeal can still be made; draws "Jag vill överklaga".
  final VoidCallback? onAppeal;

  final VoidCallback onTap;

  static IconData glyphFor(ContentType? type) => switch (type) {
    ContentType.recipe || ContentType.menuDish => ButleryIcons.file,
    ContentType.comment || ContentType.message => ButleryIcons.messageSquare,
    ContentType.profile => ButleryIcons.user,
    ContentType.cookSnap => ButleryIcons.camera,
    ContentType.group => ButleryIcons.users,
    null => ButleryIcons.flag,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    const indent = AppDimensions.iconSizeL + AppDimensions.space12;
    final linkStyle = AppTextStyles.bodyMedium.copyWith(
      color: ModeColors.of(Theme.of(context).brightness).textLink,
      decoration: TextDecoration.underline,
    );
    final note = outcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          child: PressFill(
            surface: PressSurface.base,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(top: AppDimensions.space12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: ButleryIcon(
                        glyphFor(contentType),
                        size: AppDimensions.iconSizeM,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppDimensions.space8),
                              status,
                            ],
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: AppTextStyles.captionBase.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          if (note == null && onAppeal == null)
                            const SizedBox(height: AppDimensions.space12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (note != null)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: indent,
              top: AppDimensions.space8,
              bottom: onAppeal == null ? AppDimensions.space12 : 0,
            ),
            child: TintedNote.labelled(
              label: l10n.decisionOutcomeLabel,
              text: note,
            ),
          ),
        if (onAppeal != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: indent),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ButleryLink(
                semanticLabel: l10n.decisionAppealLink,
                onTap: onAppeal,
                child: Text(l10n.decisionAppealLink, style: linkStyle),
              ),
            ),
          ),
      ],
    );
  }
}

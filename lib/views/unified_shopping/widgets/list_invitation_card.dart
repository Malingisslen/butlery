import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

/// One pending invitation to a shared shopping list. While [busy] both
/// buttons are off and the answer being given shows progress.
class ListInvitationCard extends StatelessWidget {
  const ListInvitationCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onBlock,
    super.key,
  });

  final SocialRequest invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final senderName = senderNameOf(context, invitation);
    final meta = invitation.permission == 'view'
        ? l10n.listInvitationMetaView(senderName)
        : l10n.listInvitationMetaEdit(senderName);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.space8),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.space16,
        AppDimensions.space8,
        AppDimensions.space8,
        AppDimensions.space8,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.space8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.listName.orEmpty(),
                        style: AppTextStyles.titleBold,
                      ),
                      const SizedBox(height: AppDimensions.space4),
                      Text(
                        meta,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppIconButton(
                icon: ButleryIcons.moreVertical,
                semanticLabel: l10n.listInvitationMoreActions,
                onPressed: busy ? null : () => _openMenu(context, senderName),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: AppDimensions.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionButtons.textButton(
                  context,
                  label: l10n.listInvitationDecline,
                  onPressed: busy ? null : onDecline,
                ),
                ActionButtons.primaryButton(
                  context,
                  label: l10n.listInvitationJoin,
                  onPressed: busy ? null : onAccept,
                  isLoading: busy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The sender as the invitee sees them: a blank name reads as someone.
  static String senderNameOf(BuildContext context, SocialRequest invitation) {
    final name = invitation.fromUserName?.trim();
    return (name == null || name.isEmpty)
        ? context.l10n.listInvitationUnknownSender
        : name;
  }

  void _openMenu(BuildContext context, String senderName) {
    showButleryListSheet<void>(
      context,
      title: invitation.listName.orEmpty(),
      rows: (sheetContext) => [
        ButleryListRow.danger(
          label: context.l10n.listInvitationBlockSender(senderName),
          onTap: () {
            Navigator.of(sheetContext).pop();
            onBlock();
          },
        ),
      ],
    );
  }
}

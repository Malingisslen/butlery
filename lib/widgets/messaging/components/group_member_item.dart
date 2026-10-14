import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/list/butlery_media_row.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';

/// A group member as a row: round avatar, name, "· du" after your own, and
/// "Ta bort" at the end when the member can be removed. Rows go in a
/// ButleryListSection so they sit between hairlines.
class GroupMemberItem extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
  final bool canRemove;
  final VoidCallback? onRemove;

  /// Makes the whole row tappable. [semanticsLabel] names the action only and
  /// is merged into the row's node, so the row is a single focus stop.
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const GroupMemberItem({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.isCurrentUser = false,
    this.canRemove = false,
    this.onRemove,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final row = ButleryMediaRow(
      leading: AvatarCircle(
        imageUrl: avatarUrl,
        displayName: displayName,
      ),
      title: displayName,
      titleSuffix: isCurrentUser ? context.l10n.messagingMemberYou : null,
      onTap: onTap,
      trailing: canRemove
          ? ButleryTextButton(
              label: context.l10n.commonRemove,
              tone: ButleryTextButtonTone.danger,
              onPressed: onRemove,
            )
          : null,
    );
    if (onTap == null) return row;
    return MergeSemantics(
      child: Semantics(label: semanticsLabel, button: true, child: row),
    );
  }
}

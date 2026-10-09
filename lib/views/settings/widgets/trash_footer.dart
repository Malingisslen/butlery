import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/bottom_action_bar.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The trash view's footer. With a selection it counts it and offers restore
/// and delete for those rows; without one it offers to empty the trash.
class TrashFooter extends StatelessWidget {
  const TrashFooter({
    required this.selectedCount,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
    required this.onEmpty,
    super.key,
  });

  final int selectedCount;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BottomActionBar(
      child: SafeArea(
        top: false,
        child: selectedCount == 0
            ? ActionButtons.outlinedButton(
                context,
                label: l10n.trashEmptyAction,
                icon: ButleryIcons.trash2,
                onPressed: busy ? null : onEmpty,
                isExpanded: true,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.trashSelectedCount(selectedCount),
                    style: AppTextStyles.titleSmall,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ActionButtons.primaryButton(
                    context,
                    label: l10n.trashRestoreSelected(selectedCount),
                    icon: ButleryIcons.undo,
                    onPressed: busy ? null : onRestore,
                    isExpanded: true,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ActionButtons.outlinedButton(
                    context,
                    label: l10n.trashDeleteSelected(selectedCount),
                    icon: ButleryIcons.trash2,
                    onPressed: busy ? null : onDelete,
                    isExpanded: true,
                  ),
                ],
              ),
      ),
    );
  }
}

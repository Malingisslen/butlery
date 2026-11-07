import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/user_avatar.dart';

/// The quiet line under a saved menu's name: who it was shared with.
class MenuSharedWithLine extends StatelessWidget {
  const MenuSharedWithLine({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        ButleryIcon(
          ButleryIcons.users,
          size: AppDimensions.iconSizeS,
          color: color,
        ),
        const SizedBox(width: AppDimensions.space4),
        Text(
          context.l10n.menuSharedWithCount(count),
          style: AppTextStyles.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Names are fetched here, on the tap, never while the saved menus list opens.
Future<void> showMenuSharedWithSheet(
  BuildContext context, {
  required MenuViewModel viewModel,
  required String menuName,
  required Set<String> recipientIds,
}) {
  return showButlerySheet<void>(
    context: context,
    builder: (_) => _SharedWithBody(
      menuName: menuName,
      lookup: viewModel.getShareRecipientProfiles(recipientIds.toList()),
      expected: recipientIds.length,
    ),
  );
}

class _SharedWithBody extends StatelessWidget {
  const _SharedWithBody({
    required this.menuName,
    required this.lookup,
    required this.expected,
  });

  final String menuName;
  final Future<List<UserProfile>> lookup;
  final int expected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space16,
        0,
        AppDimensions.space16,
        AppDimensions.space16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.menuSharedWithTitle(menuName),
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppDimensions.space8),
          FutureBuilder<List<UserProfile>>(
            future: lookup,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.space16,
                  ),
                  child: PlateLineMessage(message: context.l10n.commonLoading),
                );
              }
              final people = snapshot.data ?? const <UserProfile>[];
              return Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in people)
                      ButleryItemRow(
                        leading: UserAvatar(
                          imageUrl: p.avatarUrl,
                          displayName: p.displayName,
                        ),
                        title: p.displayName,
                      ),
                    if (people.length < expected)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppDimensions.space8,
                        ),
                        child: Text(
                          context.l10n.menuSharedWithMissing,
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

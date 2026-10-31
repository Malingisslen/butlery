// lib/views/unified_shopping/widgets/week_list_follow_notice_bar.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/week_list_follow_notice_manager.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/layout/main_tab_shown.dart';

/// "Uppdaterad från veckomenyn: 3 nya, 1 borttagen" with Ångra and ×, at the
/// top of the list the week menu changed (Malin 2026-10-31, variant A).
///
/// It shows the next time the list is on screen, not while the menu is being
/// edited, and is gone once the list is left.
class WeekListFollowNoticeBar extends StatefulWidget {
  const WeekListFollowNoticeBar({
    super.key,
    required this.listId,
    this.canUndo = true,
    this.manager,
  });

  /// The list on screen, null while there is none.
  final String? listId;

  /// Off without a connection: Ångra compares with the list as this device
  /// last saw it, and could otherwise undo a tick made on another device.
  final bool canUndo;

  /// For tests; the bar makes its own otherwise.
  final WeekListFollowNoticeManager? manager;

  @override
  State<WeekListFollowNoticeBar> createState() =>
      _WeekListFollowNoticeBarState();
}

class _WeekListFollowNoticeBarState extends State<WeekListFollowNoticeBar> {
  late final WeekListFollowNoticeManager _manager =
      widget.manager ?? WeekListFollowNoticeManager();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(WeekListFollowNoticeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() =>
      _manager.onScreen(MainTabShown.of(context) ? widget.listId : null);

  Future<void> _undo() async {
    final undone = await _manager.undo();
    if (undone || !mounted) return;
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.shoppingFollowNoticeUndoFailed,
    );
  }

  @override
  void dispose() {
    if (widget.manager == null) _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final notice = _manager.notice;
        if (notice == null) return const SizedBox.shrink();
        return _NoticeRow(
          text: noticeText(context, notice),
          onUndo: widget.canUndo ? _undo : null,
          onDismiss: _manager.dismiss,
        );
      },
    );
  }

  static String noticeText(BuildContext context, WeekListFollowNotice notice) {
    final l = context.l10n;
    return l.shoppingFollowNotice(
      [
        if (notice.addedCount > 0) l.shoppingFollowAdded(notice.addedCount),
        if (notice.changedCount > 0)
          l.shoppingFollowChanged(notice.changedCount),
        if (notice.removedCount > 0)
          l.shoppingFollowRemoved(notice.removedCount),
      ].join(', '),
    );
  }
}

/// Drawn like the shared list's "updated by" notice, on the calm success
/// tint instead of the warning one: nothing went wrong.
class _NoticeRow extends StatelessWidget {
  const _NoticeRow({
    required this.text,
    required this.onUndo,
    required this.onDismiss,
  });

  final String text;
  final VoidCallback? onUndo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final body = AppModeColors.textBody(Theme.of(context).brightness);
    return Semantics(
      key: const ValueKey('unifiedShopping.weekListFollowNotice'),
      container: true,
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
        decoration: BoxDecoration(
          color: context.modeColors.surfaceTintSuccess,
          borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space12,
                  vertical: AppDimensions.space8,
                ),
                child: Text(
                  text,
                  style: AppTextStyles.captionBase.copyWith(color: body),
                ),
              ),
            ),
            if (onUndo != null)
              ButleryTextButton(
                key: const ValueKey(
                  'unifiedShopping.weekListFollowNotice.undo',
                ),
                label: context.l10n.commonUndo,
                onPressed: onUndo,
                dense: true,
              ),
            SizedBox(
              width: AppDimensions.minTouchTarget,
              height: AppDimensions.minTouchTarget,
              child: ButleryCloseButton(
                semanticLabel: context.l10n.shoppingFollowNoticeDismiss,
                onPressed: onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

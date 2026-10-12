// lib/views/social/shared_with_me/shared_menu_card.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/shared_content_row.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// A shared menu as a [SharedContentRow].
class SharedMenuCard {
  // A collaborative menu the user has joined opens live. An invitation not yet
  // joined opens the preview, whose join step adds them as a participant.
  static void _open(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
    bool isRead,
  ) {
    if (!isRead) {
      viewModel.menuViewModel.markAsViewed(sharedMenu);
    }
    final liveId =
        sharedMenu.allowCollaboration &&
            viewModel.menuViewModel.isMenuImported(sharedMenu)
        ? sharedMenu.realtimeMenuId
        : null;
    if (liveId != null) {
      unawaited(
        Navigator.pushNamed(
          context,
          Routes.realtimeMenu,
          arguments: {'menuId': liveId},
        ),
      );
      return;
    }
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: viewModel,
            child: MenuPreviewView(sharedMenu: sharedMenu),
          ),
        ),
      ),
    );
  }

  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedMenu sharedMenu,
  ) {
    final l10n = context.l10n;
    final menus = viewModel.menuViewModel;
    final isRead = menus.isMenuViewed(sharedMenu);
    final isCollaborative =
        sharedMenu.realtimeMenuId != null && sharedMenu.allowCollaboration;
    final fromAgo = l10n.sharedFromNameAgo(
      sharedMenu.sharedByDisplayName,
      timeago.format(sharedMenu.sharedAt, locale: 'sv'),
    );

    return SharedContentRow(
      leading: SharedKindThumb(
        icon: isCollaborative ? ButleryIcons.users : ButleryIcons.calendar,
      ),
      title: sharedMenu.menuTitle,
      subtitle: isCollaborative ? '$fromAgo · ${l10n.sharedLive}' : fromAgo,
      message: sharedMenu.shareMessage,
      unread: !isRead,
      saved: menus.isMenuImported(sharedMenu),
      saving: menus.isItemOperating(sharedMenu.id),
      onSave: () =>
          SharedContentActions.importMenu(context, viewModel, sharedMenu),
      onOpen: () => _open(context, viewModel, sharedMenu, isRead),
      onActions: () => showSharedContentActions(
        context,
        title: sharedMenu.menuTitle,
        onDismiss: () =>
            SharedContentActions.dismissMenu(context, viewModel, sharedMenu),
        onUnshare: () =>
            SharedContentActions.unshareMenu(context, viewModel, sharedMenu),
      ),
    );
  }
}

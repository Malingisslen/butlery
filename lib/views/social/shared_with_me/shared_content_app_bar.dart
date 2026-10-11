// lib/views/social/shared_with_me/shared_content_app_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

/// Named as Mer's row that opens the page, Back leading to Mer. No refresh
/// action: the lists are live and pull-to-refresh stays on the body.
class SharedContentAppBar {
  static PreferredSizeWidget build(BuildContext context) {
    return ButleryTopBar.undersida(
      title: context.l10n.profileSharedWithMe,
      backTo: context.l10n.moreTitle,
    );
  }
}

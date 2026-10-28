// lib/widgets/social/shared_receive_sheet.dart
//
// What opens when a shared recipe that is not yet in the user's own is
// tapped: who shared it, what they may do with it, and the choice to accept
// it or only look. A recipe that is already saved opens directly.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart'
    show FormButton;
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

enum SharedReceiveChoice { accept, view }

/// Resolves to what the user chose, or null when the sheet is dismissed.
Future<SharedReceiveChoice?> showSharedReceiveSheet(
  BuildContext context, {
  required String title,
  required String fromLine,
  required ResourcePermission permission,
  String? message,
}) {
  return showButlerySheet<SharedReceiveChoice>(
    context: context,
    builder: (_) => SharedReceiveSheet(
      title: title,
      fromLine: fromLine,
      permission: permission,
      message: message,
    ),
  );
}

class SharedReceiveSheet extends StatelessWidget {
  const SharedReceiveSheet({
    required this.title,
    required this.fromLine,
    required this.permission,
    this.message,
    super.key,
  });

  final String title;

  /// "från {name} · {time}", built by the caller from the stored name.
  final String fromLine;
  final ResourcePermission permission;
  final String? message;

  static const Key acceptKey = ValueKey<String>('test-receive-accept');
  static const Key viewKey = ValueKey<String>('test-receive-view');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = message;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.layoutMargin,
        0,
        AppDimensions.layoutMargin,
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.subpageTitle),
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            fromLine,
            style: AppTextStyles.captionBase.copyWith(color: muted),
          ),
          const SizedBox(height: AppDimensions.space8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: UnifiedBadge.status(
              label: permission.canEdit
                  ? l10n.sharedReceiveCanEdit
                  : l10n.sharedReceiveCanRead,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space12),
            Text(
              '”$note”',
              style: AppTextStyles.captionBase.copyWith(
                color: muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.space16),
          FormButton(
            key: acceptKey,
            label: l10n.sharedReceiveAccept,
            expand: true,
            onPressed: () =>
                Navigator.of(context).pop(SharedReceiveChoice.accept),
          ),
          ButleryTextButton(
            key: viewKey,
            label: l10n.sharedReceiveView,
            onPressed: () =>
                Navigator.of(context).pop(SharedReceiveChoice.view),
          ),
        ],
      ),
    );
  }
}

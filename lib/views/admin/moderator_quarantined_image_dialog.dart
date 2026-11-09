import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_appeals_viewmodel.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Fetches the quarantined image(s) behind an owner appeal and shows them to
/// the moderator.
Future<void> showQuarantinedImageDialog(
  BuildContext context,
  OpenAppeal appeal,
) {
  final future = context
      .read<ModeratorAppealsViewModel>()
      .loadQuarantinedImages(
        appeal,
      );
  return showButleryDialog<void>(
    context: context,
    builder: (_) => _QuarantinedImageDialog(future: future),
  );
}

class _QuarantinedImageDialog extends StatelessWidget {
  const _QuarantinedImageDialog({required this.future});

  final Future<QuarantinedImages?> future;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ButleryDialog(
      title: l10n.moderatorAppealImagesTitle,
      content: FutureBuilder<QuarantinedImages?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: AppDimensions.heightXLarge,
              child: StateWidget.loading(message: l10n.loadingImage),
            );
          }
          final data = snapshot.data;
          if (data == null || (data.images.isEmpty && data.omitted == 0)) {
            return Text(
              l10n.moderatorAppealImagesFailed,
              style: AppTextStyles.bodyMedium.copyWith(color: cs.error),
            );
          }
          final decodeWidth =
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final bytes in data.images)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.space8,
                  ),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    // Decode at display size, not at the upload's full size.
                    cacheWidth: decodeWidth,
                    errorBuilder: (context, error, stack) => Text(
                      l10n.moderatorAppealImagesFailed,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.error,
                      ),
                    ),
                  ),
                ),
              if (data.omitted > 0)
                Text(
                  l10n.moderatorAppealImagesOmitted(data.omitted),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          );
        },
      ),
      actions: [
        DialogCancelButton(label: l10n.commonClose),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/moderator_appeals_viewmodel.dart';

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
  return showDialog<void>(
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
    return AlertDialog(
      content: FutureBuilder<QuarantinedImages?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: AppDimensions.space32,
              child: Center(child: CircularProgressIndicator()),
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
          return SingleChildScrollView(
            child: Column(
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
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Invitation target state widgets.
class InvitationStates {
  /// Build target list loading state.
  static Widget targetListLoading({
    String? text = 'Laddar målgrupper...',
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Text(text),
          ],
        ],
      ),
    );
  }

  /// Build target card loading state
  static Widget targetCardLoading({
    int count = 3,
  }) {
    return Column(
      children: List.generate(
          count,
          (index) => const Card(
                child: ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Laddar...'),
                ),
              )),
    );
  }

  /// Build inline loading state
  static Widget inlineLoading({
    String? text = 'Laddar...',
    double size = 20.0,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        if (text != null) ...[
          const SizedBox(width: AppDimensions.spacingSm),
          Text(text),
        ],
      ],
    );
  }

  /// Build target loading error state.
  static Widget targetLoadingError(
    BuildContext context, {
    String? title = 'Kunde inte ladda målgrupper',
    String? message = 'Kontrollera din internetanslutning och försök igen.',
    VoidCallback? onRetry,
    String? retryText = 'Försök igen',
    IconData errorIcon = Icons.error_outline,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(errorIcon,
              size: AppDimensions.iconSizeXXXl, color: AppColors.error),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (message != null) Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(retryText ?? 'Försök igen'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build network error state
  static Widget networkError(
    BuildContext context, {
    String? title = 'Nätverksfel',
    String? message = 'Kontrollera din internetanslutning.',
    VoidCallback? onRetry,
    String? retryText = 'Försök igen',
  }) {
    return targetLoadingError(
      context,
      title: title,
      message: message,
      onRetry: onRetry,
      retryText: retryText,
      errorIcon: Icons.wifi_off,
    );
  }

  /// Build permission error state
  static Widget permissionError(
    BuildContext context, {
    String? title = 'Ingen åtkomst',
    String? message = 'Du har inte behörighet att se denna information.',
    VoidCallback? onRequestAccess,
    String? requestText = 'Begär åtkomst',
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock,
              size: AppDimensions.iconSizeXXXl, color: AppColors.warning),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (message != null) Text(message, textAlign: TextAlign.center),
          if (onRequestAccess != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onRequestAccess,
              child: Text(requestText ?? 'Begär åtkomst'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no targets available state.
  static Widget noTargetsAvailable(
    BuildContext context, {
    String? title = 'Inga målgrupper tillgängliga',
    String? message = 'Du har inte lagt till några vänner eller grupper än.',
    IconData icon = Icons.group_outlined,
    VoidCallback? onAddTargets,
    String? addButtonText = 'Lägg till vänner',
    bool showAddButton = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl, color: AppColors.textMedium),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (message != null) Text(message, textAlign: TextAlign.center),
          if (showAddButton && onAddTargets != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onAddTargets,
              child: Text(addButtonText ?? 'Lägg till vänner'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build no search results state
  static Widget noSearchResults(
    BuildContext context, {
    String? query,
    String? title = 'Inga sökresultat',
    String? message =
        'Prova att söka med andra ord eller kontrollera stavningen.',
    IconData icon = Icons.search_off,
    VoidCallback? onClearSearch,
    String? clearButtonText = 'Rensa sökning',
    bool showClearButton = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl, color: AppColors.textMedium),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (message != null) Text(message, textAlign: TextAlign.center),
          if (query != null)
            Text('Sökning: "$query"',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic)),
          if (showClearButton && onClearSearch != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            TextButton(
              onPressed: onClearSearch,
              child: Text(clearButtonText ?? 'Rensa sökning'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build empty selection state
  static Widget emptySelection(
    BuildContext context, {
    String? title = 'Inga valda målgrupper',
    String? message = 'Välj målgrupper från listan ovan för att fortsätta.',
    IconData icon = Icons.checklist_outlined,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl, color: AppColors.textMedium),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (message != null) Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Build targets selected success state.
  static Widget targetsSelectedSuccess(
    BuildContext context, {
    required int selectedCount,
    String? title = 'Målgrupper valda',
    String? message = 'Du har valt {count} målgrupper för inbjudan.',
    IconData icon = Icons.check_circle_outline,
    VoidCallback? onContinue,
    String? continueButtonText = 'Fortsätt',
    Color? successColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl,
              color: successColor ?? AppColors.success),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (message != null)
            Text(
              message.replaceAll('{count}', selectedCount.toString()),
              textAlign: TextAlign.center,
            ),
          if (onContinue != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onContinue,
              child: Text(continueButtonText ?? 'Fortsätt'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build invitation sent success state
  static Widget invitationSentSuccess(
    BuildContext context, {
    required int sentCount,
    String? title = 'Inbjudningar skickade',
    String? message = 'Inbjudningar har skickats till {count} målgrupper.',
    IconData icon = Icons.send,
    VoidCallback? onDone,
    String? doneButtonText = 'Klar',
    Color? successColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: AppDimensions.iconSizeXXXl,
              color: successColor ?? AppColors.success),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (message != null)
            Text(
              message.replaceAll('{count}', sentCount.toString()),
              textAlign: TextAlign.center,
            ),
          if (onDone != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton(
              onPressed: onDone,
              child: Text(doneButtonText ?? 'Klar'),
            ),
          ],
        ],
      ),
    );
  }

  /// Build upload progress state.
  static Widget uploadProgress(
    BuildContext context, {
    required double progress, // 0.0 to 1.0
    String? title = 'Skickar inbjudningar...',
    String? subtitle,
    bool showPercentage = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          if (title != null)
            Text(title,
                style: AppTextStyles.titleBold),
          if (showPercentage) Text('${(progress * 100).toInt()}%'),
          if (subtitle != null) Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Build batch operation progress
  static Widget batchOperationProgress(
    BuildContext context, {
    required int completed,
    required int total,
    String? operationName = 'Bearbetar',
    String? currentItem,
  }) {
    final progress = total > 0 ? completed / total : 0.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            '$operationName $completed av $total',
            style: AppTextStyles.text16Medium,
          ),
          if (currentItem != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Aktuell: $currentItem',
              style: AppTextStyles.bodyMediumMuted,
            ),
          ],
        ],
      ),
    );
  }
}

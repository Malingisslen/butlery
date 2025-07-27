// lib/widgets/common/social_components/invitation_states.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';

/// Focused module for invitation target state widgets
/// 
/// This module handles ONLY state presentations:
/// - Loading states (list, card, loading)
/// - Error states with retry options
/// - Empty states with actions
/// - Success states with feedback
/// 
/// ❌ DOES NOT CONTAIN: Display widgets, selectors, actions, lists
class InvitationStates {

  // ===== LOADING STATES =====

  /// Build target list loading state
  static Widget targetListLoading({
    String? text = 'Laddar målgrupper...',
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (text != null) ...[
            SizedBox(height: AppDimensions.spacing16),
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
      children: List.generate(count, (index) => const Card(
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
          SizedBox(width: AppDimensions.spacing8),
          Text(text),
        ],
      ],
    );
  }

  // ===== ERROR STATES =====

  /// Build target loading error state
  static Widget targetLoadingError({
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
          Icon(errorIcon, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (message != null)
            Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            SizedBox(height: AppDimensions.spacing16),
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
  static Widget networkError({
    String? title = 'Nätverksfel',
    String? message = 'Kontrollera din internetanslutning.',
    VoidCallback? onRetry,
    String? retryText = 'Försök igen',
  }) {
    return targetLoadingError(
      title: title,
      message: message,
      onRetry: onRetry,
      retryText: retryText,
      errorIcon: Icons.wifi_off,
    );
  }

  /// Build permission error state
  static Widget permissionError({
    String? title = 'Ingen åtkomst',
    String? message = 'Du har inte behörighet att se denna information.',
    VoidCallback? onRequestAccess,
    String? requestText = 'Begär åtkomst',
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (message != null)
            Text(message, textAlign: TextAlign.center),
          if (onRequestAccess != null) ...[
            SizedBox(height: AppDimensions.spacing16),
            ElevatedButton(
              onPressed: onRequestAccess,
              child: Text(requestText ?? 'Begär åtkomst'),
            ),
          ],
        ],
      ),
    );
  }

  // ===== EMPTY STATES =====

  /// Build no targets available state
  static Widget noTargetsAvailable({
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
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (message != null)
            Text(message, textAlign: TextAlign.center),
          if (showAddButton && onAddTargets != null) ...[
            SizedBox(height: AppDimensions.spacing16),
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
  static Widget noSearchResults({
    String? query,
    String? title = 'Inga sökresultat',
    String? message = 'Prova att söka med andra ord eller kontrollera stavningen.',
    IconData icon = Icons.search_off,
    VoidCallback? onClearSearch,
    String? clearButtonText = 'Rensa sökning',
    bool showClearButton = true,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (message != null)
            Text(message, textAlign: TextAlign.center),
          if (query != null)
            Text('Sökning: "$query"', style: const TextStyle(fontStyle: FontStyle.italic)),
          if (showClearButton && onClearSearch != null) ...[
            SizedBox(height: AppDimensions.spacing16),
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
  static Widget emptySelection({
    String? title = 'Inga valda målgrupper',
    String? message = 'Välj målgrupper från listan ovan för att fortsätta.',
    IconData icon = Icons.checklist_outlined,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (message != null)
            Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ===== SUCCESS STATES =====

  /// Build targets selected success state
  static Widget targetsSelectedSuccess({
    required int selectedCount,
    String? title = 'Målgrupper valda',
    String? message = 'Du har valt {count} målgrupper för inbjudan.',
    IconData icon = Icons.check_circle_outline,
    VoidCallback? onContinue,
    String? continueButtonText = 'Fortsätt',
    Color? successColor = Colors.green,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: successColor),
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (message != null)
            Text(
              message.replaceAll('{count}', selectedCount.toString()),
              textAlign: TextAlign.center,
            ),
          if (onContinue != null) ...[
            SizedBox(height: AppDimensions.spacing16),
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
  static Widget invitationSentSuccess({
    required int sentCount,
    String? title = 'Inbjudningar skickade',
    String? message = 'Inbjudningar har skickats till {count} målgrupper.',
    IconData icon = Icons.send,
    VoidCallback? onDone,
    String? doneButtonText = 'Klar',
    Color? successColor = Colors.green,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: successColor),
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (message != null)
            Text(
              message.replaceAll('{count}', sentCount.toString()),
              textAlign: TextAlign.center,
            ),
          if (onDone != null) ...[
            SizedBox(height: AppDimensions.spacing16),
            ElevatedButton(
              onPressed: onDone,
              child: Text(doneButtonText ?? 'Klar'),
            ),
          ],
        ],
      ),
    );
  }

  // ===== PROGRESS STATES =====

  /// Build upload progress state
  static Widget uploadProgress({
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
          const SizedBox(height: 16),
          if (title != null)
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (showPercentage)
            Text('${(progress * 100).toInt()}%'),
          if (subtitle != null)
            Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  /// Build batch operation progress
  static Widget batchOperationProgress({
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
          const SizedBox(height: 16),
          Text(
            '$operationName $completed av $total',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (currentItem != null) ...[
            SizedBox(height: AppDimensions.spacing8),
            Text(
              'Aktuell: $currentItem',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
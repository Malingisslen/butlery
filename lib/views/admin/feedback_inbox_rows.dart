import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/feedback_inbox_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/image/fullscreen_image_viewer.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Localized label for a triage status.
String feedbackStatusLabel(BuildContext context, FeedbackStatus status) {
  switch (status) {
    case FeedbackStatus.newReport:
      return context.l10n.adminFeedbackStatusNew;
    case FeedbackStatus.triaged:
      return context.l10n.adminFeedbackStatusTriaged;
    case FeedbackStatus.resolved:
      return context.l10n.adminFeedbackStatusResolved;
  }
}

class FeedbackRow extends StatelessWidget {
  final FeedbackEntry entry;
  const FeedbackRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.read<FeedbackInboxViewModel>();
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${entry.category.name.toUpperCase()} · '
                  '${_formatDate(entry.createdAt)}',
                  style: AppTextStyles.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusPill(label: feedbackStatusLabel(context, entry.status)),
            ],
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(entry.description, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppDimensions.space4),
          Text(
            '${entry.email ?? '—'} · ${entry.deviceInfo ?? '—'}',
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (entry.screenshotUrl != null) ...[
            const SizedBox(height: AppDimensions.space8),
            _Screenshot(url: entry.screenshotUrl!),
          ],
          if (entry.recentInteractions.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              '${context.l10n.adminFeedbackInteractions}: '
              '${_formatInteractions(entry.recentInteractions)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.space8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copyForClaude(context),
              icon: const ButleryIcon(
                ButleryIcons.copy,
                size: AppDimensions.iconSize18,
              ),
              label: Text(context.l10n.adminCopyForClaude),
            ),
          ),
          _StatusControl(entry: entry, vm: vm),
        ],
      ),
    );
  }

  /// Copies the full report as a ready-to-paste prompt so an admin can hand it
  /// straight to a fresh Claude session. Deterministic string build — no LLM.
  Future<void> _copyForClaude(BuildContext context) async {
    final confirmation = context.l10n.adminCopiedForClaude;
    final failure = context.l10n.adminCopyFailed;
    try {
      await Clipboard.setData(ClipboardData(text: _buildClaudePrompt(entry)));
    } catch (_) {
      if (!context.mounted) return;
      SnackBarUtils.showFailure(context, what: failure);
      return;
    }
    if (!context.mounted) return;
    SnackBarUtils.showSuccess(context, confirmation);
  }

  static String _buildClaudePrompt(FeedbackEntry entry) {
    final trail = entry.recentInteractions.isEmpty
        ? '—'
        : _formatInteractions(entry.recentInteractions);
    return 'Buggrapport från Butlery-beta. Fixa i detta repo.\n\n'
        'Kategori: ${_categoryLabel(entry.category)} · '
        '${_formatDate(entry.createdAt)}\n'
        'Enhet: ${entry.deviceInfo ?? '—'}\n'
        'E-post: ${entry.email ?? '—'}\n'
        'Användaren skrev: "${entry.description}"\n'
        'Skärmväg innan: $trail\n'
        'Skärmdump: ${entry.screenshotUrl ?? '—'}\n'
        'Feedback-ID: ${entry.id}';
  }

  static String _categoryLabel(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.bug:
        return 'Bugg';
      case FeedbackCategory.featureRequest:
        return 'Funktionsönskemål';
      case FeedbackCategory.general:
        return 'Allmänt';
    }
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  static String _formatInteractions(List<Map<String, dynamic>> items) {
    return items
        .map((e) => e['screenName']?.toString() ?? '?')
        .take(20)
        .join(' → ');
  }
}

class _Screenshot extends StatelessWidget {
  final String url;
  const _Screenshot({required this.url});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.adminScreenshotOpen,
      button: true,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: () => _openFullScreen(context),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxHeight: AppDimensions.heightXLarge,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
            ),
            child: _image(context, BoxFit.contain),
          ),
        ),
      ),
    );
  }

  /// Shared image widget. Storage download URLs lack CORS headers for the admin
  /// origin, so the default canvas/XHR path fails — falling back to an <img>
  /// element displays the cross-origin image without needing bucket CORS.
  Widget _image(BuildContext context, BoxFit fit) {
    final cs = Theme.of(context).colorScheme;
    return Image.network(
      // arch-allow: Image.network — admin CORS <img> fallback
      url,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: AppDimensions.heightXLarge,
          child: StateWidget.loading(message: context.l10n.loadingImage),
        );
      },
      errorBuilder: (context, _, __) => Padding(
        padding: const EdgeInsets.all(AppDimensions.space12),
        child: Row(
          children: [
            ButleryIcon(ButleryIcons.imageOff, color: cs.outline),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: Text(
                url,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    FullscreenImageViewer.open(
      context,
      [url],
      photoBuilder: (photoCtx, _) => _image(photoCtx, BoxFit.contain),
    );
  }
}

class _StatusControl extends StatelessWidget {
  final FeedbackEntry entry;
  final FeedbackInboxViewModel vm;
  const _StatusControl({required this.entry, required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(String, FeedbackStatus)>[
      (l10n.adminFeedbackStatusNew, FeedbackStatus.newReport),
      (l10n.adminFeedbackStatusTriaged, FeedbackStatus.triaged),
      (l10n.adminFeedbackStatusResolved, FeedbackStatus.resolved),
    ];
    return Wrap(
      spacing: AppDimensions.space8,
      children: [
        for (final (label, status) in options)
          PressFill(
            surface: entry.status == status
                ? PressSurface.ink
                : PressSurface.base,
            child: ChoiceChip(
              label: Text(label),
              selected: entry.status == status,
              onSelected: entry.status == status
                  ? null
                  : (_) => _setStatus(context, status),
            ),
          ),
      ],
    );
  }

  Future<void> _setStatus(BuildContext context, FeedbackStatus status) async {
    if (await vm.updateStatus(entry.id, status) || !context.mounted) return;
    SnackBarUtils.showFailure(
      context,
      what: context.l10n.adminFeedbackStatusFailed,
      preserved: context.l10n.adminFeedbackStatusPreserved,
      action: FailureAction.retry(() => _setStatus(context, status)),
    );
  }
}

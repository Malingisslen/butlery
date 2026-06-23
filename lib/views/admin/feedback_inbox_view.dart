import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/feedback_inbox_viewmodel.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Admin-only inbox listing beta feedback newest-first, with the screenshot,
/// interaction trail and device info captured at submission, plus a triage
/// status control. Reached only after the admin gate in `admin_main.dart`.
class FeedbackInboxView extends StatefulWidget {
  const FeedbackInboxView({super.key});

  @override
  State<FeedbackInboxView> createState() => _FeedbackInboxViewState();
}

class _FeedbackInboxViewState extends State<FeedbackInboxView> {
  late final FeedbackInboxViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = FeedbackInboxViewModel()..start();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FeedbackInboxViewModel>.value(
      value: _vm,
      child: const _FeedbackInboxContent(),
    );
  }
}

class _FeedbackInboxContent extends StatelessWidget {
  const _FeedbackInboxContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeedbackInboxViewModel>();
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.adminFeedbackInboxTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: context.l10n.adminSignOut,
            onPressed: () => ServiceLocator.get<AuthService>().signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StatusFilterBar(vm: vm),
        ),
      ),
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, FeedbackInboxViewModel vm) {
    if (vm.isLoading && vm.entries.isEmpty) {
      return StateWidget.loading();
    }
    if (vm.error != null && vm.entries.isEmpty) {
      return StateWidget.error(
        message: vm.error!,
        onAction: vm.start,
      );
    }
    if (vm.entries.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.adminFeedbackEmpty,
        icon: Icons.inbox_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: vm.entries.length + (vm.canLoadMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacingSm),
      itemBuilder: (context, i) {
        if (i >= vm.entries.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.paddingM,
            ),
            child: Center(
              child: OutlinedButton(
                onPressed: vm.loadMore,
                style: OutlinedButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(context.l10n.adminFeedbackLoadMore),
              ),
            ),
          );
        }
        final entry = vm.entries[i];
        return _FeedbackCard(key: ValueKey(entry.id), entry: entry);
      },
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final FeedbackInboxViewModel vm;
  const _StatusFilterBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(String, FeedbackStatus?)>[
      (l10n.adminFeedbackFilterAll, null),
      (l10n.adminFeedbackStatusNew, FeedbackStatus.newReport),
      (l10n.adminFeedbackStatusTriaged, FeedbackStatus.triaged),
      (l10n.adminFeedbackStatusResolved, FeedbackStatus.resolved),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          for (final (label, status) in options)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingSm),
              child: ChoiceChip(
                label: Text(label),
                selected: vm.statusFilter == status,
                shape: const RoundedRectangleBorder(),
                onSelected: (_) => vm.setStatusFilter(status),
              ),
            ),
        ],
      ),
    );
  }
}

/// Localized label for a triage status, shared by the pill and the controls.
String _statusLabel(BuildContext context, FeedbackStatus status) {
  switch (status) {
    case FeedbackStatus.newReport:
      return context.l10n.adminFeedbackStatusNew;
    case FeedbackStatus.triaged:
      return context.l10n.adminFeedbackStatusTriaged;
    case FeedbackStatus.resolved:
      return context.l10n.adminFeedbackStatusResolved;
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackEntry entry;
  const _FeedbackCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.read<FeedbackInboxViewModel>();
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
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
                _StatusPill(status: entry.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(entry.description, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${entry.email ?? '—'} · ${entry.deviceInfo ?? '—'}',
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (entry.screenshotUrl != null) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              _Screenshot(url: entry.screenshotUrl!),
            ],
            if (entry.recentInteractions.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                '${context.l10n.adminFeedbackInteractions}: '
                '${_formatInteractions(entry.recentInteractions)}',
                style: AppTextStyles.bodySmall.copyWith(color: cs.outline),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingSm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _copyForClaude(context),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: Text(context.l10n.adminCopyForClaude),
                style: TextButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                ),
              ),
            ),
            _StatusControl(entry: entry, vm: vm),
          ],
        ),
      ),
    );
  }

  /// Copies the full report as a ready-to-paste prompt so an admin can hand it
  /// straight to a fresh Claude session. Deterministic string build — no LLM.
  Future<void> _copyForClaude(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = context.l10n.adminCopiedForClaude;
    final failure = context.l10n.adminCopyFailed;
    try {
      await Clipboard.setData(ClipboardData(text: _buildClaudePrompt(entry)));
      messenger.showSnackBar(SnackBar(content: Text(confirmation)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
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
    );
  }

  /// Shared image widget. Storage download URLs lack CORS headers for the admin
  /// origin, so the default canvas/XHR path fails — falling back to an <img>
  /// element displays the cross-origin image without needing bucket CORS.
  Widget _image(BuildContext context, BoxFit fit) {
    final cs = Theme.of(context).colorScheme;
    return Image.network(
      url,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: AppDimensions.heightXLarge,
          child: StateWidget.loading(),
        );
      },
      errorBuilder: (context, _, __) => Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Row(
          children: [
            Icon(Icons.broken_image_outlined, color: cs.outline),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                url,
                style: AppTextStyles.bodySmall.copyWith(color: cs.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the screenshot in a zoomable full-screen viewer. Tap the dark
  /// backdrop to dismiss; pinch/scroll to zoom.
  void _openFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      // Lightbox scrim: a near-opaque dark backdrop is a content-relative
      // effect (makes the photo readable), not a themed surface — theme tokens
      // would be invisible against the image, so black is intentional here.
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppDimensions.paddingM),
        // SizedBox.expand gives the image a definite size (the dialog box) so
        // BoxFit.contain + the <img> fallback can't hit unbounded constraints.
        // The image fills the dialog, so there's no barrier left to tap —
        // an explicit close button (and Esc) is the reliable way out.
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: _image(dialogCtx, BoxFit.contain),
                ),
              ),
              Positioned(
                top: AppDimensions.spacingSm,
                right: AppDimensions.spacingSm,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  tooltip: dialogCtx.l10n.adminScreenshotClose,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
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
      spacing: AppDimensions.spacingSm,
      children: [
        for (final (label, status) in options)
          ChoiceChip(
            label: Text(label),
            selected: entry.status == status,
            shape: const RoundedRectangleBorder(),
            onSelected: entry.status == status
                ? null
                : (_) => vm.updateStatus(entry.id, status),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final FeedbackStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: AppDimensions.paddingXxs,
      ),
      color: cs.secondaryContainer,
      child: Text(
        _statusLabel(context, status),
        style: AppTextStyles.metadataEmphasized,
      ),
    );
  }
}

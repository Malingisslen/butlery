import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/admin/feedback_inbox_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/image/fullscreen_image_viewer.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/styled/styled_card.dart';

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
      appBar: ButleryTopBar.undersida(
        title: context.l10n.adminFeedbackInboxTitle,
        actions: [
          IconButton(
            icon: const ButleryIcon(ButleryIcons.logOut),
            tooltip: context.l10n.adminSignOut,
            onPressed: () => ServiceLocator.get<AuthService>().signOut(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_StatusFilterBar.ceilingHeight),
          child: _StatusFilterBar(vm: vm),
        ),
      ),
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, FeedbackInboxViewModel vm) {
    if (vm.isLoading && vm.entries.isEmpty) {
      return StateWidget.loading(message: context.l10n.loadingFeedbackEntries);
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
        icon: ButleryIcons.inbox,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.space12),
      itemCount: vm.entries.length + (vm.canLoadMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.space8),
      itemBuilder: (context, i) {
        if (i >= vm.entries.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.space12,
            ),
            child: Center(
              child: OutlinedButton(
                onPressed: vm.loadMore,
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

  /// The row's height at 200 % text, the ceiling ButleryTopBar sizes itself
  /// for.
  static double get ceilingHeight {
    final label = AppTextStyles.labelMedium;
    final line = ((label.fontSize ?? 14) * (label.height ?? 1.0) * 2.0)
        .ceilToDouble();
    final chip = math.max(
      AppDimensions.minTouchTarget,
      line + 2 * AppDimensions.space8,
    );
    return chip + 2 * AppDimensions.space8;
  }

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
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space8,
      ),
      child: Row(
        children: [
          for (final (label, status) in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: AppDimensions.space8,
              ),
              child: PressFill(
                surface: vm.statusFilter == status
                    ? PressSurface.ink
                    : PressSurface.base,
                child: ChoiceChip(
                  label: Text(label),
                  selected: vm.statusFilter == status,
                  onSelected: (_) => vm.setStatusFilter(status),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Localized label for a triage status.
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
    return StyledCard(
      padding: const EdgeInsets.all(AppDimensions.space12),
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
              StatusPill(label: _statusLabel(context, entry.status)),
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

  // A refused change is a failure snackbar with Försök igen, never the
  // inbox's load-error state and never the method name
  // (content-style-guide.md:87-97).
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

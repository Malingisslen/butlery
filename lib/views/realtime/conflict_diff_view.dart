/// BUT-1163: full-screen diff view for a resolved collaborative-edit conflict.
///
/// When the realtime conflict resolver picks a winner, last-write-wins is
/// silent — one user's edit can vanish. The [ConflictBanner] surfaces that a
/// conflict happened; this view lets the user see exactly *which fields* the
/// two snapshots disagreed on (their local version vs the collaborator's remote
/// version) and, if their version lost, re-apply it with one tap ("Behåll min
/// version").
///
/// It operates directly on the [ConflictEvent] payload — no ViewModel — because
/// it's a leaf detail screen with no persistent state of its own beyond an
/// in-flight save guard.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';

/// Renders a field-level local-vs-remote diff for a single [ConflictEvent].
class ConflictDiffView extends StatefulWidget {
  final ConflictEvent event;

  const ConflictDiffView({super.key, required this.event});

  /// Push the diff view as a full-screen route. Returns the future the route
  /// completes with when popped.
  static Future<void> show(BuildContext context, ConflictEvent event) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ConflictDiffView(event: event),
      ),
    );
  }

  @override
  State<ConflictDiffView> createState() => _ConflictDiffViewState();
}

class _ConflictDiffViewState extends State<ConflictDiffView> {
  bool _saving = false;

  late final ConflictDiff _diff = ConflictDiff.fromEvent(widget.event);

  bool get _localLost =>
      widget.event.chosenStrategy == ConflictResolutionStrategy.remoteWon;

  Future<void> _keepMyVersion() async {
    if (_saving) return;
    setState(() => _saving = true);

    final svc = ServiceLocator.tryGet<RealtimeSyncService>();
    if (svc == null) {
      if (mounted) {
        setState(() => _saving = false);
        SnackBarUtils.showError(context, context.l10n.conflictDiffKeepFailed);
      }
      return;
    }

    try {
      // Re-apply the user's overwritten version through the permission-checked
      // recovery path. recoverLocalVersion rebuilds the local content on top of
      // the latest remote's editCount+1 so the recovered version legitimately
      // wins the NEXT conflict too — re-persisting the captured snapshot as-is
      // would write back its stale (losing) editCount and risk the same silent
      // loss on the next concurrent edit.
      await svc.recoverLocalVersion(widget.event.localValue);
      if (!mounted) return;
      Navigator.of(context).pop();
      SnackBarUtils.showSuccess(context, context.l10n.conflictDiffKeptToast);
    } catch (e) {
      AppLogger.error('Failed to re-apply local version after conflict', e);
      if (!mounted) return;
      setState(() => _saving = false);
      SnackBarUtils.showError(context, context.l10n.conflictDiffKeepFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AdaptiveAppBar(
        title: context.l10n.conflictDiffTitle,
      ),
      body: SafeArea(
        child: _diff.isEmpty ? _buildNoChanges(context) : _buildDiffList(),
      ),
      bottomNavigationBar: _localLost ? _buildKeepBar(context) : null,
    );
  }

  Widget _buildNoChanges(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Text(
          context.l10n.conflictDiffNoChanges,
          textAlign: TextAlign.center,
          style: AppTextStyles.contentLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDiffList() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      itemCount: _diff.changedFields.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.spacingL),
      itemBuilder: (context, index) =>
          _DiffFieldCard(field: _diff.changedFields[index]),
    );
  }

  Widget _buildKeepBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: AppDimensions.elevationMedium,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _keepMyVersion,
              child: _saving
                  ? const SizedBox(
                      width: AppDimensions.iconSizeS,
                      height: AppDimensions.iconSizeS,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.conflictDiffKeepMine),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single changed field, showing the local and remote values stacked with
/// colour-coded accents (success = my version, warning = collaborator's).
class _DiffFieldCard extends StatelessWidget {
  final ConflictFieldDiff field;

  const _DiffFieldCard({required this.field});

  @override
  Widget build(BuildContext context) {
    final butlery = context.butleryColors;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.fieldKey,
            style: AppTextStyles.contentLabel.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _ValueRow(
            label: context.l10n.conflictDiffLocalLabel,
            text: field.localText,
            accent: butlery.success,
            background: butlery.success.withValues(
              alpha: AppDimensions.opacityVeryLight,
            ),
            textColor: cs.onSurface,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _ValueRow(
            label: context.l10n.conflictDiffRemoteLabel,
            text: field.remoteText,
            accent: butlery.warning,
            background: butlery.warning.withValues(
              alpha: AppDimensions.opacityVeryLight,
            ),
            textColor: cs.onSurface,
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String? text;
  final Color accent;
  final Color background;
  final Color textColor;

  const _ValueRow({
    required this.label,
    required this.text,
    required this.accent,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final value = text;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          left: BorderSide(
            color: accent,
            width: AppDimensions.borderWidthThick,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.captionText.copyWith(color: accent),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            value == null || value.isEmpty
                ? context.l10n.conflictDiffEmptyValue
                : value,
            style: AppTextStyles.contentLabel.copyWith(
              color: textColor,
              fontStyle: (value == null || value.isEmpty)
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

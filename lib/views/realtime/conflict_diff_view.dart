/// BUT-1163: full-screen diff view for a resolved collaborative-edit conflict.
///
/// When the realtime conflict resolver picks a winner, last-write-wins is
/// silent — one user's edit can vanish. The [ConflictBanner] surfaces that a
/// conflict happened; this view lets the user see exactly *which fields* the
/// two snapshots disagreed on (their local version vs the collaborator's remote
/// version) and choose which one applies:
/// - if their version lost, re-apply it with one tap ("Behåll min version");
/// - if their version won, put the other person's version back with one tap
///   ("Använd deras version").
///
/// The choice is the decision (produktregler.md:102, "Recept (eget)": both
/// versions are shown and the user chooses). PQ-02 = A (2026-09-23): someone
/// else's shared recipe gets the same choice as the owner's until the
/// suggestion store exists (package 6), so this view does not branch on
/// [ConflictEvent.entity].
///
/// What is drawn and what is built: Skarmar v12 del 3 #konflikt (:1164,
/// :1169, :1199) draws only the state where the OTHER version won ("Eriks
/// version gäller just nu") with three equal exits: "Behåll min version",
/// "Använd Eriks version" and "Stäng utan att skriva över". Here that state
/// (remoteWon) offers only "Behåll min version"; the drawn "Använd … version"
/// and "Stäng utan att skriva över" exits are not built there and stay an
/// open question. "Använd deras version" is offered in the state where MY
/// version won (localWon), which is not drawn: it rests on
/// produktregler.md:102 and PQ-02 = A (an interpretation), styled as the
/// drawing's outlined button. The label is name-free ("Använd deras
/// version"), matching the column label "Deras version", because a {name}s
/// genitive breaks on names ending in s, x or z (app_localizations.dart,
/// BUT-1797 note).
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
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

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

  /// Their version lost and differs from mine: offer to put it back.
  bool get _canUseTheirs =>
      widget.event.chosenStrategy == ConflictResolutionStrategy.localWon &&
      _diff.isNotEmpty;

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

  /// Puts the other person's version back. It goes through the same
  /// permission-checked recovery path as "Behåll min version": the snapshot
  /// is rebuilt on top of the latest editCount + 1, so it wins the next
  /// comparison and nothing is overwritten silently. The user's own version
  /// is only replaced because she chose it here; on failure hers still
  /// applies and she is told so.
  ///
  /// The write is hers, so the saved record names her as the editor, uid AND
  /// display name together: recoverLocalVersion stamps her uid, and the
  /// snapshot is given her profile name first, so it never says "Erik" next
  /// to her uid (BUT-1705: the profile name, never the Auth handle).
  ///
  /// The failure snackbar's "Försök igen" can outlive this route, so a retry
  /// after the view has closed does nothing rather than touch a disposed
  /// state.
  Future<void> _useTheirVersion() async {
    if (_saving || !mounted) return;
    setState(() => _saving = true);
    final myName =
        ServiceLocator.tryGet<UserService>()?.profileDisplayName ??
        context.l10n.displayUnknownUser;

    try {
      final svc = ServiceLocator.tryGet<RealtimeSyncService>();
      if (svc == null) {
        throw StateError('RealtimeSyncService is not registered');
      }
      await svc.recoverLocalVersion(
        widget.event.remoteValue.copyWithMetadata(
          lastEditedByDisplayName: myName,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      SnackBarUtils.showSuccess(context, context.l10n.conflictDiffUsedTheirs);
    } catch (e) {
      AppLogger.error('Failed to apply remote version after conflict', e);
      if (!mounted) return;
      setState(() => _saving = false);
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.conflictDiffUseTheirsFailed,
        preserved: context.l10n.conflictDiffUseTheirsKept,
        action: FailureAction.retry(_useTheirVersion),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      // The subpage bar (Komponentark v1 §01 pattern 2; Skarmar v12 del 3
      // 'Redigeringskonflikt' draws the back arrow; B-45).
      appBar: ButleryTopBar.undersida(title: context.l10n.conflictDiffTitle),
      body: SafeArea(
        child: _diff.isEmpty ? _buildNoChanges(context) : _buildDiffList(),
      ),
      bottomNavigationBar: _localLost
          ? _buildKeepBar(context)
          : _canUseTheirs
          ? _buildUseTheirsBar(context)
          : null,
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
            // Saving keeps the button's name and draws the plate line along
            // its bottom edge, never a spinner in its place (Komponentark
            // v1:365, :372; produktregler.md:902). What the button does is
            // unchanged (P4-U19 owns the recovery path and its look).
            child: BusyButtonSemantics(
              busy: _saving,
              name: context.l10n.conflictDiffKeepMine,
              child: FilledButton(
                key: const ValueKey('conflictDiff.keepMine'),
                onPressed: _saving ? PlateLineButton.ignore : _keepMyVersion,
                style: _saving
                    ? PlateLineButton.busyStyle(
                        null,
                        Theme.of(context).filledButtonTheme.style,
                      )
                    : null,
                child: Text(context.l10n.conflictDiffKeepMine),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Använd deras version" as the drawing's outlined button (Skarmar v12
  /// del 3:1199, 1.5 px ink outline). Saving keeps the name and draws the
  /// plate line, as the keep bar does (Komponentark v1:365, :372).
  Widget _buildUseTheirsBar(BuildContext context) {
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
            child: BusyButtonSemantics(
              busy: _saving,
              name: context.l10n.conflictDiffUseTheirs,
              child: OutlinedButton(
                key: const ValueKey('conflictDiff.useTheirs'),
                onPressed: _saving ? PlateLineButton.ignore : _useTheirVersion,
                style: _saving
                    ? PlateLineButton.busyStyle(
                        null,
                        Theme.of(context).outlinedButtonTheme.style,
                        onFill: false,
                      )
                    : null,
                child: Text(context.l10n.conflictDiffUseTheirs),
              ),
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

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/import/voice_import_viewmodel.dart';
import 'package:butlery/views/smart_import/import_result_handler.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/import/assisted_import_dialog.dart';
import 'package:butlery/widgets/import/voice_section_card.dart';

/// "Tala in recept" — guided voice dictation import (voice plan roadmap #2).
///
/// Direction B (Malin, 2026-07-13): all three sections as checklist cards
/// on ONE screen, recordable in any order, with direction A's big
/// microphone inside the active card. Every field stays typable — voice is
/// an offer, never a gate.
class VoiceImportView extends StatefulWidget {
  const VoiceImportView({
    super.key,
    this.permissionGateway = const DefaultPermissionGateway(),
  });

  /// Injectable per OsPermissionHelper's contract — tests stub statuses
  /// without touching plugin channels.
  final PermissionGateway permissionGateway;

  @override
  State<VoiceImportView> createState() => _VoiceImportViewState();
}

class _VoiceImportViewState extends State<VoiceImportView> {
  late final VoiceImportViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<VoiceImportViewModel>();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VoiceImportViewModel>.value(
      value: _vm,
      child: _VoiceImportContent(permissionGateway: widget.permissionGateway),
    );
  }
}

class _VoiceImportContent extends StatefulWidget {
  const _VoiceImportContent({required this.permissionGateway});

  final PermissionGateway permissionGateway;

  @override
  State<_VoiceImportContent> createState() => _VoiceImportContentState();
}

class _VoiceImportContentState extends State<_VoiceImportContent> {
  final Map<VoiceImportSection, TextEditingController> _controllers = {
    for (final s in VoiceImportSection.values) s: TextEditingController(),
  };
  VoiceImportViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<VoiceImportViewModel>();
    if (!identical(vm, _vm)) {
      _vm?.removeListener(_syncControllersFromVm);
      _vm = vm..addListener(_syncControllersFromVm);
    }
  }

  /// Reconciles the text fields with the viewmodel whenever a transcript
  /// lands OUTSIDE the manual-stop tap — the 3-min auto-stop path (review
  /// finding #1: without this, an auto-stopped dictation was invisible in
  /// the UI and one keystroke would overwrite it). User typing is safe:
  /// onChanged pushes to the VM first, so text always matches here.
  void _syncControllersFromVm() {
    final vm = _vm;
    if (vm == null || !mounted) return;
    for (final section in VoiceImportSection.values) {
      final controller = _controllers[section]!;
      if (vm.stateOf(section) == VoiceSectionState.idle &&
          controller.text != vm.textOf(section)) {
        controller.text = vm.textOf(section);
      }
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_syncControllersFromVm);
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onMicTap(VoiceImportSection section) async {
    final vm = context.read<VoiceImportViewModel>();

    if (vm.stateOf(section) == VoiceSectionState.recording) {
      final ok = await vm.stopRecording();
      if (!mounted) return;
      if (!ok) {
        SnackBarUtils.showInfo(context, context.l10n.voicePromptFailed);
      }
      // Success needs no manual controller write — the VM listener
      // (_syncControllersFromVm) reconciles for both manual and auto stops.
      return;
    }

    final granted = await OsPermissionHelper.requestWithRationale(
      context: context,
      permission: Permission.microphone,
      rationaleTitle: context.l10n.voiceImportMicRationaleTitle,
      // Generic body — the menu-specific one misstates purpose here
      // (same finding class as the search/comment mics, fixed 2026-07-14).
      rationaleBody: context.l10n.voiceMicRationaleBody,
      grantLabel: context.l10n.voicePromptMicGrant,
      permanentlyDeniedMessage: context.l10n.voicePromptMicPermanentlyDenied,
      openSettingsLabel: context.l10n.voicePromptOpenSettings,
      gateway: widget.permissionGateway,
    );
    if (!granted || !mounted) return;

    final started = await vm.startRecording(section);
    if (!mounted) return;
    if (!started) {
      // Model missing / mic busy — nothing was heard yet, so this is
      // "unavailable", not a failed interpretation.
      SnackBarUtils.showInfo(context, context.l10n.voiceUnavailable);
    }
  }

  Future<void> _onImport() async {
    final vm = context.read<VoiceImportViewModel>();
    final result = await vm.importRecipe();
    if (!mounted || result == null) return;

    if (result.isSuccess && result.recipe != null) {
      ImportResultHandler.navigateToRecipeEditor(context, result.recipe!);
      return;
    }
    if (result.needsAssistance && result.extractedText != null) {
      final assisted = await showAssistedImportDialog(
        context: context,
        extractedText: result.extractedText!,
        suggestedTitle: result.suggestedTitle,
        source: ImportSource.voice,
        preDetectedIngredientLines: result.likelyIngredientLines,
      );
      if (!mounted || assisted == null) return;
      ImportResultHandler.navigateToRecipeEditor(context, assisted);
      return;
    }
    SnackBarUtils.showInfo(
      context,
      result.error ?? context.l10n.voiceImportFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VoiceImportViewModel>();
    final cs = Theme.of(context).colorScheme;

    final sections = [
      (
        section: VoiceImportSection.title,
        title: context.l10n.voiceImportSectionTitle,
        prompt: context.l10n.voiceImportPromptTitle,
        multiline: false,
      ),
      (
        section: VoiceImportSection.ingredients,
        title: context.l10n.voiceImportSectionIngredients,
        prompt: context.l10n.voiceImportPromptIngredients,
        multiline: true,
      ),
      (
        section: VoiceImportSection.steps,
        title: context.l10n.voiceImportSectionSteps,
        prompt: context.l10n.voiceImportPromptSteps,
        multiline: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.voiceImportTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: LayoutComponents.valueFor(
              context: context,
              mobile: double.infinity,
              tablet: 700,
              desktop: 800,
            ),
          ),
          child: ListView(
            padding: AppDimensions.responsiveContentPadding(context),
            children: [
              Text(
                context.l10n.voiceImportIntro,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              for (final s in sections) ...[
                VoiceSectionCard(
                  key: ValueKey('voice-section-${s.section.name}'),
                  index: s.section.index + 1,
                  title: s.title,
                  prompt: s.prompt,
                  state: vm.stateOf(s.section),
                  isDone: vm.isDone(s.section),
                  enabled: !vm.hasActiveCapture && !vm.isImporting,
                  controller: _controllers[s.section]!,
                  multiline: s.multiline,
                  onMicTap: () => _onMicTap(s.section),
                  onChanged: (v) => vm.updateText(s.section, v),
                ),
                const SizedBox(height: AppDimensions.spacingM),
              ],
              const SizedBox(height: AppDimensions.spacingS),
              Semantics(
                identifier: 'btn-voice-import-submit',
                button: true,
                enabled: vm.canImport,
                label: context.l10n.voiceImportSubmit,
                child: ActionButtons.primaryButton(
                  context,
                  label: context.l10n.voiceImportSubmit,
                  icon: Icons.download_done,
                  onPressed: vm.canImport ? _onImport : null,
                  isLoading: vm.isImporting,
                  loadingText: context.l10n.voiceImportImporting,
                ),
              ),
              if (!vm.canImport && !vm.isImporting)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.spacingS),
                  child: Text(
                    context.l10n.voiceImportSubmitHint,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

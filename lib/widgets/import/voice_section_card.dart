import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/import/voice_import_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// One checklist card of the "Tala in recept" wizard (direction B with A's
/// big microphone in the active card — Malin's pick 2026-07-13).
///
/// States: waiting (quiet mic), recording (large central stop, error color),
/// preparing/transcribing (LoadingIndicator), done (checkmark). The text
/// field is ALWAYS typable — typing is the permission-denial and
/// transcription-failure fallback, so the card never dead-ends.
class VoiceSectionCard extends StatelessWidget {
  const VoiceSectionCard({
    super.key,
    required this.index,
    required this.title,
    required this.prompt,
    required this.state,
    required this.isDone,
    required this.enabled,
    required this.controller,
    required this.onMicTap,
    required this.onChanged,
    this.multiline = false,
  });

  final int index;
  final String title;
  final String prompt;
  final VoiceSectionState state;
  final bool isDone;

  /// False while another card records or the import runs — the mic is
  /// paused but typing stays available.
  final bool enabled;
  final TextEditingController controller;
  final VoidCallback onMicTap;
  final ValueChanged<String> onChanged;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recording = state == VoiceSectionState.recording;
    final busy =
        state == VoiceSectionState.preparing ||
        state == VoiceSectionState.transcribing;

    // Square design language: no rounded corners; green left accent, done
    // cards keep the rust bottom accent used by content cards.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(
            color: recording
                ? cs.error
                : isDone
                ? cs.primary
                : cs.outlineVariant,
            width: 4,
          ),
          bottom: BorderSide(
            color: isDone ? cs.secondary : cs.outlineVariant,
            width: isDone ? 3 : 1,
          ),
          top: BorderSide(color: cs.outlineVariant),
          right: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$index · $title',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Checkmark and mic COEXIST on a done card: re-dictating a
              // single section is direction B's core promise ("gör om bara
              // ingredienserna" = one tap), so the mic never disappears
              // (review finding #5).
              if (isDone) Icon(Icons.check, color: cs.primary),
              if (!recording && !busy)
                Semantics(
                  identifier: 'btn-voice-record-$index',
                  button: true,
                  label: prompt,
                  child: IconButton(
                    icon: Icon(Icons.mic_none, color: cs.primary),
                    tooltip: prompt,
                    onPressed: enabled ? onMicTap : null,
                  ),
                ),
            ],
          ),
          Text(
            prompt,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          if (recording)
            // Direction A's big central microphone, grafted into the active
            // card: one large stop control, impossible to miss mid-speech.
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingM,
                ),
                child: Semantics(
                  identifier: 'btn-voice-stop-$index',
                  button: true,
                  label: context.l10n.voicePromptStop,
                  child: InkWell(
                    onTap: onMicTap,
                    child: Container(
                      width: 88,
                      height: 88,
                      color: cs.error,
                      child: Icon(
                        Icons.stop,
                        size: 40,
                        color: cs.onError,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (busy)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                child: Tooltip(
                  message: state == VoiceSectionState.preparing
                      ? context.l10n.voicePromptPreparing
                      : context.l10n.voicePromptTranscribing,
                  child: const LoadingIndicator(
                    size: AppDimensions.iconSizeAction,
                  ),
                ),
              ),
            )
          else
            TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: multiline ? null : 1,
              minLines: multiline ? 3 : 1,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: context.l10n.voiceImportTypeHint,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
                isDense: true,
              ),
            ),
          if (recording)
            Center(
              child: Text(
                context.l10n.voiceImportRecordingHint,
                style: AppTextStyles.bodySmall.copyWith(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }
}

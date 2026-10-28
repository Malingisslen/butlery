import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/import/voice_import_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/voice/voice_mic_button.dart';
import 'package:butlery/widgets/common/input/styled_input.dart';

/// One part of the "Tala in recept" page: the
/// numbered heading, its prompt, then the field with the microphone beside it
/// and a hairline under. The field is ALWAYS typable — typing is the
/// permission-denial and transcription-failure fallback, so a part never
/// dead-ends; while it listens the field waits and the button says so.
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

  /// False while another part records or the import runs — the mic is
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

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space16),
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
                // Done and re-dictatable at once: "gör om bara ingredienserna"
                // is one tap, so the mic stays beside a finished part.
                if (isDone)
                  ButleryIcon(ButleryIcons.check, color: cs.onSurface),
              ],
            ),
            Text(
              prompt,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.space12),
            if (busy)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.space8),
                // The plate line with its text, never a spinner
                // (B-18).
                child: Center(
                  child: PlateLineMessage(
                    message: state == VoiceSectionState.preparing
                        ? context.l10n.voicePromptPreparing
                        : context.l10n.voicePromptTranscribing,
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StyledInput(
                      hint: context.l10n.voiceImportTypeHint,
                      controller: controller,
                      onChanged: onChanged,
                      enabled: !recording,
                      maxLines: multiline ? null : 1,
                      minLines: multiline ? 3 : 1,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  VoiceMicButton(
                    identifier: recording
                        ? 'btn-voice-stop-$index'
                        : 'btn-voice-record-$index',
                    listening: recording,
                    label: recording ? context.l10n.voicePromptStop : prompt,
                    listeningWord: context.l10n.voiceListeningWord,
                    onTap: recording || enabled ? onMicTap : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

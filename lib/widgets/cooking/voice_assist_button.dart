// lib/widgets/cooking/voice_assist_button.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/cooking/cooking_voice_controller.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// Köksbutlern's mic control (tasks/koksbutlern-plan.md, Batch D) — the big,
/// knuckle-friendly button bottom-right of the instructions panel that
/// drives a [CookingVoiceController]. Icon/color track the controller's
/// state; the button owns nothing of the voice logic itself.
///
/// Square design language throughout (no `BorderRadius`). The pulsing
/// "listening" animation only ever runs while [CookingVoiceController.state]
/// is [VoiceAssistState.listening], and is skipped entirely under
/// `MediaQuery.disableAnimations` (reduced motion) in favor of a static
/// high-contrast state.
class VoiceAssistButton extends StatefulWidget {
  const VoiceAssistButton({
    super.key,
    required this.controller,
    required this.onEnsurePermission,
  });

  /// The state machine this button reflects and drives. Owned by the
  /// caller (cooking mode view) — this widget never constructs or disposes
  /// it.
  final CookingVoiceController controller;

  /// Runs the mic permission (and first-use model-prepare) flow; resolves
  /// true when the button may proceed to open the mic. Called before every
  /// tap that would start a capture — cheap once permission is already
  /// granted, since the underlying check short-circuits.
  final Future<bool> Function() onEnsurePermission;

  @override
  State<VoiceAssistButton> createState() => _VoiceAssistButtonState();
}

class _VoiceAssistButtonState extends State<VoiceAssistButton>
    with SingleTickerProviderStateMixin {
  static const double _buttonEdge = 56;

  late final AnimationController _pulse = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncPulse);
    // No _syncPulse() here: it reads MediaQuery, which is unsafe before
    // first build — and the ListenableBuilder's first build runs it anyway.
  }

  @override
  void didUpdateWidget(covariant VoiceAssistButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncPulse);
      widget.controller.addListener(_syncPulse);
      _syncPulse();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPulse);
    _pulse.dispose();
    super.dispose();
  }

  /// The pulse only animates while actually listening — starting it
  /// unconditionally in [initState] would leave a widget test's
  /// `pumpAndSettle()` spinning forever on a repeating animation.
  void _syncPulse() {
    if (!mounted) return;
    final shouldPulse =
        widget.controller.state == VoiceAssistState.listening &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  Future<void> _handleTap() async {
    final state = widget.controller.state;
    // Idle and speaking (barge-in) both lead into a capture; transcribing
    // is busy (ignored by the controller itself); listening is the "stop"
    // tap and needs no permission re-check.
    final startsCapture =
        state == VoiceAssistState.idle || state == VoiceAssistState.speaking;
    if (startsCapture) {
      final granted = await widget.onEnsurePermission();
      if (!granted) return;
    }
    await widget.controller.onMicPressed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        _syncPulse();
        final state = widget.controller.state;
        final showWindowHint = state == VoiceAssistState.listening;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showWindowHint)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.spacingXs,
                ),
                child: Text(
                  context.l10n.voiceAssistWindowHint,
                  style: AppTextStyles.bodySmall.copyWith(color: cs.onPrimary),
                ),
              ),
            _buildButton(context, cs, state),
          ],
        );
      },
    );
  }

  Widget _buildButton(
    BuildContext context,
    ColorScheme cs,
    VoiceAssistState state,
  ) {
    final l10n = context.l10n;

    late final Color background;
    late final Widget content;
    late final String label;
    switch (state) {
      case VoiceAssistState.idle:
        background = cs.primary;
        content = Icon(
          Icons.mic_none,
          color: cs.onPrimary,
          size: AppDimensions.iconSizeXl,
        );
        label = l10n.voiceAssistMicTooltip;
      case VoiceAssistState.listening:
        background = cs.error;
        content = Icon(
          Icons.stop,
          color: cs.onError,
          size: AppDimensions.iconSizeXl,
        );
        // Reuses the existing "klar, tolka" tooltip (voice_prompt_button's
        // stop label) rather than minting a near-duplicate key.
        label = l10n.voicePromptStop;
      case VoiceAssistState.transcribing:
        background = cs.primary;
        content = LoadingIndicator(
          size: AppDimensions.iconSizeL,
          color: cs.onPrimary,
          semanticLabel: l10n.voicePromptTranscribing,
        );
        label = l10n.voicePromptTranscribing;
      case VoiceAssistState.speaking:
        background = cs.primary;
        content = Icon(
          Icons.volume_up,
          color: cs.onPrimary,
          size: AppDimensions.iconSizeXl,
        );
        label = l10n.voiceAssistMicTooltip;
    }

    final square = Container(
      width: _buttonEdge,
      height: _buttonEdge,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background),
      child: content,
    );

    final pulsing = state == VoiceAssistState.listening
        ? ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: square,
          )
        : square;

    return Semantics(
      identifier: 'btn-cooking-voice',
      label: label,
      button: true,
      child: GestureDetector(
        onTap: state == VoiceAssistState.transcribing ? null : _handleTap,
        child: pulsing,
      ),
    );
  }
}

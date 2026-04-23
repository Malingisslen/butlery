import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/ping.dart';
import 'package:butlery/services/social/ping_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Show the ping compose sheet for [targetUserId] in [groupId].
///
/// Helper matches the `showModalBottomSheet` convention used elsewhere in the
/// codebase — the long-press handler in [FamilyPresenceBar] just calls this.
Future<void> showPingComposeSheet({
  required BuildContext context,
  required String groupId,
  required String targetUserId,
  PingService? pingServiceOverride,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    isScrollControlled: true,
    builder: (_) => PingComposeSheet(
      groupId: groupId,
      targetUserId: targetUserId,
      pingService: pingServiceOverride,
    ),
  );
}

/// Compose-a-ping sheet. Self-contained — manages its own local state and
/// looks up the [PingService] via [ServiceLocator] unless one is injected.
class PingComposeSheet extends StatefulWidget {
  const PingComposeSheet({
    required this.groupId,
    required this.targetUserId,
    this.pingService,
    super.key,
  });

  final String groupId;
  final String targetUserId;

  /// Test seam: inject a service instead of hitting [ServiceLocator]. Keeps
  /// widget tests free of the DI container.
  final PingService? pingService;

  @override
  State<PingComposeSheet> createState() => _PingComposeSheetState();
}

class _PingComposeSheetState extends State<PingComposeSheet> {
  PingType? _selectedType;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  String? _inlineError;

  PingService get _pingService =>
      widget.pingService ?? ServiceLocator.get<PingService>();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _selectType(PingType type) {
    setState(() {
      _selectedType = type;
      // A fresh selection clears prior rate-limit error — user is trying again.
      _inlineError = null;
    });
  }

  Future<void> _handleSend() async {
    final type = _selectedType;
    if (type == null || _isSending) return;

    setState(() {
      _isSending = true;
      _inlineError = null;
    });

    final message = _messageController.text.trim();
    try {
      await _pingService.sendPing(
        groupId: widget.groupId,
        toUserId: widget.targetUserId,
        type: type,
        message: message.isEmpty ? null : message,
      );

      if (!mounted) return;
      // Haptic is fire-and-forget — awaiting the platform channel hangs in
      // widget tests (no handler registered), and the user doesn't need us
      // to block on the buzz anyway.
      HapticFeedback.mediumImpact();

      // Capture the messenger + localized string BEFORE popping — once the
      // sheet is gone its context is deactivated and `ScaffoldMessenger.of`
      // can't walk the now-detached element tree.
      final messenger = ScaffoldMessenger.of(context);
      final sentLabel = context.l10n.pingComposeSent;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(sentLabel),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PingRateLimitedException {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _inlineError = context.l10n.pingRateLimited;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorGeneric),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: l10n.pingComposeTitle),
              const SizedBox(height: AppDimensions.spacingMd),
              _TypeChipRow(
                selected: _selectedType,
                onSelect: _selectType,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              _MessageField(controller: _messageController),
              if (_inlineError != null) ...[
                const SizedBox(height: AppDimensions.spacingSm),
                _InlineError(message: _inlineError!),
              ],
              const SizedBox(height: AppDimensions.spacingLg),
              _SendButton(
                enabled: _selectedType != null && !_isSending,
                isLoading: _isSending,
                onPressed: _handleSend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(
        color: AppColors.forestGreenDark,
        fontWeight: FontWeight.w700,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _TypeChipRow extends StatelessWidget {
  const _TypeChipRow({
    required this.selected,
    required this.onSelect,
  });

  final PingType? selected;
  final ValueChanged<PingType> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _TypeChip(
            key: const Key('ping-type-nudge'),
            label: l10n.pingNudge,
            icon: Icons.back_hand_outlined,
            selected: selected == PingType.nudge,
            onTap: () => onSelect(PingType.nudge),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: _TypeChip(
            key: const Key('ping-type-timer'),
            label: l10n.pingTimerAlert,
            icon: Icons.timer_outlined,
            selected: selected == PingType.timerAlert,
            onTap: () => onSelect(PingType.timerAlert),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: _TypeChip(
            key: const Key('ping-type-help'),
            label: l10n.pingHelpMe,
            icon: Icons.help_outline,
            selected: selected == PingType.helpMe,
            onTap: () => onSelect(PingType.helpMe),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.cream : AppColors.forestGreenDark;
    final bg = selected ? AppColors.forestGreen : AppColors.creamDark;
    final border = selected
        ? AppColors.forestGreen
        : AppColors.forestGreen.withValues(alpha: 0.3);

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingSm,
            vertical: AppDimensions.spacingMd,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppDimensions.iconSizeM, color: fg),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageField extends StatelessWidget {
  const _MessageField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('ping-message-field'),
      controller: controller,
      maxLength: kPingMaxMessageLength,
      maxLines: 2,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: context.l10n.pingComposeMessageHint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textLight,
        ),
        filled: true,
        fillColor: AppColors.cardWhite,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.forestGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: AppColors.forestGreen.withValues(alpha: 0.3),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ping-inline-error'),
      padding: const EdgeInsets.all(AppDimensions.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: AppDimensions.iconSizeS,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? AppColors.forestGreenDark : AppColors.greenMuted;

    return InkWell(
      key: const Key('ping-send-button'),
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacingMd,
        ),
        decoration: BoxDecoration(color: bg),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.cream),
                ),
              )
            : Text(
                context.l10n.pingComposeSend,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

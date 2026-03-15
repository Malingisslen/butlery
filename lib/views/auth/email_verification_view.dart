import 'dart:async';
import 'package:flutter/material.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/l10n/app_localizations.dart';

/// Soft-gate verification screen shown to new users after registration.
/// Polls for email verification status and auto-navigates when verified.
class EmailVerificationView extends StatefulWidget {
  final String email;
  final VoidCallback? onDismiss;

  const EmailVerificationView({
    super.key,
    required this.email,
    this.onDismiss,
  });

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 5);
  static const _resendCooldown = Duration(seconds: 60);

  late final AuthService _authService;
  Timer? _pollTimer;
  bool _isSending = false;
  bool _verified = false;
  String? _errorMessage;
  DateTime? _lastResendTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService = ServiceLocator.get<AuthService>();
    _scheduleNextPoll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restart polling when app returns to foreground
      if (_pollTimer == null || !_pollTimer!.isActive) {
        _scheduleNextPoll();
      }
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  /// Sequential timer — schedules next poll only after current one completes.
  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(_pollInterval, () async {
      if (_verified) return;

      // Check cached state first to avoid unnecessary network call
      if (_authService.isEmailVerified) {
        if (mounted) setState(() => _verified = true);
        return;
      }

      await _authService.reloadUser();
      if (_authService.isEmailVerified && mounted) {
        setState(() => _verified = true);
        return;
      }

      if (mounted) _scheduleNextPoll();
    });
  }

  bool get _canResend {
    if (_lastResendTime == null) return true;
    return DateTime.now().difference(_lastResendTime!) >= _resendCooldown;
  }

  int get _resendCooldownRemaining {
    if (_lastResendTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastResendTime!);
    final remaining = _resendCooldown - elapsed;
    return remaining.inSeconds.clamp(0, _resendCooldown.inSeconds);
  }

  Future<void> _resendVerification() async {
    if (!_canResend) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendEmailVerification();
      _lastResendTime = DateTime.now();
    } catch (_) {
      if (mounted) {
        // Use service error message if available, fall back to generic
        final serviceError = _authService.errorMessage;
        setState(() {
          _errorMessage = (serviceError != null && serviceError.isNotEmpty)
              ? serviceError
              : AppLocalizations.of(context).errorNetwork;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_verified) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 64, color: cs.primary),
              const SizedBox(height: AppDimensions.spacingM),
              Text(l.emailVerificationSuccess, style: tt.titleLarge),
            ],
          ),
        ),
      );
    }

    final resendDisabled = _isSending || !_canResend;
    final cooldownText = !_canResend
        ? '${l.emailVerificationResend} (${_resendCooldownRemaining}s)'
        : l.emailVerificationResend;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      size: 80, color: cs.primary),
                  const SizedBox(height: AppDimensions.spacingXl),
                  Text(
                    l.emailVerificationTitle,
                    style: tt.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(
                    l.emailVerificationMessage(widget.email),
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      _errorMessage!,
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingXxl),
                  StyledButton(
                    text: cooldownText,
                    onPressed: resendDisabled ? null : _resendVerification,
                    isLoading: _isSending,
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  TextButton(
                    onPressed: () {
                      _pollTimer?.cancel();
                      widget.onDismiss?.call();
                    },
                    child: Text(
                      l.emailVerificationContinue,
                      style: tt.bodyMedium?.copyWith(color: cs.outline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

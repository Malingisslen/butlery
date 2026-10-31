/// Shown instead of [ErrorApp] when the start stopped because the encrypted
/// local database cannot be opened: its key is gone or cannot be read. The app
/// never deletes the file on its own in that state.
library;

import 'package:flutter/material.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';

/// Whether [error], the reason the start stopped, is the locked local
/// database. Matched on the text because the key errors reach `main` wrapped
/// (a DI module exception carries them as its cause and prints them), and
/// because their types live in a file the web build must not import.
bool isLocalDataLocked(Object error) {
  final text = error.toString();
  return text.contains('DatabaseKeyLost') ||
      text.contains('DatabaseKeyUnavailable');
}

class LocalDataLockedApp extends StatefulWidget {
  const LocalDataLockedApp({
    super.key,
    required this.onRetry,
    required this.onStartOver,
  });

  /// Starts the app again without touching anything.
  final VoidCallback onRetry;

  /// Deletes the local database and starts again. Called only after the
  /// confirmation.
  final Future<void> Function() onStartOver;

  static const String title = 'Den lokala datan går inte att öppna';
  static const String explanation =
      'Dina recept och listor i molnet är kvar. Det som bara fanns på den här '
      'telefonen och inte hunnit synkas försvinner om du börjar om.';
  static const String retryLabel = 'Försök igen';
  static const String startOverLabel = 'Börja om med tom lokal data';
  static const String confirmTitle = 'Är du säker?';
  static const String confirmBody =
      'Ändringar som inte hunnit skickas till molnet går förlorade. '
      'Vi kan inte se hur många de är.';
  static const String cancelLabel = 'Avbryt';
  static const String confirmLabel = 'Ja, börja om';
  static const String startOverFailed =
      'Det gick inte att börja om. Starta om telefonen och försök igen.';

  @override
  State<LocalDataLockedApp> createState() => _LocalDataLockedAppState();
}

class _LocalDataLockedAppState extends State<LocalDataLockedApp> {
  bool _busy = false;
  bool _failed = false;

  // A start that stops on the lock again calls runApp with a new screen of
  // the same type, which reuses this state; without the reset the buttons
  // would stay disabled from the attempt that just ended.
  @override
  void didUpdateWidget(LocalDataLockedApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _busy = false;
    _failed = false;
  }

  Future<void> _confirmAndStartOver(BuildContext context) async {
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: LocalDataLockedApp.confirmTitle,
      message: LocalDataLockedApp.confirmBody,
      primaryActionText: LocalDataLockedApp.confirmLabel,
      secondaryActionText: LocalDataLockedApp.cancelLabel,
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onStartOver();
    } catch (_) {
      // The exception text is not shown or logged: a platform error can name
      // the file or the key.
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Butlery',
      theme: AppTheme.lightTheme,
      // The shared dialog reads its own button texts from the localisations.
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: cs.surface,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppDimensions.space24),
                    Semantics(
                      header: true,
                      child: Text(
                        LocalDataLockedApp.title,
                        style: AppTextStyles.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space8),
                    Text(
                      LocalDataLockedApp.explanation,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (_failed) ...[
                      const SizedBox(height: AppDimensions.space16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          LocalDataLockedApp.startOverFailed,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.space24),
                    ActionButtons.secondaryButton(
                      context,
                      label: LocalDataLockedApp.retryLabel,
                      onPressed: _busy ? null : widget.onRetry,
                      isExpanded: true,
                    ),
                    const SizedBox(height: AppDimensions.space12),
                    ActionButtons.primaryButton(
                      context,
                      label: LocalDataLockedApp.startOverLabel,
                      onPressed: _busy
                          ? null
                          : () => _confirmAndStartOver(context),
                      isLoading: _busy,
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

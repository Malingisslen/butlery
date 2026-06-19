/// Admin dashboard entry point — a separate Flutter-web build
/// (`flutter build web -t lib/admin_main.dart`) deployed to its own Firebase
/// Hosting site. It reuses the consumer app's data layer (DI modules, models,
/// repositories, theme) but renders a minimal admin shell instead of
/// [ButleryApp], so none of this ships in the consumer bundle.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:butlery/core/bootstrap/app_modules.dart';
import 'package:butlery/core/bootstrap/application_bootstrap.dart';
import 'package:butlery/core/bootstrap/firestore_bootstrap.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/firebase_options.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/admin/admin_shell.dart';
import 'package:butlery/widgets/common/state_widget.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kIsWeb) usePathUrlStrategy();

      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await FirestoreBootstrap.configure();
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaV3Provider(
            '6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo',
          ),
        );
        await ApplicationBootstrap.initialize(
          modules: buildDiModules(),
          stages: buildBootstrapStages(),
        );
        runApp(const AdminApp());
      } catch (e, st) {
        AppLogger.error('Admin app failed to initialize: $e', st);
        runApp(_AdminBootError(message: '$e'));
      }
    },
    (error, stack) => AppLogger.error('Admin zone error: $error', stack),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Butlery Admin',
      theme: AppTheme.lightThemeWith(null),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _AdminRoot(),
    );
  }
}

/// Decides between the login screen, the admin gate, and the dashboard based on
/// auth + admin state.
class _AdminRoot extends StatefulWidget {
  const _AdminRoot();

  @override
  State<_AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<_AdminRoot> {
  late final AuthService _authService;
  late final ReportService _reportService;

  @override
  void initState() {
    super.initState();
    _authService = ServiceLocator.get<AuthService>();
    _reportService = ServiceLocator.get<ReportService>();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authService,
      builder: (context, _) {
        if (!_authService.isAuthenticated) {
          return _AdminLoginScreen(authService: _authService);
        }
        // Authenticated — gate on admin status (admins/{uid} existence).
        return StreamBuilder<bool>(
          stream: _reportService.watchIsAdmin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: StateWidget.loading());
            }
            if (snapshot.data ?? false) {
              return const AdminShell();
            }
            return _AdminNotAuthorized(onSignOut: _authService.signOut);
          },
        );
      },
    );
  }
}

class _AdminLoginScreen extends StatefulWidget {
  final AuthService authService;
  const _AdminLoginScreen({required this.authService});

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final ok = await widget.authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (!ok) setState(() => _error = context.l10n.adminLoginFailed);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.adminLoginFailed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Butlery Admin',
                  style: AppTextStyles.headlineBold,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.l10n.feedbackEmailLabel,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: context.l10n.adminPasswordLabel,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(_error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: AppDimensions.spacingLg),
                SizedBox(
                  height: AppDimensions.buttonHeight,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: Text(context.l10n.adminLoginButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminNotAuthorized extends StatelessWidget {
  final Future<void> Function() onSignOut;
  const _AdminNotAuthorized({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: cs.outline),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                context.l10n.adminNotAuthorized,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              TextButton(
                onPressed: onSignOut,
                child: Text(context.l10n.adminSignOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBootError extends StatelessWidget {
  final String message;
  const _AdminBootError({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // This fallback renders before localization is available, so its single
      // string is hardcoded Swedish (the app's UI language) by exception.
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingXl),
            child: Text('Adminpanelen kunde inte starta:\n$message'),
          ),
        ),
      ),
    );
  }
}

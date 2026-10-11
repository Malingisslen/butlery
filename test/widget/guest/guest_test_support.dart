import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class FakeUser extends Fake implements User {
  FakeUser({required this.isAnonymous, this.uid = 'uid-1'});

  @override
  final bool isAnonymous;

  @override
  final String uid;
}

class FakeAuthService extends Fake with ChangeNotifier implements AuthService {
  FakeAuthService(this._user);

  User? _user;

  @override
  User? get currentUser => _user;

  @override
  String? get currentUserId => _user?.uid;

  void signInAs(User? user) {
    _user = user;
    notifyListeners();
  }
}

/// Registers [auth] the way the app's service locator hands it out.
void registerAuth(AuthService auth) {
  production.ServiceLocator.initialize(DIContainer());
  GetIt.instance.registerSingleton<AuthService>(auth);
}

Future<void> resetLocator() async {
  production.ServiceLocator.reset();
  await GetIt.instance.reset();
}

Widget guestApp(Widget home, {NavigatorObserver? observer}) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  navigatorObservers: [?observer],
  onGenerateRoute: (settings) => MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const Scaffold(body: Text('pushed')),
  ),
  home: Scaffold(body: home),
);

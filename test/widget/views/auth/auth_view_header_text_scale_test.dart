// BUT-2192, updated for B96-2 (beslut 2026-09-30, B96-2 = A): the header is
// now the locked logo lockup (never text) plus the tagline, drawn straight on
// the page background. This test now pins that header: at 320 dp / 200 %
// text there is no layout error scoped to the header block, the lockup is
// present, and the tagline stays within the screen bounds.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/widgets/common/brand/butlery_lockup.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _kScreenWidth = 320.0;
const _kPumpCap = Duration(seconds: 2);

void main() {
  group('AuthView header at large text', () {
    late MockAuthService mockAuthService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      mockAuthService = MockFactory.createAuthService(isAuthenticated: false);
      mockAuthService.setAuthState(isAuthenticated: false, isLoading: false);
      TestServiceLocator.registerMock<AuthService>(mockAuthService);
      TestServiceLocator.registerMock<AuthViewModel>(
        AuthViewModel(authService: mockAuthService),
      );
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      prod.ServiceLocator.reset();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    testWidgets(
      'the lockup + tagline header lays out with no error at 320 dp and '
      '200 % text',
      (tester) async {
        tester.view.physicalSize = const Size(_kScreenWidth, 800);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // Layout errors are collected rather than read via takeException:
        // under the wide test font the footer's legal-links Row also
        // overflows at this size, and that Row is not this test's subject.
        final layoutErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = layoutErrors.add;
        try {
          await tester.pumpWidget(
            createLocalizedTestApp(
              child: const AuthView(),
              wrapInScaffold: false,
            ),
          );
          await tester.pumpAndSettle(_kPumpCap);
        } finally {
          FlutterError.onError = previousOnError;
        }

        final lockup = find.byType(ButleryLockup);
        expect(lockup, findsOneWidget);

        final headerColumn = tester.renderObject<RenderFlex>(
          find.ancestor(of: lockup, matching: find.byType(Column)).first,
        );
        final headerColumnId = describeIdentity(headerColumn);
        expect(
          layoutErrors.where((e) => e.toString().contains(headerColumnId)),
          isEmpty,
          reason: 'the lockup + tagline header must not overflow',
        );

        final lockupRect = tester.getRect(lockup);
        expect(lockupRect.left, greaterThanOrEqualTo(0));
        expect(lockupRect.right, lessThanOrEqualTo(_kScreenWidth));

        final l10n = AppLocalizations.of(
          tester.element(find.byType(AuthView)),
        );
        final tagline = find.text(l10n.authTagline);
        expect(tagline, findsOneWidget);

        final taglineRect = tester.getRect(tagline);
        expect(taglineRect.left, greaterThanOrEqualTo(0));
        expect(taglineRect.right, lessThanOrEqualTo(_kScreenWidth));
      },
    );
  });
}

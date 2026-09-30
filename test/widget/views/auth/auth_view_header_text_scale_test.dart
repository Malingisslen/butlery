// BUT-2192: at 320 dp with 200 % text the auth header's broccoli + "butlery"
// wordmark Row ran off the right edge. The wordmark is a logotype (exempt from
// text resizing under WCAG 1.4.4), so it must shrink to fit on one line rather
// than overflow or wrap.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _kWordmark = 'butlery';
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
      'the wordmark shrinks to fit one line at 320 dp and 200 % text',
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

        final wordmark = find.text(_kWordmark);
        expect(wordmark, findsOneWidget);

        final headerRow = tester.renderObject<RenderFlex>(
          find.ancestor(of: wordmark, matching: find.byType(Row)).first,
        );
        final headerRowId = describeIdentity(headerRow);
        expect(
          layoutErrors.where((e) => e.toString().contains(headerRowId)),
          isEmpty,
          reason: 'the broccoli + wordmark Row must not overflow',
        );

        final rect = tester.getRect(wordmark);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(_kScreenWidth));

        final paragraph = tester.renderObject<RenderParagraph>(wordmark);
        final oneLineHeight = paragraph.getMaxIntrinsicHeight(double.infinity);
        expect(
          paragraph.size.height,
          moreOrLessEquals(oneLineHeight, epsilon: 0.01),
          reason: 'the wordmark must stay on one line, not wrap',
        );
        expect(
          rect.width,
          lessThan(paragraph.size.width),
          reason:
              'on screen the wordmark is drawn smaller than its laid-out '
              'width, i.e. it was scaled down to fit',
        );
      },
    );
  });
}

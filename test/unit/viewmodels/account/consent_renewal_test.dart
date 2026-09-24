// P6-U06 — consent (produktregler.md:724-731, § 14; Skarmar v12 etapp 6
// #samtyckefornya #samtyckeai #kontosamtycke).
//
// 1. Saving consent must start from the consent that was READ: the old save
//    built a fresh object from five of seven purposes and silently revoked
//    AI processing on every save (the §14 bug).
// 2. The renewal says what changed since the accepted version, keeps the
//    earlier choices, and "Inte nu" changes nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/widgets/consent/consent_renewal_dialog.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

UserConsent _consent({
  required String version,
  bool aiProcessing = false,
  bool analytics = true,
}) => UserConsent(
  userId: 'anna',
  purposes: ConsentPurposes(
    essentialServices: true,
    dataProcessing: true,
    analytics: analytics,
    marketing: true,
    socialFeatures: true,
    pushNotifications: false,
    aiProcessing: aiProcessing,
  ),
  grantedAt: DateTime(2026, 6, 12, 14, 20),
  consentVersion: version,
  deviceInfo: 'test',
);

void main() {
  late MockConsentService service;

  setUpAll(() {
    registerFallbackValue(ConsentPurposes.defaults());
  });

  setUp(() {
    service = MockConsentService();
    when(() => service.needsConsentRenewal()).thenAnswer((_) async => true);
    when(() => service.saveConsent(any())).thenAnswer((_) async => true);
  });

  Future<ConsentViewModel> loaded(UserConsent consent) async {
    when(() => service.getUserConsent()).thenAnswer((_) async => consent);
    final vm = ConsentViewModel(consentService: service);
    await vm.loadConsent();
    return vm;
  }

  group('saving keeps what the user did not touch (§ 14 bug)', () {
    test(
      'aiProcessing = true stays true when another switch is saved',
      () async {
        final vm = await loaded(_consent(version: '1.1.0', aiProcessing: true));

        vm.setPushNotifications(true);
        await vm.saveConsent();

        final saved =
            verify(() => service.saveConsent(captureAny())).captured.single
                as ConsentPurposes;
        expect(saved.aiProcessing, isTrue, reason: 'AI consent must survive');
        expect(saved.pushNotifications, isTrue);
        expect(saved.marketing, isTrue, reason: 'hidden switches survive too');
        expect(saved.socialFeatures, isTrue);
      },
    );

    test('the AI switch is the user\'s own and saves both ways', () async {
      final vm = await loaded(_consent(version: '1.1.0'));
      expect(vm.aiProcessing, isFalse);

      vm.setAiProcessing(true);
      await vm.saveConsent();
      final saved =
          verify(() => service.saveConsent(captureAny())).captured.single
              as ConsentPurposes;
      expect(saved.aiProcessing, isTrue);
    });
  });

  group('renewal', () {
    test('lists what changed since the accepted version', () {
      final fromOld = ConsentService.changesSince('1.0.0');
      expect(fromOld, hasLength(1));
      expect(fromOld.single.purpose, ConsentPurpose.aiProcessing);
      expect(fromOld.single.kind, ConsentChangeKind.added);

      expect(ConsentService.changesSince('1.1.0'), isEmpty);
      expect(ConsentService.changesSince(''), hasLength(1));
    });

    test('versions compare as numbers', () {
      expect(compareConsentVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareConsentVersions('1.1', '1.1.0'), 0);
      expect(compareConsentVersions('1.0.0', '1.1.0'), lessThan(0));
    });

    test('"Jag godkänner" keeps every earlier choice and switches on only '
        'the new purpose', () async {
      final vm = await loaded(_consent(version: '1.0.0', analytics: false));

      expect(await vm.acceptRenewal(), isTrue);

      final saved =
          verify(() => service.saveConsent(captureAny())).captured.single
              as ConsentPurposes;
      expect(saved.aiProcessing, isTrue, reason: 'listed as new, agreed to');
      expect(saved.analytics, isFalse, reason: 'an earlier no stays a no');
      expect(saved.marketing, isTrue);
      expect(saved.pushNotifications, isFalse);
    });

    testWidgets('shows the change lines, the old version and three answers', (
      tester,
    ) async {
      final vm = await loaded(_consent(version: '1.0.0'));
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  ConsentRenewalDialog.show(context, viewModel: vm),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Vi har ändrat en sak'), findsOneWidget);
      expect(
        find.text(
          'Du sa ja till version 1.0.0 den 12 juni. Det här är nytt sedan dess.',
        ),
        findsOneWidget,
      );
      expect(find.text('AI-tolkning är ett nytt ändamål'), findsOneWidget);
      expect(
        find.text('Övriga 6 ändamål är oförändrade och dina val står kvar.'),
        findsOneWidget,
      );
      expect(find.text('Jag godkänner'), findsOneWidget);
      expect(find.text('Låt mig välja själv'), findsOneWidget);
      expect(find.text('Inte nu'), findsOneWidget);
    });

    testWidgets('"Inte nu" changes nothing', (tester) async {
      final vm = await loaded(_consent(version: '1.0.0'));
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  ConsentRenewalDialog.show(context, viewModel: vm),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inte nu'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => service.saveConsent(any()));
      verifyNever(() => service.revokeOptionalConsents());
    });

    testWidgets('"Jag godkänner" saves and closes', (tester) async {
      final vm = await loaded(_consent(version: '1.0.0'));
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  ConsentRenewalDialog.show(context, viewModel: vm),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jag godkänner'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verify(() => service.saveConsent(any())).called(1);
    });
  });
}

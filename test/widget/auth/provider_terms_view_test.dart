// BUT-916 mockup screen 2: the terms step after a new Google/Apple sign-in.
// The name starts from the provider's first name and can be changed; "Skapa
// konto" waits for the tick; declining removes the auth account (C3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/viewmodels/auth/provider_terms_viewmodel.dart';
import 'package:butlery/views/auth/provider_terms_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _Auth extends MockAuthService {
  _Auth({this.firstName, this.createdHere = true});

  final String? firstName;
  final bool createdHere;
  final List<String> calls = [];

  @override
  String? get providerFirstName => firstName;

  @override
  bool get providerAccountCreatedHere => createdHere;

  @override
  Future<void> deleteCurrentAuthUser() async => calls.add('delete');

  @override
  Future<void> signOut() async => calls.add('signOut');
}

class _Users extends Mock implements UserService {}

void main() {
  late _Users users;

  setUp(() {
    users = _Users();
    when(() => users.error).thenReturn(null);
    when(
      () => users.acceptProviderTerms(displayName: any(named: 'displayName')),
    ).thenAnswer((_) async => true);
  });

  Future<void> pump(WidgetTester tester, _Auth auth) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: ProviderTermsView(
          viewModel: ProviderTermsViewModel(
            authService: auth,
            userService: users,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder create() => find.byKey(const ValueKey('providerTerms.create'));

  FilledButton createButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(of: create(), matching: find.byType(FilledButton)),
  );

  testWidgets('the name starts from the provider and Skapa konto waits for '
      'the tick', (tester) async {
    await pump(tester, _Auth(firstName: 'Malin'));

    expect(find.text('Välkommen till Butlery'), findsOneWidget);
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('providerTerms.name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, 'Malin');
    expect(createButton(tester).onPressed, isNull);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('providerTerms.accept')),
        matching: find.byType(ButleryCheckbox),
      ),
    );
    await tester.pump();
    expect(createButton(tester).onPressed, isNotNull);
  });

  testWidgets('Skapa konto saves the name as edited', (tester) async {
    await pump(tester, _Auth(firstName: 'Malin'));

    await tester.enterText(
      find.byKey(const ValueKey('providerTerms.name')),
      '  Malin G  ',
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('providerTerms.accept')),
        matching: find.byType(ButleryCheckbox),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(create());
    await tester.tap(create());
    await tester.pumpAndSettle();

    verify(() => users.acceptProviderTerms(displayName: 'Malin G')).called(1);
  });

  testWidgets('an empty name is refused before anything is saved', (
    tester,
  ) async {
    await pump(tester, _Auth());

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('providerTerms.accept')),
        matching: find.byType(ButleryCheckbox),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(create());
    await tester.tap(create());
    await tester.pumpAndSettle();

    verifyNever(
      () => users.acceptProviderTerms(displayName: any(named: 'displayName')),
    );
    expect(find.text('Namn krävs'), findsOneWidget);
  });

  testWidgets('a failed save says so and stays', (tester) async {
    when(
      () => users.acceptProviderTerms(displayName: any(named: 'displayName')),
    ).thenAnswer((_) async => false);
    when(
      () => users.error,
    ).thenReturn('Kontot kunde inte skapas. Försök igen.');
    await pump(tester, _Auth(firstName: 'Malin'));

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('providerTerms.accept')),
        matching: find.byType(ButleryCheckbox),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(create());
    await tester.tap(create());
    await tester.pumpAndSettle();

    expect(find.text('Kontot kunde inte skapas. Försök igen.'), findsOneWidget);
  });

  testWidgets('Avbryt removes the auth account, then signs out', (
    tester,
  ) async {
    final auth = _Auth(firstName: 'Malin');
    await pump(tester, auth);

    final decline = find.byKey(const ValueKey('providerTerms.decline'));
    expect(
      find.descendant(of: decline, matching: find.text('Avbryt')),
      findsOneWidget,
    );
    await tester.ensureVisible(decline);
    await tester.tap(decline);
    await tester.pumpAndSettle();

    expect(auth.calls, ['delete', 'signOut']);
    verifyNever(
      () => users.acceptProviderTerms(displayName: any(named: 'displayName')),
    );
  });

  testWidgets('met again after a restart, declining says the account goes', (
    tester,
  ) async {
    await pump(tester, _Auth(firstName: 'Malin', createdHere: false));

    expect(find.text('Avbryt och ta bort kontot'), findsOneWidget);
  });
}

/// Widget tests for the BaseDialog hierarchy: BaseDialog (via concrete
/// subclasses), ConfirmationDialog, DestructiveConfirmationDialog,
/// BaseActionDialog, BaseFormDialog, LoadingDialog.
// ignore_for_file: unused_element_parameter
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

Widget _trigger(VoidCallback onTap) => Builder(
  builder: (ctx) => ElevatedButton(
    onPressed: () => onTap(),
    child: const Text('Open'),
  ),
);

/// Concrete BaseDialog subclass for testing the abstract template.
class _TestBaseDialog extends BaseDialog<String> {
  const _TestBaseDialog({
    required super.title,
    super.titleIcon,
    super.subtitle,
    super.primaryActionText,
    super.secondaryActionText,
    super.isDangerous,
    this.shouldThrow = false,
    this.contentText = 'body',
    this.additionalText,
    this.validateResult = true,
    this.contentChild,
  });

  final bool shouldThrow;
  final String contentText;
  final String? additionalText;
  final bool validateResult;
  final Widget? contentChild;

  @override
  Widget buildContent(BuildContext context) =>
      contentChild ?? Text(contentText);

  @override
  Widget? buildAdditionalContent(BuildContext context) =>
      additionalText == null ? null : Text(additionalText!);

  @override
  bool validateBeforeAction() => validateResult;

  @override
  Future<String?> performAction(BuildContext context) async {
    if (shouldThrow) throw Exception('boom from action');
    return 'success';
  }
}

class _TestFormDialog extends BaseFormDialog<String> {
  _TestFormDialog({super.title = 'Form'});

  final _controller = TextEditingController();

  @override
  List<Widget> buildFormFields(BuildContext context) => [
    TextFormField(
      controller: _controller,
      validator: (v) => (v == null || v.isEmpty) ? 'required' : null,
    ),
  ];

  @override
  Future<String?> performAction(BuildContext context) async => _controller.text;
}

class _TestActionDialog extends BaseActionDialog<int> {
  const _TestActionDialog({
    this.fail = false,
    this.titleText = 'Action',
    this.actionLabel = 'Go',
    this.cancelLabel,
    this.icon,
    this.validateOk = true,
    this.destructive = false,
    this.actionStyle,
    this.contentChild,
  });

  final bool fail;
  final String titleText;
  final String actionLabel;
  final String? cancelLabel;
  final Widget? icon;
  final bool validateOk;
  final bool destructive;
  final ButtonStyle? actionStyle;
  final Widget? contentChild;

  @override
  String dialogTitleText(BuildContext context) => titleText;

  @override
  String actionButtonLabel(BuildContext context) => actionLabel;

  @override
  String? get cancelButtonText => cancelLabel;

  @override
  Widget get actionButtonIcon => icon ?? const Icon(Icons.check);

  @override
  bool validateBeforeAction() => validateOk;

  @override
  bool get isDestructiveAction => destructive;

  @override
  ButtonStyle? actionButtonStyleFor(BuildContext context) => actionStyle;

  @override
  Widget buildContent(BuildContext context) =>
      contentChild ?? const Text('action body');

  @override
  Future<int> performAction(BuildContext context) async {
    if (fail) throw Exception('action failure');
    return 42;
  }
}

void main() {
  group('BaseDialog — render', () {
    testWidgets('renders title, body, default cancel and OK buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      // Wire the dialog via showDialog
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<void>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(title: 'Hej'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hej'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      expect(find.text('Avbryt'), findsOneWidget); // sv default
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('renders titleIcon when provided', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<void>(
        context: ctx,
        builder: (_) =>
            const _TestBaseDialog(title: 't', titleIcon: Icons.info),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('renders subtitle above content', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<void>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(
          title: 't',
          subtitle: 'sub-line',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('sub-line'), findsOneWidget);
    });

    testWidgets('renders buildAdditionalContent when non-null', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<void>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(
          title: 't',
          additionalText: 'extra-content',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('extra-content'), findsOneWidget);
    });

    testWidgets('custom primaryActionText overrides "OK"', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<void>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(
          title: 't',
          primaryActionText: 'Spara nu',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spara nu'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('isDangerous → primary label resolves to Ta bort + delete icon', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<void>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(
          title: 't',
          isDangerous: true,
        ),
      );
      await tester.pumpAndSettle();
      // Default primary label for isDangerous + no override = commonDelete = "Ta bort"
      expect(find.text('Ta bort'), findsOneWidget);
      // Default delete icon on the primary button
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });

  group('BaseDialog — primary action lifecycle', () {
    testWidgets('successful action pops with the performAction result', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      final future = showDialog<String>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(title: 't'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await future, 'success');
    });

    testWidgets('failing action displays the error in-dialog without popping', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<String>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(
          title: 't',
          shouldThrow: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Dialog still open — error_outline icon and exception message rendered
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('boom from action'), findsOneWidget);
      // Title still visible
      expect(find.text('t'), findsAtLeastNWidgets(1));
    });

    testWidgets('validateBeforeAction=false short-circuits without loading', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<String>(
        context: ctx,
        builder: (_) => const _TestBaseDialog(
          title: 't',
          validateResult: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // No error, no progress spinner
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ConfirmationDialog', () {
    testWidgets('renders title + message + custom primary label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => ConfirmationDialog.show(
                  ctx,
                  title: 'Bekräfta',
                  message: 'Är du säker?',
                  primaryActionText: 'Ja',
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Bekräfta'), findsOneWidget);
      expect(find.text('Är du säker?'), findsOneWidget);
      expect(find.text('Ja'), findsOneWidget);
    });

    testWidgets('show() returns true when primary tapped', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.show(
                    ctx,
                    title: 't',
                    message: 'm',
                    primaryActionText: 'OK',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('customContent replaces the default Text(message)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => ConfirmationDialog.show(
                  ctx,
                  title: 't',
                  message: 'should-not-render',
                  customContent: const Text('totally-custom'),
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('totally-custom'), findsOneWidget);
      expect(find.text('should-not-render'), findsNothing);
    });
  });

  group('DestructiveConfirmationDialog', () {
    testWidgets('renders RichText with bold itemName interpolated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () => DestructiveConfirmationDialog.show(
                  ctx,
                  title: 'Radera',
                  message: 'Vill du ta bort',
                  itemName: 'mitt recept',
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((w) {
          if (w is! RichText) return false;
          final t = w.text.toPlainText();
          return t.contains('Vill du ta bort') && t.contains('mitt recept');
        }),
        findsOneWidget,
      );
      // Warning icon
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      // Danger label = commonDelete = "Ta bort"
      expect(find.text('Ta bort'), findsAtLeastNWidgets(1));
    });
  });

  group('BaseActionDialog', () {
    testWidgets('renders title + content + action label + cancel', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<int>(
        context: ctx,
        builder: (_) => const _TestActionDialog(
          titleText: 'Ta bort',
          actionLabel: 'Kör',
          cancelLabel: 'Hoppa över',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ta bort'), findsOneWidget);
      expect(find.text('action body'), findsOneWidget);
      expect(find.text('Kör'), findsOneWidget);
      expect(find.text('Hoppa över'), findsOneWidget);
    });

    testWidgets('successful action returns performAction result', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      final future = showDialog<int>(
        context: ctx,
        builder: (_) => const _TestActionDialog(actionLabel: 'Go'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(await future, 42);
    });

    testWidgets('failing action shows error_outline and stays open', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<int>(
        context: ctx,
        builder: (_) => const _TestActionDialog(fail: true, actionLabel: 'Go'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('action failure'), findsOneWidget);
    });

    testWidgets(
      'actionButtonStyleFor non-null → FilledButton with that style',
      (tester) async {
        await tester.pumpWidget(_wrap(_trigger(() {})));
        final ctx = tester.element(find.byType(ElevatedButton));
        showDialog<int>(
          context: ctx,
          builder: (_) => _TestActionDialog(
            actionLabel: 'Styled',
            actionStyle: FilledButton.styleFrom(backgroundColor: Colors.purple),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Styled'), findsOneWidget);
      },
    );

    testWidgets('validateBeforeAction=false skips performAction', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<int>(
        context: ctx,
        builder: (_) => const _TestActionDialog(
          actionLabel: 'Go',
          validateOk: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      // No error displayed, no spinner
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('BaseFormDialog', () {
    testWidgets('renders the form fields from buildFormFields', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<String>(
        context: ctx,
        builder: (_) => _TestFormDialog(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('empty field → validator fails → action not invoked', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      showDialog<String>(
        context: ctx,
        builder: (_) => _TestFormDialog(),
      );
      await tester.pumpAndSettle();
      // primary label for BaseFormDialog is commonSave = "Spara"
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();
      // Validation error visible
      expect(find.text('required'), findsOneWidget);
    });

    testWidgets('filled field → submit → returns the entered value', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: ctx,
                    builder: (_) => _TestFormDialog(),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Hej världen');
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();
      expect(result, 'Hej världen');
    });
  });

  group('LoadingDialog', () {
    testWidgets('renders the message + CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      LoadingDialog.show(ctx, message: 'Sparar...');
      // CircularProgressIndicator never settles → use pump not pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sparar...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Hide so the tree is clean before the test ends
      LoadingDialog.hide(tester.element(find.text('Sparar...')));
      await tester.pump();
    });

    testWidgets('canCancel=false sets PopScope.canPop=false', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      LoadingDialog.show(ctx, message: 'm');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final pop = tester.widget<PopScope>(find.byType(PopScope));
      expect(pop.canPop, isFalse);
      LoadingDialog.hide(tester.element(find.text('m')));
      await tester.pump();
    });

    testWidgets('canCancel=true sets PopScope.canPop=true', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(() {})));
      final ctx = tester.element(find.byType(ElevatedButton));
      LoadingDialog.show(ctx, message: 'm', canCancel: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final pop = tester.widget<PopScope>(find.byType(PopScope));
      expect(pop.canPop, isTrue);
      LoadingDialog.hide(tester.element(find.text('m')));
      await tester.pump();
    });
  });

  // Content taller than the dialog must scroll, not overflow. Both templates
  // take caller-supplied content, and BUT-1693's Art. 9 consent copy is long
  // because the law says what it has to state — a bare Column dropped its tail
  // off the bottom with only a debug-mode stripe to show for it, so the member
  // could not read what they were consenting to or reach "Avbryt".
  //
  // Deliberately synthetic content at a phone-sized surface: pinning this on
  // the real ARB string would make the guard depend on nobody ever shortening
  // the copy (at the 800x600 default it overflowed by just 38px) and on a
  // feature flag that will one day be removed.
  group('content taller than the dialog', () {
    Widget tallContent() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('first-line'),
        for (var i = 0; i < 40; i++) Text('filler-$i'),
        const Text('last-line'),
      ],
    );

    Future<void> phoneSurface(WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets(
      'BaseDialog: long content scrolls and its tail stays reachable',
      (
        tester,
      ) async {
        await phoneSurface(tester);
        await tester.pumpWidget(_wrap(_trigger(() {})));
        final ctx = tester.element(find.byType(ElevatedButton));
        showDialog<String>(
          context: ctx,
          builder: (_) =>
              _TestBaseDialog(title: 't', contentChild: tallContent()),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'a dialog must never overflow its own content',
        );

        await tester.ensureVisible(find.text('last-line'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('last-line')).bottom,
          lessThanOrEqualTo(568.0),
          reason: 'the last line of the copy must be readable on a phone',
        );
      },
    );

    testWidgets(
      'BaseActionDialog: long content scrolls and its tail stays reachable',
      (tester) async {
        await phoneSurface(tester);
        await tester.pumpWidget(_wrap(_trigger(() {})));
        final ctx = tester.element(find.byType(ElevatedButton));
        showDialog<int>(
          context: ctx,
          builder: (_) => _TestActionDialog(contentChild: tallContent()),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('last-line'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('last-line')).bottom,
          lessThanOrEqualTo(568.0),
        );
      },
    );
  });
}

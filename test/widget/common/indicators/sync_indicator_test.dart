import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/sync_indicator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

void main() {
  group('SyncIndicator', () {
    group('SyncStatus derivation', () {
      testWidgets('synced state hides widget by default', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: false,
              ),
            ),
          ),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('synced state shows when alwaysVisible', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: false,
                alwaysVisible: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      });

      testWidgets('pending writes shows upload icon', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: true,
                isFromCache: false,
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      });

      testWidgets('offline shows cloud off icon', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: true,
              ),
            ),
          ),
        );

        // Production guards offline state behind a 3s debounce to avoid
        // boot-time cache snapshots flashing the offline icon. Pump past
        // the grace period so the timer fires.
        await tester.pump(const Duration(seconds: 4));

        expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      });

      testWidgets('pending writes takes priority over cache', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: true,
                isFromCache: true,
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      });
    });

    group('Colors', () {
      testWidgets('pending writes uses butleryColors warning', (tester) async {
        late ButleryColors butleryColors;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  butleryColors = context.butleryColors;
                  return const SyncIndicator(
                    hasPendingWrites: true,
                    isFromCache: false,
                  );
                },
              ),
            ),
          ),
        );

        await tester.pump();
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(butleryColors.warning));
      });

      testWidgets('offline uses theme onSurfaceVariant', (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return const SyncIndicator(
                    hasPendingWrites: false,
                    isFromCache: true,
                  );
                },
              ),
            ),
          ),
        );

        // Wait past the 3s offline-debounce so the indicator renders.
        await tester.pump(const Duration(seconds: 4));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(cs.onSurfaceVariant));
      });

      testWidgets('synced uses butleryColors success', (tester) async {
        late ButleryColors butleryColors;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  butleryColors = context.butleryColors;
                  return const SyncIndicator(
                    hasPendingWrites: false,
                    isFromCache: false,
                    alwaysVisible: true,
                  );
                },
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(butleryColors.success));
      });
    });

    group('Icon sizing', () {
      testWidgets('uses small icon size', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: true,
              ),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 4));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, equals(AppDimensions.iconSizeS));
      });
    });

    group('Accessibility', () {
      testWidgets('has semantics label for pending writes', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: true,
                isFromCache: false,
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.bySemanticsLabel('Sparar till servern'), findsOneWidget);
      });

      testWidgets('has semantics label for offline', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: true,
              ),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 4));

        expect(find.bySemanticsLabel('Offline-läge'), findsOneWidget);
      });

      testWidgets('has tooltip for pending writes', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: true,
                isFromCache: false,
              ),
            ),
          ),
        );

        await tester.pump();
        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, equals('Sparar...'));
      });

      testWidgets('has tooltip for offline', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: true,
              ),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 4));

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, equals('Offline'));
      });
    });

    group('Animation', () {
      testWidgets('pulse animation runs for pending writes', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: true,
                isFromCache: false,
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SyncIndicator), findsOneWidget);
        expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      });

      testWidgets('no animation for offline state', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: true,
              ),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 4));

        final opacity = tester.widget<Opacity>(find.byType(Opacity));
        expect(opacity.opacity, equals(1.0));
      });
    });

    group('State transitions', () {
      testWidgets('transitions from pending to synced', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: true,
                isFromCache: false,
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SyncIndicator(
                hasPendingWrites: false,
                isFromCache: false,
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(Icon), findsNothing);
      });
    });
  });
}

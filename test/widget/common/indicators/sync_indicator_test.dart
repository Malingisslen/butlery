import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/sync_indicator.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

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
      testWidgets('pending writes uses warning color', (tester) async {
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
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.warning));
      });

      testWidgets('offline uses textLight color', (tester) async {
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

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.textLight));
      });

      testWidgets('synced uses success color', (tester) async {
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

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.success));
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

        expect(find.bySemanticsLabel('Offline-lage'), findsOneWidget);
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

        await tester.pump(const Duration(milliseconds: 100));

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

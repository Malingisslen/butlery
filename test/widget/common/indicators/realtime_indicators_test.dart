/// Widget tests for the RealtimeIndicators facade — verifies that each
/// static helper constructs the correct underlying specialized widget with
/// its props forwarded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/indicators/edit_indicator_widget.dart';
import 'package:butlery/widgets/common/indicators/participant_list_widget.dart';
import 'package:butlery/widgets/common/indicators/realtime_indicators.dart';
import 'package:butlery/widgets/common/indicators/realtime_status_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    body: MediaQuery(
      // Disable animations so PulseDot-style infinite repeats don't hang
      // pumpAndSettle for edit_indicator.
      data: const MediaQueryData(disableAnimations: true),
      child: child,
    ),
  ),
);

void main() {
  group('RealtimeIndicators.editIndicator', () {
    testWidgets('constructs an EditIndicatorWidget with forwarded props', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.editIndicator(
            editorName: 'Anna',
            editorId: 'u-1',
            editingWhat: 'ingredient',
          ),
        ),
      );
      await tester.pump();
      final w = tester.widget<EditIndicatorWidget>(
        find.byType(EditIndicatorWidget),
      );
      expect(w.editorName, 'Anna');
      expect(w.editorId, 'u-1');
      expect(w.editingWhat, 'ingredient');
      expect(w.isVisible, isTrue);
    });

    testWidgets('forwards isVisible=false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.editIndicator(
            editorName: 'Anna',
            editingWhat: 'step',
            isVisible: false,
          ),
        ),
      );
      final w = tester.widget<EditIndicatorWidget>(
        find.byType(EditIndicatorWidget),
      );
      expect(w.isVisible, isFalse);
    });

    testWidgets('forwards custom color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.editIndicator(
            editorName: 'Anna',
            editingWhat: 'step',
            color: Colors.purple,
          ),
        ),
      );
      final w = tester.widget<EditIndicatorWidget>(
        find.byType(EditIndicatorWidget),
      );
      expect(w.color, Colors.purple);
    });

    testWidgets('forwards custom animationDuration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.editIndicator(
            editorName: 'Anna',
            editingWhat: 'step',
            animationDuration: const Duration(milliseconds: 999),
          ),
        ),
      );
      final w = tester.widget<EditIndicatorWidget>(
        find.byType(EditIndicatorWidget),
      );
      expect(w.animationDuration, const Duration(milliseconds: 999));
    });
  });

  group('RealtimeIndicators.participantList', () {
    testWidgets('constructs a ParticipantListWidget with forwarded props', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.participantList(
            activities: const [],
            currentUserId: 'me',
          ),
        ),
      );
      final w = tester.widget<ParticipantListWidget>(
        find.byType(ParticipantListWidget),
      );
      expect(w.activities, isEmpty);
      expect(w.currentUserId, 'me');
      expect(w.canManageParticipants, isFalse);
    });

    testWidgets('canManageParticipants=true is forwarded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.participantList(
            activities: const [],
            currentUserId: 'me',
            canManageParticipants: true,
          ),
        ),
      );
      final w = tester.widget<ParticipantListWidget>(
        find.byType(ParticipantListWidget),
      );
      expect(w.canManageParticipants, isTrue);
    });

    testWidgets(
      'onRemoveParticipant + onChangePermission callbacks forwarded',
      (tester) async {
        void onRemove(String _) {}
        void onChange(String _) {}
        await tester.pumpWidget(
          _wrap(
            RealtimeIndicators.participantList(
              activities: const [],
              currentUserId: 'me',
              onRemoveParticipant: onRemove,
              onChangePermission: onChange,
            ),
          ),
        );
        final w = tester.widget<ParticipantListWidget>(
          find.byType(ParticipantListWidget),
        );
        expect(w.onRemoveParticipant, equals(onRemove));
        expect(w.onChangePermission, equals(onChange));
      },
    );
  });

  group('RealtimeIndicators.realtimeStatus', () {
    testWidgets('constructs a RealtimeStatusWidget with forwarded props', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatus(
            isOnline: true,
            statusDescription: 'Online',
            statusEmoji: '🟢',
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusWidget>(
        find.byType(RealtimeStatusWidget),
      );
      expect(w.isOnline, isTrue);
      expect(w.statusDescription, 'Online');
      expect(w.statusEmoji, '🟢');
      expect(w.showText, isFalse);
    });

    testWidgets('showText=true is forwarded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatus(
            isOnline: false,
            statusDescription: 'Offline',
            statusEmoji: '🔴',
            showText: true,
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusWidget>(
        find.byType(RealtimeStatusWidget),
      );
      expect(w.showText, isTrue);
    });

    testWidgets('custom padding is forwarded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatus(
            isOnline: true,
            statusDescription: 'd',
            statusEmoji: 'e',
            padding: const EdgeInsets.all(7),
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusWidget>(
        find.byType(RealtimeStatusWidget),
      );
      expect(w.padding, const EdgeInsets.all(7));
    });
  });

  group('RealtimeIndicators.realtimeStatusBanner', () {
    testWidgets('constructs a RealtimeStatusBanner with forwarded props', (
      tester,
    ) async {
      void onRetry() {}
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatusBanner(
            isOnline: false,
            statusDescription: 'Disconnected',
            statusEmoji: '🔴',
            onRetry: onRetry,
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusBanner>(
        find.byType(RealtimeStatusBanner),
      );
      expect(w.isOnline, isFalse);
      expect(w.statusDescription, 'Disconnected');
      expect(w.statusEmoji, '🔴');
      expect(w.onRetry, equals(onRetry));
    });

    testWidgets('null onRetry is forwarded as null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatusBanner(
            isOnline: true,
            statusDescription: 'Connected',
            statusEmoji: '🟢',
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusBanner>(
        find.byType(RealtimeStatusBanner),
      );
      expect(w.onRetry, isNull);
    });
  });
}

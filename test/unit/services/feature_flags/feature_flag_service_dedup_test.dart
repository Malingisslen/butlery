/// BUT-663: per-session dedup for `feature_flag_evaluated` events.
///
/// Verifies the dedup state directly via `evaluatedTupleCount` rather than
/// asserting on Firebase Analytics calls — the dedup decision is the unit
/// of behavior we care about, and the Analytics emission is a downstream
/// side effect we don't need to mock here.
library;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/feature_flags/feature_flag_service.dart';

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

void main() {
  group('FeatureFlagService — feature_flag_evaluated dedup (BUT-663)', () {
    late _MockRemoteConfig mockRemoteConfig;
    late FeatureFlagService service;

    setUp(() {
      mockRemoteConfig = _MockRemoteConfig();
      // 50% rollout — half users land in the variant=true bucket, half false.
      when(() => mockRemoteConfig.getInt('rollout_flag')).thenReturn(50);
      service = FeatureFlagService(remoteConfig: mockRemoteConfig);
    });

    test('first eval of (flag, variant) tracks the tuple', () {
      service.isInRollout('rollout_flag', 'user-1');
      expect(service.evaluatedTupleCount, 1);
    });

    test('repeat eval of the same (flag, variant) does NOT add a new tuple', () {
      // Same user → deterministic FNV result → same variant.
      service.isInRollout('rollout_flag', 'user-1');
      service.isInRollout('rollout_flag', 'user-1');
      service.isInRollout('rollout_flag', 'user-1');
      expect(
        service.evaluatedTupleCount,
        1,
        reason:
            'Repeat reads with the same flag+variant must collapse to one tuple.',
      );
    });

    test(
      'different variants on the same flag are tracked as distinct tuples',
      () {
        // Two users on a 50% rollout will (very likely) produce different
        // FNV results — sweep deterministic strings until we observe both
        // variants. The loop terminates within ~32 trials in practice.
        var variantTrue = false;
        var variantFalse = false;
        for (var i = 0; i < 32 && !(variantTrue && variantFalse); i++) {
          final result = service.isInRollout('rollout_flag', 'user-$i');
          if (result) {
            variantTrue = true;
          } else {
            variantFalse = true;
          }
        }
        expect(
          variantTrue && variantFalse,
          isTrue,
          reason: 'Test fixture should observe both variants.',
        );
        // The dedup keeps one tuple per variant — at most 2 for a boolean flag.
        expect(service.evaluatedTupleCount, 2);
      },
    );

    test('resetSessionDedup() clears the set so next eval emits again', () {
      service.isInRollout('rollout_flag', 'user-1');
      expect(service.evaluatedTupleCount, 1);

      service.resetSessionDedup();
      expect(service.evaluatedTupleCount, 0);

      service.isInRollout('rollout_flag', 'user-1');
      expect(
        service.evaluatedTupleCount,
        1,
        reason: 'After reset, the next read must register the tuple again.',
      );
    });

    test(
      'soft cap of 256 distinct tuples — 257th is silently dropped, no growth',
      () {
        // `isInRollout` short-circuits to true (and skips the analytics emit)
        // at 100% rollout and false at 0% — so we use 50% to exercise the
        // hashing+emit path. 256 distinct flag names → 256 distinct tuples.
        for (var i = 0; i < 257; i++) {
          when(() => mockRemoteConfig.getInt('flag_$i')).thenReturn(50);
        }

        for (var i = 0; i < 256; i++) {
          service.isInRollout('flag_$i', 'user-x');
        }
        expect(
          service.evaluatedTupleCount,
          256,
          reason: 'Set should fill exactly to the cap.',
        );

        service.isInRollout('flag_256', 'user-x');
        expect(
          service.evaluatedTupleCount,
          256,
          reason:
              'Beyond the soft cap, additional tuples are silently dropped.',
        );
      },
    );
  });
}

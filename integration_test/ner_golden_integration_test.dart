// BUT-1240 — SKELETON for the real-signal NER golden lane.
//
// STATUS: scaffold only. The body is intentionally NOT runnable here and
// guards itself with markTestSkipped so a headless `flutter test` /
// `integration_test` invocation stays green. This file exists to (a) pin the
// target shape so a future device-capable run can fill it in without
// re-architecting, and (b) document the two residual infra decisions that
// genuinely cannot be coded without a runner + a provisioned model.
//
// Why a separate integration_test target (not test/golden/llm/ner_test.dart)?
//   The unit-level ner_test.dart can NEVER produce real NER signal: ONNX is a
//   platform-channel plugin and the headless flutter-test VM has no plugin
//   registrants, so OnnxRuntime.createSession throws MissingPluginException
//   regardless of whether the model file is present (see ner_test.dart
//   lines 18-27). Real inference requires a host with the plugin registered —
//   i.e. an integration_test binary on a device/emulator or a desktop-native
//   build. This file is that target.
//
// ---------------------------------------------------------------------------
// RESIDUAL #1 — RUNNER LANE (not codeable in this repo without infra wiring):
//   Pick ONE host that registers the flutter_onnxruntime plugin:
//     (a) Android-emulator lane, mirroring e2e_tests.yml: boot an AVD via
//         reactivecircus/android-emulator-runner, then
//         `flutter test integration_test/ner_golden_integration_test.dart -d emulator-5554`.
//         Pros: closest to the real on-device path users hit. Cons: slow
//         emulator boot, ~minutes of CI wall-time, flaky cold starts.
//     (b) Desktop-native lane: `flutter test integration_test/... -d windows`
//         (or linux/macos) on a runner with the desktop ONNX libs available.
//         Pros: fast, no emulator. Cons: validates the desktop ORT build, not
//         the mobile one; needs the native onnxruntime shared lib on PATH.
//   NO CI workflow lane is added here on purpose — that wiring is the genuine
//   infra residual and is out of scope for this skeleton.
//
// RESIDUAL #2 — MODEL PROVISIONING (not codeable; needs the artifact + creds):
//   The KB-BERT NER model (~30-40 MB) and vocab.txt are NOT bundled in the
//   repo. Provision via ONE of:
//     (a) Env vars on a self-provisioned runner:
//           NER_MODEL_PATH=/path/model.onnx NER_VOCAB_PATH=/path/vocab.txt
//         (same contract ner_test.dart already reads — reused below).
//     (b) Firebase Storage download at test setup, using a CI service-account
//         credential to fetch the production model into a temp dir, then feed
//         those paths into the env-var contract above.
//   Either path requires a credential/artifact that does not live in-repo, so
//   it cannot be finished here.
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Snapshot of case-ids expected to pass once the real model runs, following
  // the `_expectedPassing` pattern in
  // test/golden/llm/categorize_ingredient_test.dart. Empty until a real run
  // establishes the baseline — fill in lockstep with the first green lane.
  const expectedPassing = <String>{};

  test('ner golden corpus (real on-device ONNX)', () async {
    final modelPath = Platform.environment['NER_MODEL_PATH'];
    final vocabPath = Platform.environment['NER_VOCAB_PATH'];

    if (modelPath == null || vocabPath == null) {
      // TODO(BUT-1240): requires a device-capable runner (Android emulator or
      // desktop-native ONNX) — see ner_test.dart lines 21-27. Until a runner
      // lane + provisioned model exist, skip rather than fail so headless runs
      // stay green.
      markTestSkipped(
        'NER_MODEL_PATH + NER_VOCAB_PATH not set. This lane needs a '
        'device-capable runner with a provisioned KB-BERT model — see the '
        'RESIDUAL #1/#2 block at the top of this file.',
      );
      return;
    }

    // TODO(BUT-1240): wire the real on-device path. Reference the working
    // assembly already in test/golden/llm/ner_test.dart:
    //   1. OnnxNerService().initialize(modelPath, vocabContent: File(vocab))
    //   2. runCorpus(resolveCorpusPath('ner'), runner: words -> predict ->
    //      _bioToSpans), which jaccard-scores each case (threshold 0.80) via
    //      scoreCase in _golden_runner.dart.
    //   3. assert the passing-id set equals `expectedPassing` (set-equality
    //      catches a regress-here/improve-there wash, per
    //      categorize_ingredient_test.dart).
    // The corpus lives at test/golden/llm/ner/cases.json. Those imports
    // (OnnxNerService, _golden_runner, the corpus path resolver) are
    // intentionally omitted from this skeleton so it analyzes clean without an
    // ONNX/device toolchain present; add them when the runner lane lands.
    expect(expectedPassing, isNotNull);
    markTestSkipped(
      'NER real-signal body not implemented — skeleton only (BUT-1240).',
    );
  });
}

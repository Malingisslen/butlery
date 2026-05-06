# Updating an ONNX parsing model

The app downloads two ONNX models from Firebase Storage at first use:

| Family | Storage path | Local cache dir |
| ------ | ------------ | --------------- |
| Ingredient NER | `models/ingredient_ner/v{N}/` | `{appSupport}/ner_model/` |
| Line classifier | `models/line_classifier/v{N}/` | `{appSupport}/line_classifier_model/` |

Both managers verify a SHA-256 of the downloaded `model.onnx` against a hash
committed in source (BUT-792). Skipping step 3 below means clients that
download the new version will hard-fail integrity verification.

## Procedure when shipping `vN+1`

1. **Build the new ONNX**
   - NER model: train + export per the NER training pipeline.
   - Line classifier: same.
   - The artifact must be named `model.onnx` and weigh under 25 MB
     (`_maxModelSize` in both managers).
2. **Compute the SHA-256 of the bytes you are about to upload**

   ```bash
   shasum -a 256 model.onnx
   # Windows: certutil -hashfile model.onnx SHA256
   ```

3. **Add the hash to source — same PR as the upload**

   Edit `lib/services/parsing/_expected_model_hashes.dart`:

   ```dart
   const Map<int, String> kExpectedNerModelHashes = <int, String>{
     1: 'a3f2…',  // existing, do not touch
     2: '<new hash here>',
   };
   ```

   The hash for the *new* version goes in the matching map. The hash for
   the *previous* version stays — clients on the old cache must still be
   able to validate.

4. **Upload to Firebase Storage**

   ```bash
   firebase storage:set models/ingredient_ner/v2/model.onnx ./model.onnx
   firebase storage:set models/ingredient_ner/v2/vocab.txt ./vocab.txt
   ```

5. **Bump `latest_version.txt`** so existing clients pick up the new version
   on their next 12-hour throttle window:

   ```bash
   echo 2 > /tmp/latest.txt
   firebase storage:set models/ingredient_ner/latest_version.txt /tmp/latest.txt
   ```

6. **Smoke-test on a clean cache**
   - Clear `{appSupport}/ner_model/` on a test device.
   - Trigger ingredient parsing.
   - Confirm `AppLogger.info('NerModelManager: Downloaded and cached
     model v2 …')` appears.
   - Confirm no `ModelIntegrityCheckFailure` surfaces in Crashlytics.

## What can go wrong

- **Forgot step 3 in the same PR**: every client that downloads `v2` will
  log a non-fatal Crashlytics warning and the bytes are accepted (transitional
  rollout). The warning is your tripwire — fix by landing the hash entry.
- **Step 3 hash mismatches uploaded bytes**: clients hard-fail and treat the
  model as unavailable. Roll back `latest_version.txt` to `1` and republish
  with the correct hash.
- **`certutil` output includes spaces / uppercase**: the registry expects
  lowercase hex, no whitespace, no `0x` prefix. Strip via `tr -d ' '` and
  `tr A-F a-f`.

## Why we don't rotate hashes via Remote Config

Remote Config can be flipped without an app release. The integrity guard
exists precisely to catch a Storage compromise — if Remote Config could
update the registered hash, that compromise would be self-laundering. The
hash must travel through code review.

# Release Policy

Staged-rollout, halt-threshold, and rollback procedures for Butlery releases. Written 2026-05-05 (sprint L, BUT-493) ahead of the Fastlane upload pipeline (BUT-420) so that automated releases land with rollout discipline already specified, not "100% to all users on push to main".

This is a **policy** document. Until BUT-420, BUT-449, and BUT-492 land, every step here is executed manually via console UIs.

---

## 1. Per-platform rollout mechanics

### Android — Google Play Console staged rollout

Play Console exposes staged rollout natively. New production releases follow this percentage curve, with at least **24 hours between bumps** to allow Crashlytics to surface issues.

| Stage | % users | Min. dwell | Bumped to next when |
| --- | --- | --- | --- |
| 1 | 1% | 24h | crash-free sessions ≥ 99.5% **and** no Sentry P1 spike |
| 2 | 5% | 24h | same |
| 3 | 25% | 24h | same |
| 4 | 50% | 24h | same |
| 5 | 100% | — | — |

Halt + rollback: pause the rollout from the Play Console release page. Play does not support arbitrary rollback to an earlier version, but pausing freezes the percentage so already-installed users keep the new version while new updates stop. To get users *off* the bad build, ship a hotfix release at higher version-code with the prior code's behavior reverted. There's no "undeploy".

### iOS — App Store Connect Phased Release

iOS phased release is a fixed 7-day curve set by Apple — no per-stage approval required. We toggle "Phased Release for Automatic Updates" on every production submission.

| Day | % users |
| --- | --- |
| 1 | 1% |
| 2 | 2% |
| 3 | 5% |
| 4 | 10% |
| 5 | 20% |
| 6 | 50% |
| 7 | 100% |

Halt: in App Store Connect → "Pause Phased Release" on the version's page. Pause persists until manually resumed. Apple supports re-resuming after a pause; this is the iOS equivalent of "freeze rollout while we investigate". As with Android, there is no rollback — only a hotfix submission with the bad version pulled from sale.

### Web — Firebase Hosting

Firebase Hosting has no native staged rollout. Two options exist; we use option (b) by default.

(a) **Hosting channels (preview channels)** — useful for staging/QA but not real user-traffic splits. Each channel is a separate URL; we don't have URL-level traffic shifting on production.

(b) **Manual cutover with rollback path** — production deploys go to the `live` channel directly. Halt-on-regression is implemented as a `firebase hosting:rollback` to the previous release within the Hosting console UI. Hosting keeps the previous N releases (default 10) for instant rollback.

CDN cache: after rollback, run `/purge` (Cloudflare CDN purge skill) to evict any cached bad assets — see `.claude/skills/purge/`.

---

## 2. Halt thresholds

Concrete numbers a release engineer can act on without meeting. **Any one of these crossed → pause the rollout immediately**, then assess whether to resume, halt indefinitely, or hotfix.

| Metric | Threshold | Source | Notes |
| --- | --- | --- | --- |
| Crash-free sessions (Android) | < 99.5% | Crashlytics dashboard | Baseline is typically > 99.7% — 0.2pp drop is significant on small early-stage cohorts. |
| Crash-free sessions (iOS) | < 99.5% | Crashlytics dashboard | Same threshold. |
| Sentry/Crashlytics velocity | > 2× rolling 7-day baseline | Crashlytics → Trends; or Sentry once BUT-449 lands | "Velocity" = errors per active session per hour. Compare against the median of the previous 7 days, *not* the same calendar window (avoids weekday/weekend confounding). |
| D1 retention (cohort started post-rollout) | drop > 5pp vs. prior 14-day baseline | Firebase Analytics → Retention | This catches non-crash regressions that just make the app annoying enough to abandon. Lagging metric — check at +24h and +48h. |
| User reports (in-app feedback FAB) | > 3 unique reports of the same regression in 6h | Firestore `feedback/` collection | Direct user signal. Especially valuable on a 1% rollout where 3 reports = ~30k extrapolated users affected. |

Web has no Crashlytics; until BUT-449 (web error tracking) lands, web halt-decisions rely on (a) user reports and (b) the BUT-492 budget alerts firing on traffic anomalies (e.g. error pages spiking egress).

---

## 3. Rollback / halt procedures

Step-by-step. Each procedure is run by a single engineer; no approval gate (solo dev workflow).

### 3a. Android — pause Play rollout

1. Open Play Console → Butlery app → Production track.
2. Active release → "Manage rollout" → "Halt rollout".
3. Confirm; rollout freezes at current percentage.
4. Comment in the release notes ticket: paused-at-%, suspected cause, dashboard screenshot.
5. Decide: resume (after investigation clears the threshold), or ship hotfix at higher version code.

### 3b. iOS — pause phased release

1. App Store Connect → Apps → Butlery → version page.
2. "Phased Release" section → "Pause Phased Release".
3. Same documentation step as Android.
4. Decide: resume after investigation, or submit hotfix as new version.

### 3c. Web — rollback to previous Hosting release

1. Firebase Console → Hosting → Releases.
2. Select the previous green release → "Rollback".
3. Run `/purge` to evict CDN.
4. Verify: hit `synat.se` with cache-busting query string; confirm the rolled-back version is live.
5. Document in the release notes ticket.

---

## 4. Dependencies / current gaps

This policy is **document-only** until the following land — without them, every threshold check and every halt is a manual console click.

| Ticket | What it adds | Gap closed |
| --- | --- | --- |
| [BUT-420](https://linear.app/butlery/issue/BUT-420/) | Fastlane + App Distribution upload pipeline | Replaces manual binary uploads to Play/ASC. |
| [BUT-449](https://linear.app/butlery/issue/BUT-449/) | Web error tracking (Sentry or equivalent) | Currently web has no telemetry comparable to Crashlytics; section 2 row 5 row is half-blind. |
| [BUT-492](https://linear.app/butlery/issue/BUT-492/) | Firebase + GCP cost/budget alerts | Catches traffic-anomaly regressions (404 spikes, crash-loops uploading to Crashlytics, runaway Functions invocations) that aren't in Crashlytics' field of view. |

A future automation ticket should wire Crashlytics + Sentry + Firebase Analytics into a single "rollout halt" webhook that pages and pauses rollout automatically when any threshold is crossed. Out of scope here.

---

## 5. Review cadence

Re-check thresholds after the first 3 staged releases. Likely adjustments:

- The 99.5% crash-free floor may be too tight or too loose depending on how the production crash baseline shakes out — adjust to baseline × 0.99.
- The 6-hour user-reports window assumes "early rollout, low absolute volume". As the user base grows, this becomes too sensitive; rescale the threshold proportionally.
- The Hosting rollback procedure assumes single-flight deploys. Once preview channels (or another web staging mechanism) are wired in, that flow changes.

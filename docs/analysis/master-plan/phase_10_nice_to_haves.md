# Phase 10: Nice-to-Haves (~5+ days)

Cooking timer, in-app review, referral mechanism, web hover states, foldable support, etc.

---

## P10-01 — Cooking timer in cook mode [MED]

**Source**: R10:M3.1
**Fix**: Every major competitor has step-by-step timers. Butlery's cook mode exists but has no timer. Parse time mentions from instructions, embed timer widget.
**Effort**: 1-2d

---

## P10-02 — In-app review prompt [MED]

**Source**: R06:6.5, R08:PA-27
**Fix**: Add `in_app_review` package. Trigger after meaningful success events (5th recipe cooked, 3rd menu created). Primary mechanism for organic App Store ratings.
**Effort**: 4h

---

## P10-03 — Referral/invite mechanism [MED]

**Source**: R10:M7.1
**Fix**: Recipe sharing exists but no "invite a friend" flow with tracking and deep link attribution.
**Effort**: 1d

---

## P10-04 — Web hover states on custom widgets [MED]

**Source**: R06:7.1
**Fix**: No `MouseRegion` or `onHover` patterns beyond standard Material hover. Web users lack visual feedback.
**Effort**: 2d

---

## P10-05 — Keyboard shortcuts for web/desktop [MED]

**Source**: R06:5.2, R06:7.2
**Fix**: No `Shortcuts`/`Actions` widgets for Ctrl+S, Ctrl+F, etc.
**Effort**: 2d

---

## P10-06 — Foldable device support [LOW]

**Source**: R06:7.3
**Fix**: No `MediaQuery.displayFeatures` usage. Content may be hidden by hinge.
**Effort**: 1d

---

## P10-07 — Undo snackbar for destructive actions [LOW]

**Source**: R06:3.2
**Fix**: No undo mechanism for recipe deletion.
**Effort**: 2d

---

## P10-08 — Structured data for shared recipe links [LOW]

**Source**: R08:PA-29
**Fix**: Generate Open Graph metadata for recipe share links via Cloud Function. Enables rich social media previews.
**Effort**: 1d

---

## P10-09 — Email re-engagement channel [LOW]

**Source**: R08:PA-31
**Fix**: Add transactional email via Firebase Extensions (SendGrid/Mailgun) for re-engagement.
**Effort**: 2d

---

## P10-10 — Apple Sign-In [HIGH]

**Source**: R10:H5.3
**Fix**: Required by Apple if app offers third-party social login. Add `sign_in_with_apple` package.
**Effort**: 1d

---

## P10-11 — Demo account for App Store review [MED]

**Source**: R10:M5.2
**Fix**: Apple requires a demo account with pre-populated data.
**Effort**: 4h

---

## P10-12 — App store metadata preparation [MED]

**Source**: R06:6.4, R10:M5.3
**Fix**: Screenshots, descriptions, feature graphics, keywords, content rating, data safety/privacy labels.
**Effort**: 2-3d

---

## P10-13 — A/B testing framework [MED]

**Source**: R08:PA-22
**Fix**: Create ExperimentService wrapping FeatureFlagService with analytics logging and hypothesis tracking.
**Effort**: 1d

---

## P10-14 — Add content screening (profanity filter) [MED]

**Source**: R09:TS-008
**Fix**: Basic Swedish profanity word list filter for comments/messages.
**Effort**: 2-3d

---

## P10-15 — Nutritional information (Livsmedelsverket API) [MED]

**Source**: R10:M3.2
**Fix**: Planned for post-beta.
**Effort**: 3-5d

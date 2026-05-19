# Button Family (canonical)

BUT-579: a single source of truth for which button widget to reach for. The
ad-hoc growth of three parallel button systems caused inconsistent visual
language across views. This README is the canonical guide.

## Canonical hierarchy

```
lib/widgets/common/buttons/
├── action_buttons.dart       — ActionButtons (62 call-sites — DOMINANT)
├── adaptive_button.dart      — AdaptiveButton (platform-adaptive nav/toolbar)
├── overlay_button.dart       — OverlayButton (overlays on cards/images)
└── animated_pressable.dart   — AnimatedPressable (low-level press animation)
```

## Pick by use-case

| Use case                                         | Use                            |
| ------------------------------------------------ | ------------------------------ |
| Primary/secondary action in a form, dialog, card | `ActionButtons.actionButton`   |
| Navigation bar, toolbar, modal action            | `AdaptiveButton.text` / `.primary` |
| Overlay on image/card (remove, edit)             | `OverlayButton`                |
| Custom press animation around any tap target     | `AnimatedPressable`            |

## Deprecated — do NOT use in new code

- **`lib/widgets/styled/styled_button.dart`** (`StyledButton`): 15 call-sites
  exist (2026-05-19). Slated for migration to `ActionButtons.actionButton`
  per the follow-up filed alongside BUT-579. New code MUST use the
  `common/buttons/` family instead.

## Why a separate family was retired

`StyledButton` predates the `common/buttons/` consolidation. It has its own
press-animation logic and its own style enums (`StyledButton.primary`,
`.secondary`, `.danger`). `ActionButtons.actionButton` covers the same surface
via `ActionButtonStyle` (primary | secondary | danger | dangerOutlined) with
consistent loading-state + a11y handling.

Bringing every site under `common/buttons/` lets one design-system change
propagate without `grep` and three diff'd implementations.

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

## Removed — historical reference

- **`lib/widgets/styled/styled_button.dart`** (`StyledButton`): deleted in
  BUT-867 (2026-05-19 wave 4) after all 28 production call-sites migrated to
  `ActionButtons.primaryButton` / `.secondaryButton`. The `StyledButtons`
  static helper class (`.cancel`, `.save`, `.delete`, etc.) was also removed —
  it had zero call-sites at the time of the audit.

## Why a separate family was retired

`StyledButton` predated the `common/buttons/` consolidation. It carried its
own press-animation logic and a parallel style enum (`StyledButton.primary`,
`.secondary`, `.destructive`). `ActionButtons` covers the live surface
(`primary`, `secondary`) with consistent loading-state + a11y handling.

Bringing every site under `common/buttons/` lets one design-system change
propagate without `grep` and parallel implementations to diff.

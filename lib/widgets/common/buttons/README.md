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

Reach for one of these four — don't hand-roll a button. The retired
`StyledButton`/`StyledButtons` family (removed BUT-867) is gone precisely so one
design-system change propagates without parallel implementations to diff.

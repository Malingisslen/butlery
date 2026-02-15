# Fix: Portion scaler vertical centering in cream band

## Context
The "Portioner:" row and controls are not vertically centered inside the cream background band. The user confirmed the previous fix attempt ("did change the vertical centering") didn't solve it properly.

## Root Cause
`PortionScalerUI.buildScaler()` returns a **Column** with an unconditional `SizedBox(height: 8px)` after the header row (line 40). When no status info or unit toggle is shown (the common case), this creates asymmetric spacing:

```
Container (cream band, padding: vertical 12px)
  └── Column
        ├── Row ["Portioner:" − 6 +]   ← content
        └── SizedBox(height: 8px)       ← always rendered, even with nothing below
```

Result: 12px above content, 20px below (12px padding + 8px SizedBox). Content looks pushed upward.

## Fix
**File**: `lib/widgets/common/input/portion_scaler_ui.dart` (line 40)

Make the SizedBox conditional — only render it when there's content below:
```dart
// Before (line 40):
const SizedBox(height: AppDimensions.spacingM),

// After:
if (currentPortions != originalPortions || convertToSwedish || hasAmericanUnits)
  const SizedBox(height: AppDimensions.spacingM),
```

This is a 1-line change. The condition mirrors the existing conditionals for statusInfo and unitToggle.

## Verification
1. `flutter run -d chrome --web-port=9095` — check recipe detail, portion scaler row should be vertically centered in cream band
2. Also verify: when portions ARE changed, the spacing before status info still looks correct
3. Restore stashed files: `git stash pop`

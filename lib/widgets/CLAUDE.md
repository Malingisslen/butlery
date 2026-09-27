# Widgets Layer

## Rules
- Use `StateWidget` factory constructors for all loading/empty/error states — no raw `CircularProgressIndicator`
  - `StateWidget.loading()`, `StateWidget.skeletonRecipeList()`, `StateWidget.noRecipes(onAction: ...)`
  - `StateWidget.error(message: ..., onAction: ...)`, `StateWidget.empty(title: ..., icon: ...)`
- Square design language — no `BorderRadius.circular()` on badges, buttons, FABs, cards
- Colors via `Theme.of(context).colorScheme` or `context.modeColors.xxx` (lib/theme/app_mode_colors.dart; picks the generated member for the brightness), not `AppColors.xxx` directly. The old theme-extension accessor was retired in package 7
- Responsive layout: use `LayoutContainers` for centering (default maxWidth: 400)
- Prefer `StatelessWidget`; only `StatefulWidget` for local UI state (animations, focus, text controllers)
- Service access in `initState()` or via Provider — never `ServiceLocator.get<>()` inside `build()`
- Typography from `AppTextStyles`, spacing from `AppDimensions`
- `withValues(alpha: 0.8)` not `withOpacity(0.8)`

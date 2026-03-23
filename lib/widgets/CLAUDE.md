# Widgets Layer

## Rules
- Use `StateWidget` factory constructors for all loading/empty/error states — no raw `CircularProgressIndicator`
  - `StateWidget.loading()`, `StateWidget.skeletonRecipeList()`, `StateWidget.noRecipes(onAction: ...)`
  - `StateWidget.error(message: ..., onAction: ...)`, `StateWidget.empty(title: ..., icon: ...)`
- Square design language — no `BorderRadius.circular()` on badges, buttons, FABs, cards
- Colors via `context.butleryColors.xxx` (theme-aware), not `AppColors.xxx` directly
- Responsive layout: use `LayoutContainers` for centering (default maxWidth: 400)
- Prefer `StatelessWidget`; only `StatefulWidget` for local UI state (animations, focus, text controllers)
- Service access in `initState()` or via Provider — never `ServiceLocator.get<>()` inside `build()`
- Typography from `AppTextStyles`, spacing from `AppDimensions`
- `withValues(alpha: 0.8)` not `withOpacity(0.8)`

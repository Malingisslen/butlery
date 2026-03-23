# Views Layer

## View structure pattern

```dart
class XxxView extends StatefulWidget { ... }
class _XxxViewState extends State<XxxView> {
  late final XxxViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<XxxViewModel>();
  }

  @override
  void dispose() {
    _vm.dispose();  // always dispose VMs
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<XxxViewModel>.value(value: _vm),
      ],
      child: const _XxxViewContent(),  // actual UI here
    );
  }
}
```

## Rules
- Top-level `build()` = `MultiProvider` wrapper only; actual UI in private `_XxxViewContent`
- Singleton VMs: `ChangeNotifierProvider.value(value: vm)` — never `create:` for singletons (causes double-dispose)
- `context.watch<VM>()` for rebuilds, `context.read<VM>()` in callbacks only
- Post-frame loading: `addPostFrameCallback` with `if (mounted)` guard
- Use scaffold widgets from `lib/widgets/common/scaffolds/` (BaseScaffold, ListScaffold, etc.)
- Large views: split into sub-files in a same-name subdirectory
- Colors via theme, `withValues(alpha:)` not `withOpacity()`
- Localization: `context.l10n.xxxKey`

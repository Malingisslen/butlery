// lib/widgets/common/layout/detail_pane.dart
//
// BUT-723: on a tablet held in landscape a tab shows its list on the left and
// the chosen item on the right (Malin's cards 2026-10-10; mockup approved
// 2026-10-11, built from design/mockup-kit/). Portrait and phones keep one
// page at a time, so outside a two-pane host `openDetail` is a plain push.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';

/// Whether a tab shows list and detail side by side: the rail is drawn, the
/// screen is wide enough for both, and it is held in landscape.
bool useDetailPane(Size size) =>
    useNavigationRail(size) &&
    size.width >= Breakpoints.tabletLarge &&
    size.width > size.height;

/// Opens [route] on the right when called from the list side of a two-pane
/// host, and pushes it as before everywhere else, the right side included.
/// [selectionKey] names the item for the list's mark (a recipe id, a route);
/// it defaults to the route name.
Future<Object?> openDetail(
  BuildContext context,
  String route, {
  Object? arguments,
  Object? selectionKey,
}) {
  final controller = DetailPaneScope.maybeOf(context);
  if (controller != null && !DetailPane.isInside(context)) {
    controller.open(
      RouteSettings(name: route, arguments: arguments),
      key: selectionKey ?? route,
    );
    return Future<Object?>.value();
  }
  return Navigator.of(context).pushNamed(route, arguments: arguments);
}

/// What the right side shows, and whether it has taken the whole width.
class DetailPaneController extends ChangeNotifier {
  RouteSettings? _selected;
  Object? _selectedKey;
  bool _offered = false;
  bool _expanded = false;

  RouteSettings? get selected => _selected;
  bool get expanded => _expanded;

  /// Whether the list item named [key] is the one shown on the right.
  bool isSelected(Object key) => _selected != null && _selectedKey == key;

  /// Shows [settings] on the right, replacing what was there.
  void open(RouteSettings settings, {required Object key}) {
    _selected = settings;
    _selectedKey = key;
    _offered = false;
    _expanded = false;
    notifyListeners();
  }

  /// The list's first item, shown until the user picks something. A later
  /// offer with another [key] replaces an earlier one, so a list whose first
  /// item changes keeps its default current; a pick is never replaced, and an
  /// offer of the item already shown changes nothing.
  void offerFirst(RouteSettings settings, {required Object key}) {
    if (_selected != null && !_offered) return;
    if (_selected != null && _selectedKey == key) return;
    _selected = settings;
    _selectedKey = key;
    _offered = true;
    notifyListeners();
  }

  /// Empties the right side, for when its last page has gone.
  void clear() {
    if (_selected == null && !_expanded) return;
    _selected = null;
    _selectedKey = null;
    _offered = false;
    _expanded = false;
    notifyListeners();
  }

  void setExpanded(bool value) {
    if (_expanded == value) return;
    _expanded = value;
    notifyListeners();
  }
}

/// Puts a host's [DetailPaneController] in reach of the list side's taps.
class DetailPaneScope extends InheritedNotifier<DetailPaneController> {
  const DetailPaneScope({
    super.key,
    required DetailPaneController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller of the nearest two-pane host, or null on a phone, in
  /// portrait and anywhere outside a host.
  static DetailPaneController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPaneScope>()?.notifier;
}

/// Marks the right side, so a page can tell it is shown beside a list.
class DetailPane extends InheritedWidget {
  const DetailPane._({required super.child});

  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DetailPane>() != null;

  @override
  bool updateShouldNotify(DetailPane oldWidget) => false;
}

/// A tab's list, with the chosen item beside it on a tablet in landscape.
class DetailPaneHost extends StatefulWidget {
  const DetailPaneHost({
    super.key,
    required this.master,
    required this.onGenerateRoute,
  });

  /// The tab's own view, unchanged; it opens items with [openDetail].
  final Widget master;

  /// Builds the right side's pages; the shell passes the app router.
  final RouteFactory onGenerateRoute;

  @override
  State<DetailPaneHost> createState() => _DetailPaneHostState();
}

class _DetailPaneHostState extends State<DetailPaneHost> {
  final DetailPaneController _controller = DetailPaneController();
  // A new pick starts a new stack, so the navigator gets a new key with it;
  // following a link inside the right side pushes onto the current one.
  GlobalKey<NavigatorState> _detailNavigator = GlobalKey();
  _LastPageObserver? _observer;
  RouteSettings? _shown;
  // The master keeps its state when the screen turns between one and two
  // panes, so the list does not reload or lose its scroll position.
  final GlobalKey _masterKey = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final master = KeyedSubtree(key: _masterKey, child: widget.master);
        if (!useDetailPane(MediaQuery.sizeOf(context)) ||
            !constraints.hasBoundedWidth ||
            !constraints.hasBoundedHeight) {
          return master;
        }
        return DetailPaneScope(
          controller: _controller,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _twoPanes(context, size, master),
          ),
        );
      },
    );
  }

  Widget _twoPanes(BuildContext context, Size size, Widget master) {
    final cs = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final expanded = _controller.expanded;
    const listWidth = AppDimensions.detailPaneListWidth;
    final detailWidth = expanded
        ? size.width
        : size.width - listWidth - AppDimensions.dividerHeight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Offstage rather than removed, so the list keeps its state while
        // the recipe has the whole width.
        Offstage(
          offstage: expanded,
          child: SizedBox(
            width: listWidth,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: context.l10n.a11yDetailPaneList,
              child: MediaQuery(
                data: mq.copyWith(size: Size(listWidth, size.height)),
                child: master,
              ),
            ),
          ),
        ),
        if (!expanded)
          SizedBox(
            width: AppDimensions.dividerHeight,
            child: ColoredBox(color: cs.outlineVariant),
          ),
        SizedBox(
          width: detailWidth,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: context.l10n.a11yDetailPaneDetail,
            child: MediaQuery(
              data: mq.copyWith(size: Size(detailWidth, size.height)),
              child: DetailPane._(child: _detail(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context) {
    final selected = _controller.selected;
    if (selected == null) {
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }
    if (!identical(selected, _shown)) {
      _shown = selected;
      _detailNavigator = GlobalKey();
      _observer = null;
    }
    // A page that pops itself after a save or a delete can take the stack's
    // only route with it, so an empty stack empties the selection too.
    final observer = _observer ??= _LastPageObserver(_controller.clear);
    final expanded = _controller.expanded;
    // In Helskärm, back shows the list again before it leaves the page.
    return PopScope(
      canPop: !expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && expanded) _controller.setExpanded(false);
      },
      child: NavigatorPopHandler(
        enabled: !expanded,
        // The route calls every PopScope callback below it when one of them
        // blocks the pop, the disabled handler's included, so expanded is
        // checked here too or one back would also pop the page.
        onPopWithResult: (_) {
          if (!expanded) _detailNavigator.currentState?.maybePop();
        },
        child: Navigator(
          key: _detailNavigator,
          observers: [observer],
          onGenerateInitialRoutes: (navigator, _) => [
            widget.onGenerateRoute(selected)!,
          ],
          onGenerateRoute: widget.onGenerateRoute,
        ),
      ),
    );
  }
}

class _LastPageObserver extends NavigatorObserver {
  _LastPageObserver(this.onEmpty);

  final VoidCallback onEmpty;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) onEmpty();
  }
}

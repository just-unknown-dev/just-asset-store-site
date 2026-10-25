import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../theme/theme_controller.dart';
import 'nav_drawer.dart';
import 'site_footer.dart';
import 'top_nav.dart';

/// The persistent chrome: sticky top nav, the scrolling page body, the footer
/// and the drawer. Lives in the router's ShellRoute so it survives
/// navigation; scrolls back to the top whenever [location] changes.
class SiteScaffold extends StatefulWidget {
  const SiteScaffold({
    super.key,
    required this.chrome,
    required this.theme,
    required this.location,
    required this.child,
    this.actions = const [],
    this.drawerActions = const [],
  });

  final SiteChrome chrome;
  final ThemeController theme;

  /// The current path, which picks the active navigation entry.
  final String location;
  final Widget child;

  /// Extra controls in the top nav (see [TopNav.actions]).
  final List<Widget> actions;

  /// Extra entries in the drawer (see [NavDrawer.actions]).
  final List<Widget> drawerActions;

  @override
  State<SiteScaffold> createState() => _SiteScaffoldState();
}

class _SiteScaffoldState extends State<SiteScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final Signal<bool> _scrolled = Signal<bool>(false, debugLabel: 'scrolled');

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(SiteScaffold old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
      });
    }
  }

  void _onScroll() {
    final scrolled = _scroll.hasClients && _scroll.offset > 8;
    if (_scrolled.value != scrolled) _scrolled.value = scrolled;
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.chrome.activeFor(widget.location);
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: NavDrawer(
        chrome: widget.chrome,
        active: active,
        actions: widget.drawerActions,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: PrimaryScrollController(
              controller: _scroll,
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: kTopNavHeight),
                      widget.child,
                      SiteFooter(chrome: widget.chrome),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SignalBuilder<bool>(
              signal: _scrolled,
              builder: (context, scrolled, _) => TopNav(
                chrome: widget.chrome,
                theme: widget.theme,
                active: active,
                scrolled: scrolled,
                actions: widget.actions,
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:just_asset_store_pages/content.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../router/route_state.dart';

/// Keeps `<head>` right as the user moves between the app's pages: the
/// same titles the static shell wrote ([StoreRoutes.appHead]).
final class HeadBinder {
  HeadBinder(this.head, this.route) {
    _effect = Effect(() {
      head.apply(metaFor(StoreRoutes.appHead(route.location.value)));
      return null;
    }, debugLabel: 'head');
  }

  final HeadService head;
  final RouteState route;
  Effect? _effect;

  static PageMeta metaFor(PageHead h) => PageMeta(
    siteName: StoreMeta.name,
    title: h.title,
    description: h.description,
    canonicalUrl: StoreMeta.identity.absolute(h.path),
    ogImageUrl: StoreMeta.identity.absolute(
      h.ogImage ?? StoreMeta.identity.defaultOgImage,
    ),
    noindex: h.noindex,
  );

  void dispose() => _effect?.dispose();
}

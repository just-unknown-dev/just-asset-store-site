import 'package:just_asset_store/just_asset_store.dart';

import 'icons.dart';

/// A publisher and what the catalog lists from them.
final class StorePublisherView {
  const StorePublisherView(this.id, this.trust, this.items);

  /// Their GitHub account (`just` for the store's own).
  final String id;

  /// The most the store vouches for any of their items.
  final TrustLevel trust;
  final List<StoreItem> items;

  /// Their GitHub page; null for the store's own `just`.
  String? get githubUrl => id == 'just' ? null : 'https://github.com/$id';
}

/// What the pages need from a catalog, worked out once: items in order,
/// categories in use, publishers, the newest, and where pictures are.
final class StoreCatalogView {
  /// A view of [index], published at the site's root (pictures relative to
  /// it are served from there).
  StoreCatalogView(this.index)
    : items = [...index.items]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final StoreIndex index;

  /// Every item, by name.
  final List<StoreItem> items;

  /// A publisher id the site makes a page for: a GitHub login, or `just`.
  static final RegExp publisherId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,38}$');

  /// When [item]'s newest version came out.
  DateTime? updated(StoreItem item) {
    DateTime? best;
    for (final v in item.versions) {
      final p = v.published;
      if (p != null && (best == null || p.isAfter(best))) best = p;
    }
    return best;
  }

  /// The categories that hold at least one item (but a deprecated one),
  /// in order.
  late final List<StoreCategory> usedCategories = [
    for (final c in index.categories)
      if (inCategory(c.id).isNotEmpty) c,
  ];

  /// The items in the category [id], by name; deprecated ones only
  /// [withDeprecated] (their pages stay, for old links).
  List<StoreItem> inCategory(String id, {bool withDeprecated = false}) => [
    for (final i in items)
      if (i.category == id &&
          (withDeprecated || i.stage != ItemStage.deprecated))
        i,
  ];

  /// Whether the store offers [item] unasked: not experimental or
  /// deprecated (shown only when asked), not unavailable, and with a
  /// version to install.
  bool offered(StoreItem item) =>
      !(item.stage?.hiddenByDefault ?? false) &&
      !item.unavailable &&
      item.latest != null;

  /// The newest [count] items (of [kind], when given) the store [offered],
  /// by when their newest version came out.
  List<StoreItem> newest(int count, {ItemKind? kind}) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return ([
          for (final i in items)
            if (offered(i) && (kind == null || i.kind == kind)) i,
        ]..sort(
            (a, b) => (updated(b) ?? epoch).compareTo(updated(a) ?? epoch),
          ))
        .take(count)
        .toList();
  }

  /// The home page's newest shelf.
  late final List<StoreItem> recent = newest(4);

  /// The items the store's makers show first (the catalog's `featured`),
  /// that it [offered]; four at most.
  late final List<StoreItem> featured = [
    for (final i in index.featuredItems)
      if (offered(i)) i,
  ].take(4).toList();

  /// [item]'s pictures, as the pages link them: its previews, else its
  /// card picture.
  List<String> galleryOf(StoreItem item) {
    final pictures = [for (final p in item.previews) ?pictureUrl(p)];
    if (pictures.isNotEmpty) return pictures;
    final card = pictureUrl(item.thumbnail);
    return card == null ? const [] : [card];
  }

  /// The icon the category [cat] gets ([PageIcons]).
  String iconFor(StoreCategory cat) =>
      PageIcons.categories[cat.id] ??
      PageIcons.forKind(
        inCategory(cat.id, withDeprecated: true).firstOrNull?.kind ??
            ItemKind.content,
      );

  /// Every publisher with a page, by id.
  late final List<StorePublisherView> publishers = () {
    final by = <String, List<StoreItem>>{};
    for (final i in items) {
      if (publisherId.hasMatch(i.publisher)) {
        by.putIfAbsent(i.publisher, () => []).add(i);
      }
    }
    return [
      for (final id in by.keys.toList()..sort())
        StorePublisherView(
          id,
          by[id]!.map((i) => i.trust).reduce((a, b) => a.index < b.index ? a : b),
          by[id]!,
        ),
    ];
  }();

  /// Whether [publisher] has a page.
  bool hasPublisherPage(String publisher) => publisherId.hasMatch(publisher);

  /// The items that need [id].
  List<StoreItem> dependents(String id) => [
    for (final i in items)
      if (i.latest?.dependencies.containsKey(id) ?? false) i,
  ];

  /// The items the store took down that it no longer lists.
  late final List<RemovedItem> removedOnly = [
    for (final r in index.removed)
      if (index.item(r.id) == null) r,
  ];

  /// The picture at [reference] (relative to the catalog, or a full https
  /// URL), as the pages link it; null when there is none.
  String? pictureUrl(String? reference) {
    if (reference == null || reference.isEmpty) return null;
    final uri = Uri.tryParse(reference);
    if (uri == null) return null;
    if (uri.hasScheme) return uri.scheme == 'https' ? reference : null;
    if (uri.hasAuthority || reference.startsWith('/')) return null;
    final path = uri.path;
    if (path.split('/').any((s) => s == '..' || s.isEmpty)) return null;
    return '/$path';
  }
}

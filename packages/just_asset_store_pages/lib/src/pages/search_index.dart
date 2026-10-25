import 'dart:convert';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_unknown_site/just_unknown_site.dart' show isoDate;

import '../content/labels.dart';
import 'store_catalog_view.dart';

/// `search.json`: what the search page filters, in short keys — about 200
/// bytes an item before compression.
///
/// `items[]`: `id`; `n` name; `s` summary; `k` kind id and `kl` its label;
/// `c` category; `p` publisher; `t` tags; `tr` source label (Official or
/// Third Party); `st` stage id and `stl` its badge (none when stable); `rb`
/// what replaces a deprecated item; `v` newest version; `u` when it came
/// out (`yyyy-mm-dd`); `th` its picture's URL.
abstract final class SearchIndex {
  /// The format's version.
  static const int version = 1;

  /// [c] as `search.json`'s text.
  static String of(StoreCatalogView c) => jsonEncode({
    'v': version,
    'categories': [
      for (final cat in c.usedCategories) {'id': cat.id, 'l': cat.label},
    ],
    'items': [
      for (final i in c.items)
        if (!i.unavailable) _item(c, i),
    ],
  });

  static Map<String, Object?> _item(StoreCatalogView c, StoreItem i) {
    final updated = c.updated(i);
    return {
      'id': i.id,
      'n': i.name,
      's': i.summary,
      'k': i.kind.id,
      'kl': kindLabel(i.kind),
      'c': i.category,
      'p': i.publisher,
      't': i.tags,
      'tr': sourceLabel(i.trust),
      'st': ?i.stage?.id,
      'stl': ?stageBadge(i.stage),
      'rb': ?i.replacedBy,
      if (i.latest case final v?) 'v': '${v.version}',
      if (updated != null) 'u': isoDate(updated),
      'th': ?c.pictureUrl(i.thumbnail),
    };
  }
}

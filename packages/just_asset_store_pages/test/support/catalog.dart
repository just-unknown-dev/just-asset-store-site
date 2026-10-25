// A small catalog with every kind of page in it, a hostile entry among
// them.
import 'dart:convert';

import 'package:just_asset_store/just_asset_store.dart';

const String shaA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String shaB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Map<String, Object?> catalogJson() => {
  'schema': 2,
  'source': {'id': 'just-official', 'name': 'Just Asset Store'},
  'generatedAt': '2026-10-20T10:00:00Z',
  'categories': [
    {'id': 'characters', 'label': 'Characters', 'order': 10},
    {'id': 'kits', 'label': 'Kits', 'order': 20},
    {'id': 'libraries', 'label': 'Libraries', 'order': 90},
    {'id': 'empty', 'label': 'Nothing here', 'order': 95},
  ],
  'removed': [
    {'id': 'bad_pack', 'reason': 'It held a stolen tileset.'},
  ],
  // An experimental one and one it doesn't list are not shown.
  'featured': ['their_kit', 'their_new_kit', 'missing_one', 'just_art_knight'],
  'items': [
    {
      'id': 'just_art_knight',
      'name': 'Knight',
      'kind': 'content',
      'category': 'characters',
      'summary': 'A pixel knight with run and attack clips.',
      'description': 'Eight animations.\nAll at 32 px.',
      'tags': ['pixel-art', 'hero'],
      'author': {'name': 'Just', 'url': 'https://justunknown.com'},
      'license': {'spdx': 'CC-BY-4.0', 'attribution': 'Art by Just Unknown'},
      'thumbnail': 'thumbs/0123456789abcdef.jpg',
      'previews': [
        'previews/fedcba9876543210.jpg',
        'https://github.com/just-unknown-dev/knight/releases/download/v1.1.0/run.png',
      ],
      'trust': 'official',
      'sourceRepo': 'https://github.com/just-unknown-dev/knight',
      'versions': [
        {
          'version': '1.0.0',
          'published': '2026-09-01',
          'archive': {'url': 'https://e.com/k-1.0.0.zip', 'sha256': shaA, 'size': 1200},
          'yanked': true,
        },
        {
          'version': '1.1.0',
          'published': '2026-10-01',
          'notes': 'An attack clip.',
          'archive': {
            'url': 'https://e.com/k-1.1.0.zip',
            'sha256': shaB,
            'size': 2500000,
            'unpackedSize': 4100000,
          },
          'requires': {'just_game_engine': '^2.0.0'},
        },
      ],
    },
    {
      'id': 'their_kit',
      'name': 'Their Kit',
      'kind': 'kit',
      'category': 'kits',
      'summary': 'Platformer bits.',
      'publisher': 'octocat',
      'trust': 'community',
      'versions': [
        {
          'version': '0.2.0',
          'published': '2026-10-10',
          'archive': {'url': 'https://e.com/t.zip', 'sha256': shaA, 'size': 900},
          'dependencies': {'just_art_knight': '^1.1.0'},
          'pubDependencies': {'nice_lib': '^1.0.0'},
          'nativePlugins': ['camera_x'],
          'permissions': ['network', 'native'],
          'stage': 'beta',
        },
      ],
    },
    {
      'id': 'their_new_kit',
      'name': 'Their New Kit',
      'kind': 'kit',
      'category': 'kits',
      'publisher': 'octocat',
      'versions': [
        {
          'version': '0.1.0',
          'published': '2026-10-15',
          'archive': {'url': 'https://e.com/n.zip', 'sha256': shaA, 'size': 900},
          'stage': 'experimental',
        },
      ],
    },
    {
      'id': 'their_old_kit',
      'name': 'Their Old Kit',
      'kind': 'kit',
      'category': 'kits',
      'publisher': 'octocat',
      'versions': [
        {
          'version': '2.0.0',
          'published': '2026-10-16',
          'archive': {'url': 'https://e.com/o.zip', 'sha256': shaA, 'size': 900},
          'stage': 'deprecated',
          'replacedBy': 'their_kit',
        },
      ],
    },
    {
      'id': 'just_tiled',
      'name': 'Tiled maps',
      'kind': 'runtime-library',
      'category': 'libraries',
      'pub': {'package': 'just_tiled'},
      'trust': 'official',
      'versions': [
        {'version': '0.4.1', 'constraint': '^0.4.1'},
      ],
    },
    {
      'id': 'sneaky',
      'name': '<script>alert(1)</script>',
      'kind': 'content',
      'category': 'characters',
      'summary': '"><img src=x onerror=alert(2)>',
      'publisher': 'evil/../x',
      'sourceRepo': 'javascript:alert(3)',
      'author': {'name': 'Mallory', 'url': 'javascript:alert(4)'},
      'thumbnail': 'https://evil.example/x.png',
      'versions': [
        {
          'version': '1.0.0',
          'archive': {'url': 'https://e.com/s.zip', 'sha256': shaA, 'size': 10},
        },
      ],
    },
    {
      'id': 'gone_kit',
      'name': 'Gone Kit',
      'kind': 'kit',
      'category': 'kits',
      'publisher': 'octocat',
      'unavailable': true,
      'versions': [
        {
          'version': '1.0.0',
          'archive': {'url': 'https://e.com/g.zip', 'sha256': shaA, 'size': 10},
        },
      ],
    },
  ],
};

StoreIndex testCatalog() => StoreIndex.parse(jsonEncode(catalogJson()));

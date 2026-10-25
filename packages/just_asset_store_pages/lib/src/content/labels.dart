import 'package:just_asset_store/just_asset_store.dart'
    show ItemKind, ItemStage, StoreItem, TrustLevel;

/// What the site calls each kind of item.
String kindLabel(ItemKind kind) => switch (kind) {
  ItemKind.content => 'Art & sound',
  ItemKind.editorExtension => 'Editor tool',
  ItemKind.kit => 'Kit',
  ItemKind.runtimeLibrary => 'Library',
  ItemKind.template => 'Template',
};

/// Where an item comes from, as the site's badge says: Official (made by
/// Just Unknown) or Third Party. (The editor also knows Unlisted and Local:
/// installs no catalog lists.)
String sourceLabel(TrustLevel trust) =>
    trust == TrustLevel.official ? 'Official' : 'Third Party';

/// The stage badge [stage] gets; none for a stable item, or one that names
/// no stage.
String? stageBadge(ItemStage? stage) =>
    stage == null || stage == ItemStage.stable ? null : stage.label;

/// The command that installs [item].
String installCommand(StoreItem item) => item.kind == ItemKind.template
    ? 'just create my_game --template ${item.id}'
    : 'just add ${item.id}';

/// [bytes] as a size people read: `840 KB`, `12.4 MB`.
String sizeLabel(int bytes) {
  if (bytes == 1) return '1 byte';
  if (bytes < 1000) return '$bytes bytes';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).round()} KB';
  final mb = bytes / (1000 * 1000);
  return mb < 100 ? '${mb.toStringAsFixed(1)} MB' : '${mb.round()} MB';
}

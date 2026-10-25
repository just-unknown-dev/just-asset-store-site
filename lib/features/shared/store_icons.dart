import 'package:flutter/material.dart';

/// The picture a page copy point names (see `CopyPoint.icon`).
IconData copyIcon(String? key) => switch (key) {
  'terminal' => Icons.terminal_rounded,
  'editor' => Icons.web_asset_rounded,
  'shield' => Icons.verified_user_rounded,
  'package' => Icons.inventory_2_rounded,
  'tag' => Icons.sell_rounded,
  'check' => Icons.fact_check_rounded,
  'upload' => Icons.upload_rounded,
  'key' => Icons.key_rounded,
  _ => Icons.star_rounded,
};

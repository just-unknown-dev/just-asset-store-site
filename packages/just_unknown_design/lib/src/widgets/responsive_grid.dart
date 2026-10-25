import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';

/// Equal-height rows of [children], 1 / 2 / N columns by form factor.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.maxColumns = 3,
    this.gap = 24,
  });

  final List<Widget> children;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final columns = Breakpoints.columns(context.formFactor, max: maxColumns);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
        i,
        (i + columns).clamp(0, children.length),
      );
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) cells.add(SizedBox(width: gap));
        cells.add(
          Expanded(
            child: j < slice.length ? slice[j] : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

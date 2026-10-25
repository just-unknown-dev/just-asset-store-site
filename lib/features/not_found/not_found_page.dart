import 'package:flutter/material.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    return PageHero(
      eyebrow: '404',
      title: 'Page not found',
      lede: path == null
          ? 'The page you were looking for does not exist.'
          : 'There is nothing at $path. The package may have been renamed or '
                'taken down.',
      compact: true,
      actions: const [
        SiteLink('Browse packages', StoreRoutes.homePath, primary: true),
        SiteLink('Publish a package', StoreRoutes.publishPath),
      ],
    );
  }
}

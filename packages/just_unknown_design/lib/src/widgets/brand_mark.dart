import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_link.dart';

/// Logo tile + wordmark, linking to [SiteChrome.home].
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    required this.chrome,
    this.size = 28,
    this.showWordmark = true,
  });

  final SiteChrome chrome;
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: '${chrome.name} home',
      child: InkWell(
        onTap: () => followHref(context, chrome.home),
        borderRadius: BorderRadius.circular(JuRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                chrome.logoAsset,
                width: size,
                height: size,
                cacheWidth: (size * 3).round(),
                filterQuality: FilterQuality.medium,
                semanticLabel: '',
                errorBuilder: (context, _, _) => SizedBox.square(dimension: size),
              ),
              if (showWordmark) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    chrome.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: JuFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.68,
                      letterSpacing: -0.3,
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

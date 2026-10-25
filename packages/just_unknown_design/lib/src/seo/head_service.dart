import 'head_service_stub.dart'
    if (dart.library.js_interop) 'head_service_web.dart'
    as impl;

/// What a page's `<head>` says.
final class PageMeta {
  const PageMeta({
    required this.siteName,
    required this.title,
    required this.description,
    required this.canonicalUrl,
    required this.ogImageUrl,
    this.noindex = false,
  });

  final String siteName;
  final String title;
  final String description;
  final String canonicalUrl;
  final String ogImageUrl;
  final bool noindex;
}

/// Keeps `<head>` in sync with in-app navigation. The static shell provides
/// the first values for crawlers; this keeps them right afterwards.
abstract class HeadService {
  /// Writes [meta] into the live document.
  void apply(PageMeta meta);
}

/// Does nothing: tests and non-web targets.
class NoopHeadService implements HeadService {
  @override
  void apply(PageMeta meta) {}
}

/// The document's head on the web, [NoopHeadService] elsewhere.
HeadService createHeadService() => impl.createHeadService();

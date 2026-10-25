/// Pictures the website serves beside the catalog: each item's card picture
/// (its first preview, made small) and its gallery (its first previews, at
/// most 1280×720), so no page loads a picture from anywhere else.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:just_asset_store/just_asset_store.dart';

import 'github.dart';
import 'records.dart';

/// Makes and keeps the store's pictures.
///
/// A deploy replaces the whole site, so every catalog item's pictures go
/// into every deploy. Each is made once: kept in [cacheDir] (a folder the
/// workflow keeps between runs), else fetched from the [liveSite], else
/// made anew from its source.
final class Thumbnails {
  /// Pictures fetched through [github], kept in [cacheDir].
  Thumbnails({required this.github, required this.cacheDir, this.liveSite});

  /// Fetches sources.
  final GitHubApi github;

  /// Where made pictures are kept between runs.
  final Directory cacheDir;

  /// The live site, to fetch pictures an earlier run made.
  final Uri? liveSite;

  /// A card picture's size: sharp on a card about 320 px wide on a
  /// high-density screen.
  static const int width = 640;

  /// A card picture's size.
  static const int height = 360;

  /// The largest gallery picture: a picture is made smaller to fit, never
  /// larger.
  static const int galleryWidth = 1280;

  /// The largest gallery picture.
  static const int galleryHeight = 720;

  /// The most pictures an item's gallery shows.
  static const int maxPictures = 4;

  /// The largest source read, in bytes.
  static const int maxSourceBytes = 4 << 20;

  /// The largest side a source may have, in pixels.
  static const int maxSourceSide = 4096;

  /// Where the card picture made from [source] is published: named by its
  /// source's SHA-256, so it never changes and caches forever.
  static String pathOf(ThumbSource source) =>
      'thumbs/${source.sha256.substring(0, 16)}.jpg';

  /// Where the gallery picture made from [source] is published.
  static String galleryPathOf(ThumbSource source) =>
      'previews/${source.sha256.substring(0, 16)}.jpg';

  /// The picture published at [path] (from [pathOf] or [galleryPathOf]):
  /// kept, fetched from the live site, or made from [source]; null when
  /// none of those works.
  Future<Uint8List?> bytesOf(String path, {ThumbSource? source}) async {
    final kept = File('${cacheDir.path}/$path');
    if (kept.existsSync()) return kept.readAsBytesSync();
    Uint8List? made;
    if (source != null) {
      made = await _make(source, gallery: path.startsWith('previews/'));
    }
    final live = liveSite;
    if (made == null && live != null) {
      try {
        made = await github.download(live.resolve(path), maxBytes: 2 << 20);
      } on Object {
        // Not there either.
      }
    }
    if (made != null) {
      kept.parent.createSync(recursive: true);
      kept.writeAsBytesSync(made);
    }
    return made;
  }

  Future<Uint8List?> _make(ThumbSource source, {required bool gallery}) async {
    try {
      final data = await github.download(
        source.url,
        maxBytes: maxSourceBytes,
      );
      if (Sha256.hexOf(data) != source.sha256) return null;
      return gallery ? makeGalleryPicture(data) : makeThumbnail(data);
    } on Object {
      return null;
    }
  }

  /// [data] decoded, when it is a picture this reads with no side over
  /// [maxSourceSide] pixels (checked before it is decoded).
  static img.Image? _decode(Uint8List data) {
    final decoder = img.findDecoderForData(data);
    if (decoder == null) return null;
    final info = decoder.startDecode(data);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width > maxSourceSide ||
        info.height > maxSourceSide) {
      return null;
    }
    return decoder.decode(data, frame: 0);
  }

  /// [image] on a dark backdrop where it is transparent, as a JPEG.
  static Uint8List _jpeg(img.Image image, int quality) {
    final out = img.Image(width: image.width, height: image.height)
      ..clear(img.ColorRgb8(32, 33, 36));
    img.compositeImage(out, image);
    return img.encodeJpg(out, quality: quality);
  }

  /// [data], a picture, as a [width]×[height] JPEG cropped to fill it; null
  /// when it is not a picture this reads ([_decode]).
  static Uint8List? makeThumbnail(Uint8List data) {
    final image = _decode(data);
    if (image == null) return null;
    final scale = max(width / image.width, height / image.height);
    final resized = img.copyResize(
      image,
      width: max(width, (image.width * scale).ceil()),
      height: max(height, (image.height * scale).ceil()),
      // Pixel art stays crisp when made larger; photos blend when smaller.
      interpolation: scale > 1
          ? img.Interpolation.nearest
          : img.Interpolation.average,
    );
    final cropped = img.copyCrop(
      resized,
      x: (resized.width - width) ~/ 2,
      y: (resized.height - height) ~/ 2,
      width: width,
      height: height,
    );
    return _jpeg(cropped, 80);
  }

  /// [data], a picture, as a JPEG within [galleryWidth]×[galleryHeight],
  /// whole (never cropped or made larger); null when it is not a picture
  /// this reads ([_decode]).
  static Uint8List? makeGalleryPicture(Uint8List data) {
    final image = _decode(data);
    if (image == null) return null;
    final scale = min(
      1.0,
      min(galleryWidth / image.width, galleryHeight / image.height),
    );
    final fitted = scale >= 1
        ? image
        : img.copyResize(
            image,
            width: max(1, (image.width * scale).round()),
            height: max(1, (image.height * scale).round()),
            interpolation: img.Interpolation.average,
          );
    return _jpeg(fitted, 85);
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:just_signals/just_signals.dart';

import '../auth/store_auth.dart';

/// Something the store told a publisher: a release it refused, a version
/// waiting for a maintainer.
final class StoreNotice {
  const StoreNotice(this.at, this.text);

  final DateTime at;
  final String text;

  /// The notices in the backend's `messages` text (a JSON list of
  /// `{atMs, text}`, oldest first), newest first; anything unreadable is
  /// left out.
  static List<StoreNotice> parse(Object? messages) {
    if (messages is! String) return const [];
    final Object? list;
    try {
      list = jsonDecode(messages);
    } on FormatException {
      return const [];
    }
    if (list is! List) return const [];
    return [
      for (final m in list.reversed)
        if (m is Map && m['atMs'] is int && m['text'] is String)
          StoreNotice(
            DateTime.fromMillisecondsSinceEpoch(m['atMs'] as int, isUtc: true),
            m['text'] as String,
          ),
    ];
  }
}

/// Where the store's notices are: one document per GitHub account,
/// readable by whoever signed in with it.
abstract interface class NoticeStore {
  /// The notices to the GitHub account numbered [githubId], as they change.
  Stream<List<StoreNotice>> watch(String githubId);
}

/// None: sign-in isn't set up.
final class NoNoticeStore implements NoticeStore {
  const NoNoticeStore();

  @override
  Stream<List<StoreNotice>> watch(String githubId) => Stream.value(const []);
}

/// The signed-in user's notices, followed live.
final class NoticesController {
  NoticesController(this.auth, this.store) {
    _effect = Effect(() {
      _follow(auth.user.value?.githubId);
      return null;
    }, debugLabel: 'notices');
  }

  final StoreAuth auth;
  final NoticeStore store;

  /// Theirs, newest first; null while signed out or loading.
  final Signal<List<StoreNotice>?> mine = Signal<List<StoreNotice>?>(
    null,
    debugLabel: 'myNotices',
  );

  Effect? _effect;
  StreamSubscription<List<StoreNotice>>? _sub;
  String? _id;

  void _follow(String? githubId) {
    if (githubId == _id) return;
    _id = githubId;
    _sub?.cancel();
    _sub = null;
    mine.value = null;
    if (githubId == null) return;
    _sub = store.watch(githubId).listen(
      (list) => mine.value = list,
      // Unreadable now: nothing to show is better than an error here.
      onError: (Object _) => mine.value = const [],
    );
  }

  void dispose() {
    _effect?.dispose();
    _sub?.cancel();
  }
}

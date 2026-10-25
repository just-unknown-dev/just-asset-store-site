import 'dart:async';
import 'dart:convert';

import 'package:just_storage/just_storage.dart';

/// Test double for [JustStandardStorage].
class InMemoryStorage implements JustStandardStorage {
  InMemoryStorage([Map<String, String>? initial]) : _data = {...?initial};

  final Map<String, String> _data;
  final Map<String, StreamController<String?>> _watchers = {};

  Map<String, String> get snapshot => Map.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
    _watchers[key]?.add(value);
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
    _watchers[key]?.add(null);
  }

  @override
  Future<void> clear() async {
    final keys = _data.keys.toList();
    _data.clear();
    for (final k in keys) {
      _watchers[k]?.add(null);
    }
  }

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(_data);

  @override
  Future<T?> readJson<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final raw = _data[key];
    if (raw == null) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeJson<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson,
  ) => write(key, jsonEncode(toJson(value)));

  @override
  Stream<String?> watch(String key) {
    final c = _watchers.putIfAbsent(
      key,
      () => StreamController<String?>.broadcast(),
    );
    late StreamController<String?> out;
    out = StreamController<String?>(
      onListen: () {
        out.add(_data[key]);
        out.addStream(c.stream);
      },
    );
    return out.stream;
  }
}

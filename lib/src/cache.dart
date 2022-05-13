import 'package:tusc/src/utils/platform_utils.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

/// Implementations of this interface are used to lookup a
/// [fingerprint] with the corresponding [url].
///
/// This functionality is used to allow resuming uploads.
///
/// See [TusMemoryCache] or [TusPersistentCache]
abstract class TusCache {
  /// Cache a new [fingerprint] and its upload [url].
  Future<void> set(String fingerprint, String url);

  /// Retrieves an upload URL for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  Future<String?> get(String fingerprint);

  /// Remove an entry from the cache using an upload's [fingerprint].
  Future<void> remove(String fingerprint);
}

/// This class is used to cache upload url in memory and to resume upload later.
///
/// This cache **will not** keep the values after your application crashes or
/// restarts.
class TusMemoryCache implements TusCache {
  final _cache = <String, String>{};

  @override
  Future<void> set(String fingerprint, String url) async {
    _cache[fingerprint] = url;
  }

  @override
  Future<String?> get(String fingerprint) async {
    return _cache[fingerprint];
  }

  @override
  Future<void> remove(String fingerprint) async {
    _cache.remove(fingerprint);
  }
}

/// This class is used to cache upload url in a persistent way to resume upload
/// later.
///
/// This cache **will** keep the values after your application crashes or
/// restarts.
class TusPersistentCache implements TusCache {
  bool _isHiveInitialized = false;
  bool _isBoxOpened = false;
  late final Box<String> _box;
  final String path;
  TusPersistentCache(this.path) {
    _initHive();
  }

  Future<void> _initHive() async {
    final cachePath = p.join(path, 'tus');
    if (!PlatformUtils.isWeb) Hive.init(cachePath);
    _isHiveInitialized = true;
  }

  Future<void> _openBox() async {
    if (!_isHiveInitialized) await _initHive();
    if (!_isBoxOpened) _box = await Hive.openBox('tus-persistent-cache');
    _isBoxOpened = _box.isOpen;
  }

  /// Cache a new [fingerprint] and its upload [url].
  @override
  Future<void> set(String fingerprint, String url) async {
    await _openBox();
    _box.put(fingerprint, url);
  }

  /// Retrieve an upload URL for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  @override
  Future<String?> get(String fingerprint) async {
    await _openBox();
    return _box.get(fingerprint);
  }

  /// Remove an entry from the cache using an upload [fingerprint].
  @override
  Future<void> remove(String fingerprint) async {
    await _openBox();
    _box.delete(fingerprint);
  }
}

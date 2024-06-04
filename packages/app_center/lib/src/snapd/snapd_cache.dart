import 'dart:async';
import 'dart:isolate';

import 'package:app_center/snapd.dart';
import 'package:app_center/src/snapd/cache_file.dart';
import 'package:collection/collection.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:snapd/snapd.dart';
import 'package:ubuntu_service/ubuntu_service.dart';

mixin SnapdCache on SnapdClient {
  @visibleForTesting
  final FileSystem defaultFileSystem = const LocalFileSystem();

  Stream<List<Snap>> getCategory(
    String name, {
    Duration expiry = const Duration(days: 1),
    @visibleForTesting FileSystem? fileSystem,
  }) async* {
    final file = CacheFile.fromFileName(
      'category-$name',
      expiry: expiry,
      fileSystem: fileSystem ?? defaultFileSystem,
    );
    if (file.existsSync()) {
      final snaps = await file.readSnapList();
      if (snaps != null) yield snaps;
    }
    if (!file.isValidSync()) {
      final snaps = await find(category: name);
      yield snaps;
      await Isolate.run(() async {
        file.writeSnapListSync(snaps);
        for (final snap in snaps) {
          final snapFile = CacheFile.fromFileName('snap-${snap.name}');
          if (!snapFile.existsSync()) {
            snapFile.writeSnapSync(snap);
          }
        }
      });
    }
  }

  /// Fetches the snaps given by [names] from the store. First yields a list of
  /// cached snaps, where available, and continues to fetch them from the store in
  /// case the cached files are missing/expired or the channel information is
  /// missing.
  Stream<List<Snap>> getStoreSnaps(
    List<String> names, {
    Duration expiry = const Duration(minutes: 1),
    @visibleForTesting FileSystem? fileSystem,
  }) async* {
    // Read and yield cached snaps
    final cacheFiles = {
      for (final name in names)
        name: CacheFile.fromFileName(
          'snap-$name',
          expiry: expiry,
          fileSystem: fileSystem ?? defaultFileSystem,
        )
    };
    final cachedSnaps = Map.fromEntries(
      await Future.wait(
        cacheFiles.entries.map(
          (e) async => MapEntry(
            e.key,
            e.value.existsSync() ? await e.value.readSnap() : null,
          ),
        ),
      ),
    );
    yield cachedSnaps.values.whereNotNull().toList();

    // Fetch and yield snaps from the store if necessary
    final writeToCache = <String, Snap>{};
    final storeSnaps = await Future.wait(
      cachedSnaps.entries.map(
        (e) async {
          if ((e.value?.channels.isEmpty ?? true) ||
              !cacheFiles[e.key]!.isValidSync()) {
            try {
              final snap = await find(name: e.key).then((r) => r.single);
              writeToCache[e.key] = snap;
              return snap;
            } on SnapdException catch (e) {
              if (e.kind == 'snap-not-found') {
                return null;
              } else {
                rethrow;
              }
            }
          } else {
            return e.value;
          }
        },
      ),
    );
    yield storeSnaps.whereNotNull().toList();

    // Save fetched snaps in the cache
    for (final e in writeToCache.entries) {
      await cacheFiles[e.key]!.write(e.value);
    }
  }
}

final storeSnapProvider = StreamProvider.family<Snap?, String>(
  (ref, name) async* {
    const expiry = Duration(minutes: 1);
    final file = CacheFile.fromFileName('snap-$name', expiry: expiry);
    Snap? cachedSnap;
    if (file.existsSync()) {
      cachedSnap = await file.readSnap();
      if (cachedSnap != null) {
        yield cachedSnap;
      }
    }
    final hasChannels = cachedSnap?.channels.isNotEmpty ?? false;
    if (!hasChannels || !file.isValidSync()) {
      final refreshedSnap = await _refreshSnapCache(name, file);
      yield refreshedSnap;
    }
  },
);

Future<Snap?> _refreshSnapCache(String name, CacheFile file) async {
  try {
    final client = getService<SnapdService>();
    final snap = await client.find(name: name).then((r) => r.single);
    await file.writeSnap(snap);
    return snap;
  } on SnapdException catch (e) {
    if (e.kind == 'snap-not-found') {
      return null;
    } else {
      rethrow;
    }
  }
}

// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Benchmark for fnv1 and hashJson.
//
// Usage: dart run benchmark/gg_hash_benchmark.dart [--json]

import 'dart:convert';
import 'dart:typed_data';

import 'package:gg_hash/gg_hash.dart';

// .............................................................................
/// Deterministic pseudo random generator (LCG) so runs are comparable.
class Lcg {
  Lcg([this._state = 0x243F6A8885A308D3]);
  int _state;

  int next() {
    _state =
        (_state * 6364136223846793005 + 1442695040888963407) &
        0x7FFFFFFFFFFFFFFF;
    return _state;
  }

  int nextInt(int max) => next() % max;

  double nextDouble() => next() / 0x7FFFFFFFFFFFFFFF;

  String nextString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}

// .............................................................................
Map<String, dynamic> makeWideJson(int keys) {
  final rng = Lcg(1);
  final result = <String, dynamic>{};
  for (var i = 0; i < keys; i++) {
    result['key_${rng.nextString(8)}_$i'] = switch (i % 4) {
      0 => rng.nextString(16),
      1 => rng.nextInt(1000000),
      2 => rng.nextDouble() * 1000,
      _ => i.isEven,
    };
  }
  return result;
}

// .............................................................................
Map<String, dynamic> makeDeepJson(int depth, int childrenPerLevel) {
  final rng = Lcg(2);
  Map<String, dynamic> level(int remaining) {
    final result = <String, dynamic>{
      'name': rng.nextString(12),
      'value': rng.nextInt(100000),
    };
    if (remaining > 0) {
      for (var i = 0; i < childrenPerLevel; i++) {
        result['child_$i'] = level(remaining - 1);
      }
    }
    return result;
  }

  return level(depth);
}

// .............................................................................
Map<String, dynamic> makeRecordsJson(int records) {
  final rng = Lcg(3);
  return <String, dynamic>{
    'meta': {'version': 1, 'source': 'benchmark'},
    'records': [
      for (var i = 0; i < records; i++)
        {
          'id': i,
          'name': rng.nextString(20),
          'score': rng.nextDouble() * 100,
          'active': i % 3 == 0,
          'tags': [rng.nextString(6), rng.nextString(6), rng.nextString(6)],
          'address': {
            'street': rng.nextString(24),
            'zip': rng.nextInt(99999),
            'geo': {
              'lat': rng.nextDouble() * 180 - 90,
              'lon': rng.nextDouble() * 360 - 180,
            },
          },
        },
    ],
  };
}

// .............................................................................
class BenchResult {
  BenchResult(this.name, this.microsPerOp, this.checksum);
  final String name;
  final double microsPerOp;
  final Object? checksum;
}

// .............................................................................
BenchResult bench(
  String name,
  Object? Function() body, {
  int minIterations = 10,
  int minMillis = 500,
}) {
  // Warmup
  Object? checksum;
  for (var i = 0; i < 3; i++) {
    checksum = body();
  }

  // Measure until minMillis and minIterations are reached
  final stopwatch = Stopwatch()..start();
  var iterations = 0;
  while (iterations < minIterations ||
      stopwatch.elapsedMilliseconds < minMillis) {
    body();
    iterations++;
  }
  stopwatch.stop();

  final microsPerOp = stopwatch.elapsedMicroseconds / iterations;
  return BenchResult(name, microsPerOp, checksum);
}

// .............................................................................
void main(List<String> args) {
  final asJson = args.contains('--json');

  // Inputs
  final bytes1M = Uint8List(1024 * 1024);
  final rng = Lcg(4);
  for (var i = 0; i < bytes1M.length; i++) {
    bytes1M[i] = rng.nextInt(256);
  }
  final bytesOdd = Uint8List.sublistView(bytes1M, 0, 1024 * 1024 - 3);
  final intList = List<int>.generate(100000, (i) => rng.nextInt(1 << 32));
  final stringList = List<String>.generate(20000, (i) => rng.nextString(12));
  final lazyIterable = intList.take(20000).map((e) => e * 2);
  final wideJson = makeWideJson(1000);
  final deepJson = makeDeepJson(7, 3);
  final recordsJson = makeRecordsJson(500);

  final results = <BenchResult>[
    bench('fnv1 Uint8List 1MiB (aligned)', () => fnv1(bytes1M)),
    bench('fnv1 Uint8List 1MiB-3 (unaligned)', () => fnv1(bytesOdd)),
    bench('fnv1 List<int> 100k', () => fnv1(intList)),
    bench('fnv1 List<String> 20k', () => fnv1(stringList)),
    bench('fnv1 lazy Iterable 20k', () => fnv1(lazyIterable)),
    bench('hashJson wide 1000 keys', () => hashJson(wideJson)['_hash']),
    bench('hashJson deep 7x3', () => hashJson(deepJson)['_hash']),
    bench('hashJson 500 records', () => hashJson(recordsJson)['_hash']),
  ];

  if (asJson) {
    print(
      const JsonEncoder.withIndent('  ').convert({
        for (final r in results)
          r.name: {'usPerOp': r.microsPerOp, 'checksum': '${r.checksum}'},
      }),
    );
  } else {
    for (final r in results) {
      final us = r.microsPerOp.toStringAsFixed(1).padLeft(12);
      print('$us us/op  ${r.name}  (checksum: ${r.checksum})');
    }
  }
}

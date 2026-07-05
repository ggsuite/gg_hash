// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Verifies that fnv1 and hashJson produce bit-identical results
// compared to previously recorded golden values.
//
// Usage:
//   dart run benchmark/golden_check.dart --record   # write goldens
//   dart run benchmark/golden_check.dart            # verify against goldens

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gg_hash/gg_hash.dart';

enum Color { red, green, blue }

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
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"\\äöü';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[nextInt(chars.length)]);
    }
    return buffer.toString();
  }
}

// .............................................................................
dynamic randomJsonValue(Lcg rng, int depth) {
  final choice = depth <= 0 ? rng.nextInt(6) : rng.nextInt(8);
  switch (choice) {
    case 0:
      return rng.nextString(rng.nextInt(20) + 1);
    case 1:
      return rng.nextInt(1 << 40) - (1 << 39);
    case 2:
      return rng.nextDouble() * 1e6 - 5e5;
    case 3:
      return rng.next().isEven;
    case 4:
      // Doubles with many decimal places to exercise truncation
      return rng.nextDouble() * 1e-4;
    case 5:
      return rng.nextInt(100);
    case 6:
      return [
        for (var i = 0, n = rng.nextInt(5); i < n; i++)
          randomJsonValue(rng, depth - 1),
      ];
    default:
      return randomJsonMap(rng, depth - 1, rng.nextInt(5));
  }
}

// .............................................................................
Map<String, dynamic> randomJsonMap(Lcg rng, int depth, int keys) {
  return {
    for (var i = 0; i < keys; i++)
      '${rng.nextString(rng.nextInt(10) + 1)}_$i': randomJsonValue(rng, depth),
  };
}

// .............................................................................
Map<String, dynamic> computeGoldens() {
  final result = <String, dynamic>{};

  // ................
  // fnv1 test inputs
  final rng = Lcg(42);

  // Typed data of various lengths, alignments and element types
  for (final length in [0, 1, 2, 7, 8, 9, 63, 64, 65, 1000, 4096]) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    result['fnv1 Uint8List $length'] = fnv1(bytes);
    if (length >= 8) {
      result['fnv1 Uint8List $length sub'] = fnv1(bytes, 1, length - 2);
    }
  }
  final uint16 = Uint16List.fromList(
    List.generate(31, (i) => rng.nextInt(1 << 16)),
  );
  result['fnv1 Uint16List 31'] = fnv1(uint16);
  final int32 = Int32List.fromList(
    List.generate(17, (i) => rng.nextInt(1 << 31) - (1 << 30)),
  );
  result['fnv1 Int32List 17'] = fnv1(int32);
  final float64 = Float64List.fromList(
    List.generate(9, (i) => rng.nextDouble() * 1e5),
  );
  result['fnv1 Float64List 9'] = fnv1(float64);

  // Plain lists: ints, negative ints, strings, enums, bools, doubles, mixed
  final ints = List.generate(100, (i) => rng.nextInt(1 << 40) - (1 << 39));
  result['fnv1 List<int>'] = fnv1(ints);
  result['fnv1 List<int> sub'] = fnv1(ints, 3, 77);
  result['fnv1 List<String>'] = fnv1(
    List.generate(50, (i) => rng.nextString(rng.nextInt(20) + 1)),
  );
  result['fnv1 List<Enum>'] = fnv1(
    List.generate(20, (i) => Color.values[rng.nextInt(3)]),
  );
  result['fnv1 List mixed'] = fnv1(<dynamic>[
    1,
    'two',
    Color.blue,
    4,
    -5,
    'six',
    Color.red,
  ]);
  result['fnv1 empty'] = fnv1(<int>[]);

  // Lazy iterable
  result['fnv1 lazy iterable'] = fnv1(ints.map((e) => e * 3));

  // ....................
  // hashJson test inputs
  for (var seed = 0; seed < 20; seed++) {
    final json = randomJsonMap(Lcg(seed + 100), 4, 8);
    final hashed = hashJson(json);
    result['hashJson seed $seed'] = hashed['_hash'];
    result['hashJson seed $seed full'] = jsonEncode(hashed);
  }

  // Different hash lengths and precisions
  final sample = randomJsonMap(Lcg(999), 3, 6);
  result['hashJson len 10'] = hashJson(sample, hashLength: 10)['_hash'];
  result['hashJson precision 3'] = hashJson(
    sample,
    floatingPointPrecision: 3,
  )['_hash'];

  // Edge cases
  result['hashJson empty'] = jsonEncode(hashJson({}));
  result['hashJson escaping'] = jsonEncode(
    hashJson({'a"b': 'c"d\\e', 'x': 'ü€😀'}),
  );
  result['hashJson int-like double'] = jsonEncode(
    hashJson({'a': 1.0, 'b': -0.0, 'd': 3.14159265358979}),
  );

  return result;
}

// .............................................................................
void main(List<String> args) {
  // Resolve the goldens file relative to this script, not the working dir
  final goldenFile = File.fromUri(Platform.script.resolve('goldens.json'));

  final goldens = computeGoldens();

  if (args.contains('--record')) {
    goldenFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(goldens),
    );
    print('Recorded ${goldens.length} goldens to ${goldenFile.path}');
    return;
  }

  if (!goldenFile.existsSync()) {
    print('No goldens found. Run with --record first.');
    exit(2);
  }

  final expected = jsonDecode(goldenFile.readAsStringSync());
  var failures = 0;
  for (final key in (expected as Map<String, dynamic>).keys) {
    final want = expected[key];
    final got = goldens[key];
    if ('$want' != '$got') {
      print('MISMATCH: $key\n  want: $want\n  got:  $got');
      failures++;
    }
  }
  if (goldens.length != expected.length) {
    print(
      'COUNT MISMATCH: ${goldens.length} computed vs ${expected.length} '
      'recorded',
    );
    failures++;
  }

  if (failures > 0) {
    print('$failures golden check(s) FAILED');
    exit(1);
  }
  print('All ${goldens.length} golden checks passed.');
}

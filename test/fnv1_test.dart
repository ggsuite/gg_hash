// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:typed_data';

import 'package:gg_hash/src/fnv1.dart';
import 'package:test/test.dart';

enum E { x, y, z }

// .............................................................................
/// The original fnv1 implementation, kept as a reference
int referenceFnv1(Iterable<dynamic> data, [int start = 0, int? end]) {
  const int prime = 16777619;
  int hash = 2166136261;

  hash ^= ((end ?? data.length) - start).hashCode;
  end ??= data.length;

  if (data is TypedData) {
    final typedData = Int8List.sublistView(data as TypedData, start, end);
    final byteCount = typedData.lengthInBytes;

    if (byteCount % 8 != 0) {
      final requiredByteCount = (byteCount ~/ 8 + 1) * 8;
      final dataNew = Uint8List(requiredByteCount);
      dataNew.setRange(0, byteCount, typedData);
      start = 0;
      end = requiredByteCount;
      data = dataNew;
    }

    data = Int64List.sublistView(data as TypedData, start, end);
    start = 0;
    end = data.length;
  }

  for (int i = start; i < end; i++) {
    final val = data.elementAt(i);
    hash = hash * prime;
    hash =
        hash ^
        ((val is Enum)
            ? val.name.hashCode
            : val is int
            ? val
            : val.hashCode);
  }

  return hash;
}

// #############################################################################
void main() {
  group('fnv1(data, start, end)', () {
    // #########################################################################
    test('Should work fine for buffers with length devidable by 8', () {
      final buffer = Uint16List(8);
      final hash = fnv1(buffer);
      expect(hash, -8227345800955486059);
    });

    // #########################################################################
    test('Should work fine for buffers with length not devidable by 8', () {
      final buffer = Uint16List(7);
      final hash = fnv1(buffer);
      expect(hash, 3996532018526443330);
    });

    // #########################################################################
    test('Should work fine for strings', () {
      final buffer = ['a', 'b', 'c'];
      final hash = fnv1(buffer);
      expect(hash, 6619819810309098008);
    });

    // #########################################################################
    test('Should work for enums', () {
      final buffer = [E.x, E.y, E.z];
      final hash = fnv1(buffer);
      expect(hash, 2114034622316947657);
    });

    // #########################################################################
    group('Should match the reference implementation', () {
      test('for typed data of various lengths and offsets', () {
        final bytes = Uint8List.fromList(
          List.generate(64, (i) => (i * 37 + 11) & 0xFF),
        );

        for (final length in [0, 1, 7, 8, 9, 16, 23, 31, 32, 63, 64]) {
          final buffer = Uint8List.sublistView(bytes, 0, length);
          expect(fnv1(buffer), referenceFnv1(buffer), reason: 'len $length');
        }

        // Views with an offset not devidable by 8 use the copy fallback
        final unaligned = Uint8List.sublistView(bytes, 3, 24);
        expect(fnv1(unaligned), referenceFnv1(unaligned));

        // Sub ranges passed via start and end
        expect(fnv1(bytes, 1, 60), referenceFnv1(bytes, 1, 60));
        expect(fnv1(bytes, 8, 56), referenceFnv1(bytes, 8, 56));

        // Other element types
        final uint16 = Uint16List.fromList(List.generate(9, (i) => i * 999));
        expect(fnv1(uint16), referenceFnv1(uint16));
        final float64 = Float64List.fromList([1.5, -2.5, 3.25]);
        expect(fnv1(float64), referenceFnv1(float64));
      });

      test('for lists of ints', () {
        final ints = List.generate(100, (i) => i * i * 31 - 5000);
        expect(fnv1(ints), referenceFnv1(ints));
        expect(fnv1(ints, 3, 77), referenceFnv1(ints, 3, 77));
        expect(fnv1(<int>[]), referenceFnv1(<int>[]));
      });

      test('for lists of strings', () {
        final strings = ['alpha', 'beta', '', 'ü€😀', 'q"uote'];
        expect(fnv1(strings), referenceFnv1(strings));
        expect(fnv1(strings, 1, 4), referenceFnv1(strings, 1, 4));
      });

      test('for mixed lists', () {
        final mixed = <dynamic>[1, 'two', E.z, -4, 5.5, true, E.x];
        expect(fnv1(mixed), referenceFnv1(mixed));
        expect(fnv1(mixed, 2, 6), referenceFnv1(mixed, 2, 6));
      });

      test('for lazy iterables of ints', () {
        final ints = List.generate(20, (i) => i * 7 - 50);
        final lazy = ints.where((e) => true);
        expect(fnv1(lazy), referenceFnv1(lazy));
        expect(fnv1(lazy, 2, 17), referenceFnv1(lazy, 2, 17));
      });

      test('for other lazy iterables', () {
        final lazy = ['a', 'b', 'c', E.y, 5].map<dynamic>((e) => e);
        expect(fnv1(lazy), referenceFnv1(lazy));
      });
    });

    // #########################################################################
    test('Should throw for unaligned views with a length devidable by 8, '
        'like the reference implementation', () {
      final bytes = Uint8List(64);
      final unaligned = Uint8List.sublistView(bytes, 4, 20);
      expect(() => fnv1(unaligned), throwsArgumentError);
      expect(() => referenceFnv1(unaligned), throwsArgumentError);
    });
  });
}

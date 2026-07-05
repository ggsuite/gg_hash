// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Verifies that the optimized hashJson implementation produces results
// bit-identical to the original, package:crypto based implementation.

import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:gg_hash/gg_hash.dart';
import 'package:test/test.dart';

// .............................................................................
/// Calculates a hash like the original, package:crypto based implementation
String referenceCalcHash(String string, {int hashLength = 22}) {
  final digest = sha256.convert(utf8.encode(string));
  return base64Encode(digest.bytes).substring(0, hashLength);
}

// #############################################################################
/// The original hashJson implementation, kept as a reference.
///
/// Slightly simplified: the unsupported-type checks of the original are
/// omitted because unsupported types already throw while copying, before
/// any hashing happens. For all inputs the original could hash, this class
/// behaves identically.
class ReferenceHashJson {
  const ReferenceHashJson({
    this.hashLength = 22,
    this.floatingPointPrecision = 10,
  });

  final int hashLength;
  final int floatingPointPrecision;

  Map<String, dynamic> applyTo(Map<String, dynamic> json) {
    final copy = _copyJson(json);
    _addHashesToObject(copy);
    return copy;
  }

  String calcHash(String string) =>
      referenceCalcHash(string, hashLength: hashLength);

  void _addHashesToObject(Map<String, dynamic> obj) {
    obj.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _addHashesToObject(value);
      } else if (value is List<dynamic>) {
        _processList(value);
      }
    });

    final objToHash = <String, dynamic>{};

    for (final entry in obj.entries) {
      final key = entry.key;
      if (key == '_hash') continue;
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        objToHash[key] = value['_hash'] as String;
      } else if (value is List<dynamic>) {
        objToHash[key] = _flattenList(value);
      } else if (value is double) {
        objToHash[key] = _truncate(value, floatingPointPrecision);
      } else {
        objToHash[key] = value;
      }
    }

    final sortedMap = SplayTreeMap<String, dynamic>.from(objToHash);
    obj['_hash'] = calcHash(_jsonString(sortedMap));
  }

  List<dynamic> _flattenList(List<dynamic> list) {
    return [
      for (final element in list)
        element is Map<String, dynamic>
            ? element['_hash'] as String
            : element is List<dynamic>
            ? _flattenList(element)
            : element.toString(),
    ];
  }

  void _processList(List<dynamic> list) {
    for (final element in list) {
      if (element is Map<String, dynamic>) {
        _addHashesToObject(element);
      } else if (element is List<dynamic>) {
        _processList(element);
      }
    }
  }

  static Map<String, dynamic> _copyJson(Map<String, dynamic> json) {
    return {
      for (final entry in json.entries)
        entry.key: entry.value is Map<String, dynamic>
            ? _copyJson(entry.value as Map<String, dynamic>)
            : entry.value is List<dynamic>
            ? _copyList(entry.value as List<dynamic>)
            : entry.value,
    };
  }

  static List<dynamic> _copyList(List<dynamic> list) {
    return [
      for (final element in list)
        element is Map<String, dynamic>
            ? _copyJson(element)
            : element is List<dynamic>
            ? _copyList(element)
            : element,
    ];
  }

  static double _truncate(double value, int precision) {
    String result = value.toString();
    final parts = result.split('.');
    final integerPart = parts[0];
    final commaParts = parts[1];

    final truncatedCommaParts = commaParts.length > precision
        ? commaParts.substring(0, precision)
        : commaParts;

    if (truncatedCommaParts.isEmpty) {
      return double.parse(integerPart);
    }

    return double.parse('$integerPart.$truncatedCommaParts');
  }

  static String _jsonString(Map<String, dynamic> map) {
    String encodeValue(dynamic value) {
      if (value is String) {
        return '"${value.replaceAll('"', '\\"')}"';
      } else if (value is num || value is bool) {
        return value.toString();
      } else if (value is List) {
        return '[${value.map(encodeValue).join(",")}]';
      } else {
        return _jsonString(value as Map<String, dynamic>);
      }
    }

    return '{${map.entries.map((e) => '"${e.key}"'
        ':${encodeValue(e.value)}').join(",")}}';
  }
}

// .............................................................................
/// Generates a random JSON value
dynamic randomJsonValue(Random random, int depth) {
  final choice = random.nextInt(depth <= 0 ? 6 : 8);
  switch (choice) {
    case 0:
      return randomString(random);
    case 1:
      return random.nextInt(1 << 32) - (1 << 31);
    case 2:
      return randomDouble(random);
    case 3:
      return random.nextBool();
    case 4:
      return randomString(random, unicode: true);
    case 5:
      return random.nextInt(100);
    case 6:
      return [
        for (var i = 0, n = random.nextInt(5); i < n; i++)
          randomJsonValue(random, depth - 1),
      ];
    default:
      return randomJsonMap(random, depth - 1);
  }
}

// .............................................................................
/// Generates a random double whose toString contains a decimal point.
///
/// Doubles printed in exponent notation are excluded because the original
/// implementation cannot process them.
double randomDouble(Random random) {
  while (true) {
    final value = (random.nextDouble() - 0.5) * pow(10, random.nextInt(8));
    if (value.toString().contains('.')) {
      return value;
    }
  }
}

// .............................................................................
/// Generates a random string, including quotes, backslashes and unicode
String randomString(Random random, {bool unicode = false}) {
  const ascii = 'abcdefghijklmnopqrstuvwxyzABC XYZ0123456789"\\/.:{}[]';
  const extra = 'äöüß€😀𝄞߿ࠀ�';
  final chars = unicode ? ascii + extra : ascii;
  final length = random.nextInt(24);
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    // Iterate runes so surrogate pairs stay intact
    final runes = chars.runes.toList();
    buffer.writeCharCode(runes[random.nextInt(runes.length)]);
  }
  return buffer.toString();
}

// .............................................................................
Map<String, dynamic> randomJsonMap(Random random, int depth) {
  return {
    for (var i = 0, n = random.nextInt(8); i < n; i++)
      '${randomString(random)}_$i': randomJsonValue(random, depth),
  };
}

// #############################################################################
void main() {
  group('calcHash', () {
    test('should match the package:crypto reference for known vectors', () {
      const vectors = [
        '',
        'abc',
        'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
      ];
      for (final vector in vectors) {
        expect(
          const HashJson().calcHash(vector),
          referenceCalcHash(vector),
          reason: 'vector: "$vector"',
        );
      }

      // NIST FIPS 180-2 test vector: SHA-256("abc")
      expect(
        base64Encode([
          for (var i = 0; i < 64; i += 2)
            int.parse(
              ('ba7816bf8f01cfea414140de5dae2223'
                      'b00361a396177a9cb410ff61f20015ad')
                  .substring(i, i + 2),
              radix: 16,
            ),
        ]).substring(0, 22),
        const HashJson().calcHash('abc'),
      );
    });

    test('should match the reference for all message lengths 0..200', () {
      // Covers all tail lengths around the 55/56 and 63/64 padding and
      // block boundaries of SHA-256
      final random = Random(42);
      for (var length = 0; length <= 200; length++) {
        final message = String.fromCharCodes([
          for (var i = 0; i < length; i++) 0x20 + random.nextInt(0x5F),
        ]);
        expect(
          const HashJson().calcHash(message),
          referenceCalcHash(message),
          reason: 'length: $length',
        );
      }
    });

    test('should match the reference for long and unicode messages', () {
      final random = Random(7);
      final messages = [
        'a' * 100000,
        for (var i = 0; i < 50; i++) randomString(random, unicode: true) * 20,
      ];
      for (final message in messages) {
        expect(const HashJson().calcHash(message), referenceCalcHash(message));
      }
    });

    test('should match the reference for all hash lengths', () {
      for (var hashLength = 1; hashLength <= 44; hashLength++) {
        expect(
          HashJson(hashLength: hashLength).calcHash('gg_hash'),
          referenceCalcHash('gg_hash', hashLength: hashLength),
          reason: 'hashLength: $hashLength',
        );
      }
    });

    test('should throw a RangeError for hash lengths exceeding 44', () {
      // A base64 encoded SHA-256 digest has 44 characters.
      // The reference threw a RangeError in String.substring.
      for (final hashLength in [45, 64, 1000]) {
        expect(
          () => HashJson(hashLength: hashLength).calcHash('gg_hash'),
          throwsRangeError,
          reason: 'hashLength: $hashLength',
        );
        expect(
          () => referenceCalcHash('gg_hash', hashLength: hashLength),
          throwsRangeError,
          reason: 'hashLength: $hashLength',
        );
      }
    });
  });

  group('hashJson', () {
    test('should match the original implementation on random documents', () {
      for (var seed = 0; seed < 200; seed++) {
        final random = Random(seed);
        final json = randomJsonMap(random, 4);
        final expected = const ReferenceHashJson().applyTo(json);
        final actual = hashJson(json);
        expect(
          jsonEncode(actual),
          jsonEncode(expected),
          reason: 'seed: $seed, json: ${jsonEncode(json)}',
        );
      }
    });

    test('should match the original implementation for '
        'other hash lengths and precisions', () {
      for (var seed = 0; seed < 50; seed++) {
        final random = Random(1000 + seed);
        final json = randomJsonMap(random, 3);
        expect(
          jsonEncode(hashJson(json, hashLength: 10)),
          jsonEncode(const ReferenceHashJson(hashLength: 10).applyTo(json)),
        );
        expect(
          jsonEncode(hashJson(json, floatingPointPrecision: 3)),
          jsonEncode(
            const ReferenceHashJson(floatingPointPrecision: 3).applyTo(json),
          ),
        );
      }
    });

    test('should match the original implementation for existing hashes', () {
      final json = {
        'a': 1,
        '_hash': 'stale',
        'child': {'x': true, '_hash': 'also stale'},
      };
      expect(
        jsonEncode(hashJson(json)),
        jsonEncode(const ReferenceHashJson().applyTo(json)),
      );
    });

    test('should match the original implementation for large documents', () {
      // Exercises the growth of the internal byte buffer
      final json = {
        'text': 'abcdefghijklmnopqrstuvwxyz' * 50000,
        'unicodeText': 'grüße aus der straße 😀' * 20000,
        'list': [for (var i = 0; i < 1000; i++) 'element $i'],
        for (var i = 0; i < 200; i++) 'key $i': 'value $i',
      };
      expect(
        jsonEncode(hashJson(json)),
        jsonEncode(const ReferenceHashJson().applyTo(json)),
      );
    });

    test('should match the original implementation for '
        'unicode and quotes in keys, values and lists', () {
      final json = {
        'ünï"code key': 'ünï"code \\value',
        'nested': {
          'list': [
            'ü€😀',
            'q"uote',
            ['ß', 'plain'],
            {'k': 'ünï"code'},
          ],
        },
        'asciiOnly': 'plain value',
      };
      expect(
        jsonEncode(hashJson(json)),
        jsonEncode(const ReferenceHashJson().applyTo(json)),
      );
    });

    test('should match the original implementation for '
        'a floating point precision of zero', () {
      final json = {'a': 1.5, 'b': 0.25, 'c': 100.0};
      expect(
        jsonEncode(hashJson(json, floatingPointPrecision: 0)),
        jsonEncode(
          const ReferenceHashJson(floatingPointPrecision: 0).applyTo(json),
        ),
      );
    });

    test('should throw on unsupported types in lists', () {
      expect(
        () => hashJson({
          'list': [DateTime(2024)],
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unsupported type: DateTime'),
          ),
        ),
      );
    });
  });
}

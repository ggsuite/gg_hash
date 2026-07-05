// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';

import 'package:gg_hash/gg_hash.dart';
import 'package:test/test.dart';
import 'example_json.dart';

void main() {
  final calcHash = const HashJson().calcHash;

  group('hashJson', () {
    group('with a simple json', () {
      group('containing only one key value pair', () {
        test('with a string value', () {
          final json = hashJson(const {'key': 'value'});
          expect(json['key'], 'value');
          final expectedHash = calcHash('{"key":"value"}');
          expect(json['_hash'], expectedHash);
          expect(json['_hash'], '5Dq88zdSRIOcAS+WM/lYYt');
        });

        test('with a int value', () {
          final json = hashJson(const {'key': 1});
          expect(json['key'], 1);
          final expectedHash = calcHash('{"key":1}');
          expect(json['_hash'], expectedHash);
          expect(json['_hash'], 't4HVsGBJblqznOBwy6IeLt');
        });

        test('with a bool value', () {
          final json = hashJson(const {'key': true});
          expect(json['key'], true);
          final expectedHash = calcHash('{"key":true}');
          expect(json['_hash'], expectedHash);
          expect(json['_hash'], 'dNkCrIe79x2dPyf5fywwYO');
        });

        test('with a long double value', () {
          final json = hashJson(const {'key': 1.0123456789012345});
          final expectedHash = calcHash('{"key":1.0123456789}');
          expect(json['_hash'], expectedHash);
          expect(json['_hash'], 'Cj6IqsbT9fSKfeVVkytoqA');
        });

        test('with a short double value', () {
          final json = hashJson(const {'key': 1.012000});
          final expectedHash = calcHash('{"key":1.012}');
          expect(json['_hash'], expectedHash);
          expect(json['_hash'], 'ppGtYoP5iHFqst5bPeAGMf');
        });
      });

      test('existing _hash should be overwritten', () {
        final json = hashJson({'key': 'value', '_hash': 'oldHash'});
        expect(json['key'], 'value');
        final expectedHash = calcHash('{"key":"value"}');
        expect(json['_hash'], expectedHash);
        expect(json['_hash'], '5Dq88zdSRIOcAS+WM/lYYt');
      });

      group('containing floating point numbers', () {
        test('truncates the floating point numbers to "hashFloatingPrecision" '
            '10 decimal places', () {
          final hash0 = hashJson(const {
            'key': 1.01234567890123456789,
          }, floatingPointPrecision: 9)['_hash'];

          final hash1 = hashJson(const {
            'key': 1.01234567890123456389,
          }, floatingPointPrecision: 9)['_hash'];
          final expectedHash = calcHash('{"key":1.012345678}');
          expect(hash0, hash1);
          expect(hash0, expectedHash);
        });
      });

      group('containing three key value pairs', () {
        const json0 = {'a': 'value', 'b': 1.0, 'c': true};

        const json1 = {'b': 1.0, 'a': 'value', 'c': true};

        late Map<String, dynamic> j0;
        late Map<String, dynamic> j1;

        setUpAll(() {
          j0 = hashJson(json0);
          j1 = hashJson(json1);
        });

        test('should create a string of key value pairs and hash it', () {
          final expectedHash = calcHash('{"a":"value","b":1.0,"c":true}');

          expect(j0['_hash'], expectedHash);
          expect(j1['_hash'], expectedHash);
        });

        test('should sort work independent of key order', () {
          expect(j0, j1);
          expect(j0['_hash'], j1['_hash']);
          expect(true.toString(), 'true');
        });
      });
    });

    group('with a nested json', () {
      test('of level 1', () {
        // Hash an parent object containing one child object
        final parent = hashJson(const {
          'key': 'value',
          'child': {'key': 'value'},
        });

        // Check the hash of the child object
        final child = parent['child'] as Map<String, dynamic>;
        final childHash = calcHash('{"key":"value"}');
        expect(child['_hash'], childHash);

        // Check the hash of the top level object
        final parentHash = calcHash('{"child":"$childHash","key":"value"}');

        expect(parent['_hash'], parentHash);
      });

      test('of level 2', () {
        // Hash an parent object containing one child object
        final parent = hashJson(const {
          'key': 'value',
          'child': {
            'key': 'value',
            'grandChild': {'key': 'value'},
          },
        });

        // Check the hash of the grandChild object
        final grandChild =
            parent['child']!['grandChild'] as Map<String, dynamic>;
        final grandChildHash = calcHash('{"key":"value"}');
        expect(grandChild['_hash'], grandChildHash);

        // Check the hash of the child object
        final child = parent['child'] as Map<String, dynamic>;
        final childHash = calcHash(
          '{"grandChild":"$grandChildHash","key":"value"}',
        );
        expect(child['_hash'], childHash);

        // Check the hash of the top level object
        final parentHash = calcHash('{"child":"$childHash","key":"value"}');
        expect(parent['_hash'], parentHash);
      });
    });

    test('with complete json example', () {
      final json = jsonDecode(exampleJson) as Map<String, dynamic>;
      final hashedJson = hashJson(json);

      JsonEncoder encoder = const JsonEncoder.withIndent('  ');
      final hashedJsonString = encoder.convert(hashedJson);
      // print(hashedJsonString);
      // return;
      expect(hashedJsonString, exampleJsonWithHashes);
    });

    group('with an array', () {
      group('on top level', () {
        group('containing only simple types', () {
          test('should convert all values to strings and hash it', () {
            final json = hashJson({
              'key': ['value', 1.0, true],
            });

            final expectedHash = calcHash('{"key":["value","1.0","true"]}');

            expect(json['_hash'], expectedHash);
            expect(json['_hash'], '1DJgJ9oBYJWG04HMShLE9o');
          });
        });

        group('containing nested objects', () {
          group('should hash the nested objects', () {
            group('and use the hash instead of the stringified value', () {
              test('with a complicated array', () {
                final json = hashJson({
                  'array': [
                    'key',
                    1.0,
                    true,
                    {'key1': 'value1'},
                    {'key0': 'value0'},
                  ],
                });

                final h0 = calcHash('{"key0":"value0"}');
                final h1 = calcHash('{"key1":"value1"}');
                final expectedHash = calcHash(
                  '{"array":["key","1.0","true","$h1","$h0"]}',
                );

                expect(json['_hash'], expectedHash);
                expect(json['_hash'], 'THYzkNBHbipTuGn3AEzyyH');
              });

              test('with a simple array', () {
                final json = hashJson({
                  'array': [
                    {'key': 'value'},
                  ],
                });

                // Did hash the array item?
                final itemHash = calcHash('{"key":"value"}');
                final array = json['array'] as List<dynamic>;
                final item0 = array[0] as Map<String, dynamic>;
                expect(item0['_hash'], itemHash);
                expect(itemHash, '5Dq88zdSRIOcAS+WM/lYYt');

                // Did use the array item hash for the array hash?

                final expectedHash = calcHash('{"array":["$itemHash"]}');

                expect(json['_hash'], expectedHash);
                expect(json['_hash'], 'i5C5fpWlcOXE363N3cABei');
              });
            });
          });
        });

        group('containing nested arrays', () {
          test('should hash the nested arrays', () {
            final json = hashJson({
              'array': [
                ['key', 1.0, true],
                'hello',
              ],
            });

            final jsonHash = calcHash(
              '{"array":[["key","1.0","true"],"hello"]}',
            );

            expect(json['_hash'], jsonHash);
            expect(json['_hash'], 'TPZRhkc7IDTK8EftrWmMSw');
          });
        });
      });
    });

    group('throws', () {
      test('when data contains an unsupported type', () {
        late String message;

        try {
          hashJson({'key': Exception()});
        } catch (e) {
          message = e.toString();
        }

        expect(message, 'Exception: Unsupported type: _Exception');
      });

      test('when a list contains an unsupported type', () {
        late String message;

        try {
          hashJson({
            'key': [Exception()],
          });
        } catch (e) {
          message = e.toString();
        }

        expect(message, 'Exception: Unsupported type: _Exception');
      });

      test('a RangeError when the hash length exceeds 44', () {
        // A base64 encoded SHA-256 digest has only 44 characters
        expect(
          () => hashJson(const {'key': 'value'}, hashLength: 45),
          throwsRangeError,
        );
      });
    });

    group('special cases', () {
      test('truncates doubles with a floating point precision of zero', () {
        final json = hashJson(const {'key': 1.5}, floatingPointPrecision: 0);
        expect(json['_hash'], calcHash('{"key":1.0}'));
      });

      test('hashes nested lists following other elements', () {
        final json = hashJson(const {
          'key': [
            1,
            [2],
          ],
        });
        expect(json['_hash'], calcHash('{"key":["1",["2"]]}'));
      });

      test('hashes unicode keys and escapes quotes in values', () {
        final json = hashJson(const {'kèy': 'välüe"'});
        expect(json['_hash'], calcHash('{"kèy":"välüe\\""}'));
      });

      test('hashes documents larger than the internal buffer', () {
        final value = 'a' * 100000;
        final json = hashJson({'key': value});
        expect(json['_hash'], calcHash('{"key":"$value"}'));
      });

      test('supports the full hash length of 44', () {
        final json = hashJson(const {'key': 'value'}, hashLength: 44);
        final hash = json['_hash'] as String;
        expect(
          hash,
          const HashJson(hashLength: 44).calcHash('{"key":"value"}'),
        );
        expect(hash.length, 44);
        expect(hash.endsWith('='), isTrue);
      });
    });

    group('private methods', () {
      group('_copyJson', () {
        final copyJson =
            HashJson.privateMethods['_copyJson']
                as Map<String, dynamic> Function(Map<String, dynamic>);

        test('empty json', () {
          expect(copyJson(<String, dynamic>{}), <String, dynamic>{});
        });

        test('simple value', () {
          expect(copyJson({'a': 1}), {'a': 1});
        });

        test('nested value', () {
          expect(
            copyJson({
              'a': {'b': 1},
            }),
            {
              'a': {'b': 1},
            },
          );
        });

        test('list value', () {
          expect(
            copyJson({
              'a': [1, 2],
            }),
            {
              'a': [1, 2],
            },
          );
        });

        test('list with list', () {
          expect(
            copyJson({
              'a': [
                [1, 2],
              ],
            }),
            {
              'a': [
                [1, 2],
              ],
            },
          );
        });

        test('list with map', () {
          expect(
            copyJson({
              'a': [
                {'b': 1},
              ],
            }),
            {
              'a': [
                {'b': 1},
              ],
            },
          );
        });

        group('throws', () {
          group('on unsupported type', () {
            test('in map', () {
              late String message;
              try {
                copyJson({'a': Exception()});
              } catch (e) {
                message = e.toString();
              }

              expect(message, 'Exception: Unsupported type: _Exception');
            });

            test('in list', () {
              late String message;
              try {
                copyJson({
                  'a': [Exception()],
                });
              } catch (e) {
                message = e.toString();
              }

              expect(message, 'Exception: Unsupported type: _Exception');
            });
          });
        });
      });

      group('_isBasicType', () {
        final isBasicType =
            HashJson.privateMethods['_isBasicType'] as bool Function(dynamic);

        test('returns true if type is a basic type', () {
          expect(isBasicType(1), true);
          expect(isBasicType(1.0), true);
          expect(isBasicType('1'), true);
          expect(isBasicType(true), true);
          expect(isBasicType(false), true);
          expect(isBasicType(<String>{}), false);
        });
      });

      group('_truncate(double, precision)', () {
        final toTruncatedString =
            HashJson.privateMethods['_truncate']
                as double Function(double, int);

        test('truncates commas but only if precision exceeds precision', () {
          expect(toTruncatedString(1.23456789, 2), 1.23);
          expect(toTruncatedString(1.23456789, 3), 1.234);
          expect(toTruncatedString(1.23456789, 4), 1.2345);
          expect(toTruncatedString(1.23456789, 5), 1.23456);
          expect(toTruncatedString(1.23456789, 6), 1.234567);
          expect(toTruncatedString(1.23456789, 7), 1.2345678);
          expect(toTruncatedString(1.23456789, 8), 1.23456789);
          expect(toTruncatedString(1.12, 1), 1.1);
          expect(toTruncatedString(1.12, 2), 1.12);
          expect(toTruncatedString(1.12, 3), 1.12);
          expect(toTruncatedString(1.12, 4), 1.12);
        });

        test('does not add additional commas', () {
          expect(toTruncatedString(1.0, 0), 1);
          expect(toTruncatedString(1.0, 1), 1.0);
          expect(toTruncatedString(1.0, 2), 1.0);
          expect(toTruncatedString(1.0, 3), 1.0);
        });
      });

      group('_jsonString(map)', () {
        final jsonString =
            HashJson.privateMethods['_jsonString']
                as String Function(Map<String, dynamic>);

        test('converts a map into a json string', () {
          expect(jsonString({'a': 1}), '{"a":1}');
          expect(jsonString({'a': 'b'}), '{"a":"b"}');
          expect(jsonString({'a': true}), '{"a":true}');
          expect(jsonString({'a': false}), '{"a":false}');
          expect(jsonString({'a': 1.0}), '{"a":1.0}');
          expect(jsonString({'a': 1.0}), '{"a":1.0}');
          expect(
            jsonString({
              'a': [1, 2],
            }),
            '{"a":[1,2]}',
          );
          expect(
            jsonString({
              'a': {'b': 1},
            }),
            '{"a":{"b":1}}',
          );
        });

        test('throws when unsupported type', () {
          late String message;
          try {
            jsonString({'a': Exception()});
          } catch (e) {
            message = e.toString();
          }

          expect(message, 'Exception: Unsupported type: _Exception');
        });
      });
    });
  });
}

// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// ...........................................................................
import 'dart:convert';
import 'dart:typed_data';

// .............................................................................
/// Deeply hashes a JSON object.
Map<String, dynamic> hashJson(
  Map<String, dynamic> json, {
  int floatingPointPrecision = 10,
  int hashLength = 22,
}) {
  return HashJson(
    hashLength: hashLength,
    floatingPointPrecision: floatingPointPrecision,
  ).applyTo(json);
}

// #############################################################################
/// Adds hashes to JSON object
class HashJson {
  /// Constructor
  const HashJson({this.hashLength = 22, this.floatingPointPrecision = 10});

  /// The hash length in bytes
  final int hashLength;

  /// Round floating point numbers to this precision before hashing
  final int floatingPointPrecision;

  /// Writes hashes into the JSON object
  Map<String, dynamic> applyTo(Map<String, dynamic> json) {
    return _copyAndHash(json);
  }

  /// Calculates a SHA-256 hash of a string
  String calcHash(String string) {
    final bytes = utf8.encode(string);
    _sha256(bytes, bytes.length);
    return _base64Prefix(hashLength);
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  /// Recursively copies a JSON object and adds hashes to the copy.
  Map<String, dynamic> _copyAndHash(Map<String, dynamic> json) {
    // Copy the object, recursively process its child elements
    // and collect the keys to be hashed
    final copy = <String, dynamic>{};
    final keys = <String>[];
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        copy[key] = _copyAndHash(value);
      } else if (value is List<dynamic>) {
        copy[key] = _copyListAndHash(value);
      } else if (_isBasicType(value)) {
        copy[key] = value;
      } else {
        throw Exception('Unsupported type: ${value.runtimeType}');
      }
      if (key != '_hash') {
        keys.add(key);
      }
    });

    // Sort the object keys to ensure consistent key order
    keys.sort((a, b) => a.compareTo(b));

    // Build the JSON bytes representing the current object for hashing.
    // The bytes match the UTF-8 encoded JSON string of the object exactly.
    _jsonBytesLength = 0;
    _writeCharCode(_charBraceOpen);
    var isFirst = true;

    for (final key in keys) {
      if (!isFirst) {
        _writeCharCode(_charComma);
      }
      isFirst = false;

      _writeCharCode(_charQuote);
      _writeUtf8(key);
      _writeCharCode(_charQuote);
      _writeCharCode(_charColon);

      final value = copy[key];
      if (value is Map<String, dynamic>) {
        _writeQuotedUtf8(value['_hash'] as String);
      } else if (value is List<dynamic>) {
        _writeFlattenedList(value);
      } else if (value is double) {
        _writeTruncated(value);
      } else if (value is String) {
        _writeQuotedUtf8(value);
      } else {
        // value is int || value is bool
        _writeUtf8(value.toString());
      }
    }
    _writeCharCode(_charBraceClose);

    // Compute the SHA-256 hash of the JSON bytes
    _sha256(_jsonBytes, _jsonBytesLength);
    final hash = _base64Prefix(hashLength);

    // Add the hash to the copied object
    copy['_hash'] = hash;
    return copy;
  }

  // ...........................................................................
  /// Recursively copies a list and adds hashes to objects within the copy.
  List<dynamic> _copyListAndHash(List<dynamic> list) {
    final copy = <dynamic>[];
    for (final element in list) {
      if (element is Map<String, dynamic>) {
        copy.add(_copyAndHash(element));
      } else if (element is List<dynamic>) {
        copy.add(_copyListAndHash(element));
      } else if (_isBasicType(element)) {
        copy.add(element);
      } else {
        throw Exception('Unsupported type: ${element.runtimeType}');
      }
    }
    return copy;
  }

  // ...........................................................................
  /// Writes a double truncated to the floating point precision to the
  /// hash buffer. Behaves exactly like writing `_truncate(value, precision)`
  /// but avoids redundant string operations in the common cases.
  void _writeTruncated(double value) {
    final string = value.toString();
    final dotIndex = string.indexOf('.');

    if (dotIndex >= 0) {
      // The decimal part is already short enough: Write the string as is
      final decimals = string.length - dotIndex - 1;
      if (decimals <= floatingPointPrecision) {
        _writeUtf8(string);
        return;
      }

      // Truncate the decimal part and write the reparsed value
      if (floatingPointPrecision > 0) {
        final truncated = string.substring(
          0,
          dotIndex + 1 + floatingPointPrecision,
        );
        _writeUtf8(double.parse(truncated).toString());
        return;
      }
    }

    // Let _truncate handle the remaining edge cases
    _writeUtf8(_truncate(value, floatingPointPrecision).toString());
  }

  // ...........................................................................
  /// Writes a representation of a list for hashing to the hash buffer.
  void _writeFlattenedList(List<dynamic> list) {
    _writeCharCode(_charBracketOpen);
    var isFirst = true;

    for (final element in list) {
      if (element is Map<String, dynamic>) {
        if (!isFirst) {
          _writeCharCode(_charComma);
        }
        isFirst = false;
        _writeQuotedUtf8(element['_hash'] as String);
      } else if (element is List<dynamic>) {
        if (!isFirst) {
          _writeCharCode(_charComma);
        }
        isFirst = false;
        _writeFlattenedList(element);
      } else if (_isBasicType(element)) {
        if (!isFirst) {
          _writeCharCode(_charComma);
        }
        isFirst = false;
        _writeQuotedUtf8(element.toString());
      }
    }

    _writeCharCode(_charBracketClose);
  }

  // ...........................................................................
  /// Copies the JSON object
  static Map<String, dynamic> _copyJson(Map<String, dynamic> json) {
    final copy = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        copy[key] = _copyJson(value);
      } else if (value is List<dynamic>) {
        copy[key] = _copyList(value);
      } else if (_isBasicType(value)) {
        copy[key] = value;
      } else {
        throw Exception('Unsupported type: ${value.runtimeType}');
      }
    }
    return copy;
  }

  // ...........................................................................
  /// Copies the list
  static List<dynamic> _copyList(List<dynamic> list) {
    final copy = <dynamic>[];
    for (final element in list) {
      if (element is Map<String, dynamic>) {
        copy.add(_copyJson(element));
      } else if (element is List<dynamic>) {
        copy.add(_copyList(element));
      } else if (_isBasicType(element)) {
        copy.add(element);
      } else {
        throw Exception('Unsupported type: ${element.runtimeType}');
      }
    }
    return copy;
  }

  // ...........................................................................
  static bool _isBasicType(dynamic value) {
    return value is String || value is int || value is double || value is bool;
  }

  // ...........................................................................
  /// Turns a double into a string with a given precision.
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

    result = '$integerPart.$truncatedCommaParts';
    return double.parse(result);
  }

  // ...........................................................................
  static String _jsonString(Map<String, dynamic> map) {
    String encodeValue(dynamic value) {
      if (value is String) {
        return '"${value.replaceAll('"', '\\"')}"'; // Escape Anführungszeichen
      } else if (value is num || value is bool) {
        return value.toString();
      } else if (value == null) {
        return 'null';
      } else if (value is List) {
        return '[${value.map((e) => encodeValue(e)).join(",")}]';
      } else if (value is Map<String, dynamic>) {
        return _jsonString(value);
      } else {
        throw Exception('Unsupported type: ${value.runtimeType}');
      }
    }

    return '{${map.entries.map((e) => '"${e.key}"'
        ':${encodeValue(e.value)}').join(",")}}';
  }

  // ...........................................................................
  /// For test purposes we are exposing these private methods.
  ///
  /// Note: _copyJson, _copyList and _jsonString are not used for hashing
  /// anymore. They are kept as the readable specification of the hashed
  /// JSON format which the optimized byte writer must match exactly.
  static Map<String, dynamic> get privateMethods => {
    '_copyJson': _copyJson,
    '_copyList': _copyList,
    '_isBasicType': _isBasicType,
    '_truncate': _truncate,
    '_jsonString': _jsonString,
  };
}

// #############################################################################
// JSON byte writer
//
// Writes the JSON strings to be hashed directly as UTF-8 bytes into a
// reusable buffer. This avoids materializing intermediate strings and
// produces exactly the same bytes as `utf8.encode` of the JSON string.
// #############################################################################

// .............................................................................
/// ASCII char codes of the JSON structure characters
const int _charQuote = 0x22; // "
const int _charComma = 0x2c; // ,
const int _charColon = 0x3a; // :
const int _charBracketOpen = 0x5b; // [
const int _charBracketClose = 0x5d; // ]
const int _charBraceOpen = 0x7b; // {
const int _charBraceClose = 0x7d; // }

// .............................................................................
/// The reusable buffer holding the JSON bytes of the object to be hashed.
///
/// Invariant: the bytes of an object are only written after all of its
/// children have been hashed completely. No `_copyAndHash` call must
/// happen while the bytes of another object are being written, as it
/// would reset the buffer.
Uint8List _jsonBytes = Uint8List(1024);

/// The number of bytes currently written to `_jsonBytes`
int _jsonBytesLength = 0;

// .............................................................................
/// Ensures that `_jsonBytes` can take the additional number of bytes
void _ensureJsonBytesCapacity(int additionalBytes) {
  final requiredLength = _jsonBytesLength + additionalBytes;
  if (requiredLength <= _jsonBytes.length) {
    return;
  }
  var newLength = _jsonBytes.length * 2;
  while (newLength < requiredLength) {
    newLength *= 2;
  }
  final newBytes = Uint8List(newLength);
  newBytes.setRange(0, _jsonBytesLength, _jsonBytes);
  _jsonBytes = newBytes;
}

// .............................................................................
/// Writes a single ASCII character to `_jsonBytes`
void _writeCharCode(int charCode) {
  _ensureJsonBytesCapacity(1);
  _jsonBytes[_jsonBytesLength++] = charCode;
}

// .............................................................................
/// Appends already encoded UTF-8 bytes to `_jsonBytes`
void _writeBytes(Uint8List bytes) {
  final length = bytes.length;
  _ensureJsonBytesCapacity(length);
  _jsonBytes.setRange(_jsonBytesLength, _jsonBytesLength + length, bytes);
  _jsonBytesLength += length;
}

// .............................................................................
/// Writes a string as UTF-8 bytes to `_jsonBytes`
void _writeUtf8(String string) {
  final length = string.length;
  _ensureJsonBytesCapacity(length);

  // Write ASCII characters directly
  final bytes = _jsonBytes;
  var pos = _jsonBytesLength;
  for (var i = 0; i < length; i++) {
    final charCode = string.codeUnitAt(i);
    if (charCode >= 0x80) {
      // Encode the non ASCII rest of the string using utf8.encode
      _jsonBytesLength = pos;
      _writeBytes(utf8.encode(string.substring(i)));
      return;
    }
    bytes[pos++] = charCode;
  }
  _jsonBytesLength = pos;
}

// .............................................................................
/// Writes a string value in quotes with escaped quotes to `_jsonBytes`
void _writeQuotedUtf8(String string) {
  final length = string.length;
  _ensureJsonBytesCapacity(length + 2);

  // Write ASCII characters directly
  final bytes = _jsonBytes;
  var pos = _jsonBytesLength;
  bytes[pos++] = _charQuote;
  for (var i = 0; i < length; i++) {
    final charCode = string.codeUnitAt(i);
    if (charCode >= 0x80 || charCode == _charQuote) {
      // Escape quotes and encode the non ASCII rest of the string
      // using utf8.encode
      _jsonBytesLength = pos;
      _writeBytes(utf8.encode(string.substring(i).replaceAll('"', '\\"')));
      _writeCharCode(_charQuote);
      return;
    }
    bytes[pos++] = charCode;
  }
  _jsonBytesLength = pos;
  _writeCharCode(_charQuote);
}

// #############################################################################
// SHA-256 and base64
//
// An allocation free SHA-256 and base64 implementation reusing static buffers
// to avoid the per-call allocations of package based implementations.
// #############################################################################

// .............................................................................
/// The SHA-256 round constants
final Uint32List _sha256K = Uint32List.fromList([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

// .............................................................................
/// The base64 alphabet as code units
final Uint8List _base64Alphabet = Uint8List.fromList(
  'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.codeUnits,
);

// .............................................................................
/// Reusable buffers for `_sha256` and `_base64Prefix`
final Uint32List _sha256State = Uint32List(8);
final Uint32List _sha256W = Uint32List(64);
final Uint8List _sha256Padding = Uint8List(128);
final ByteData _sha256PaddingData = ByteData.sublistView(_sha256Padding);
final Uint8List _sha256Digest = Uint8List(32);
final ByteData _sha256DigestData = ByteData.sublistView(_sha256Digest);
final Uint8List _base64Chars = Uint8List(44);

// .............................................................................
/// Calculates the SHA-256 digest of the first `length` bytes of the
/// message into `_sha256Digest`
void _sha256(Uint8List message, int length) {
  // Initialize the hash state
  final state = _sha256State;
  state[0] = 0x6a09e667;
  state[1] = 0xbb67ae85;
  state[2] = 0x3c6ef372;
  state[3] = 0xa54ff53a;
  state[4] = 0x510e527f;
  state[5] = 0x9b05688c;
  state[6] = 0x1f83d9ab;
  state[7] = 0x5be0cd19;

  // Process all complete 64 byte blocks of the message
  final tailStart = length & ~63;
  if (tailStart > 0) {
    final messageData = ByteData.sublistView(message);
    for (var offset = 0; offset < tailStart; offset += 64) {
      _sha256Block(messageData, offset);
    }
  }

  // Copy the remaining bytes into the padding buffer and add the
  // SHA-256 padding: a 0x80 byte, zeros and the message bit length
  final padding = _sha256Padding;
  final tailLength = length - tailStart;
  final paddedLength = tailLength >= 56 ? 128 : 64;
  padding.setRange(0, tailLength, message, tailStart);
  padding.fillRange(tailLength, paddedLength, 0);
  padding[tailLength] = 0x80;

  // The bit length is written as two 32 bit words using arithmetic
  // operations, keeping the code exact on the web where 64 bit
  // integer operations are not available.
  final bitLength = length * 8;
  _sha256PaddingData.setUint32(paddedLength - 8, bitLength ~/ 0x100000000);
  _sha256PaddingData.setUint32(paddedLength - 4, bitLength % 0x100000000);

  // Process the padded blocks
  _sha256Block(_sha256PaddingData, 0);
  if (paddedLength == 128) {
    _sha256Block(_sha256PaddingData, 64);
  }

  // Write the state into the digest buffer as big endian bytes
  final digest = _sha256DigestData;
  for (var i = 0; i < 8; i++) {
    digest.setUint32(i << 2, state[i]);
  }
}

// .............................................................................
/// Processes a single 64 byte block updating `_sha256State`
void _sha256Block(ByteData data, int offset) {
  // Read the block as 16 big endian 32 bit words
  final w = _sha256W;
  for (var t = 0; t < 16; t++) {
    w[t] = data.getUint32(offset + (t << 2));
  }

  // Extend the words to the full message schedule. Bits above bit 32 are
  // truncated by the Uint32List when storing.
  for (var t = 16; t < 64; t++) {
    final w15 = w[t - 15];
    final w2 = w[t - 2];
    final s0 =
        ((w15 >>> 7) | (w15 << 25)) ^
        ((w15 >>> 18) | (w15 << 14)) ^
        (w15 >>> 3);
    final s1 =
        ((w2 >>> 17) | (w2 << 15)) ^ ((w2 >>> 19) | (w2 << 13)) ^ (w2 >>> 10);
    w[t] = w[t - 16] + s0 + w[t - 7] + s1;
  }

  // Run the 64 rounds of the compression function
  final state = _sha256State;
  final k = _sha256K;
  var a = state[0];
  var b = state[1];
  var c = state[2];
  var d = state[3];
  var e = state[4];
  var f = state[5];
  var g = state[6];
  var h = state[7];

  for (var t = 0; t < 64; t++) {
    final s1 =
        ((e >>> 6) | (e << 26)) ^
        ((e >>> 11) | (e << 21)) ^
        ((e >>> 25) | (e << 7));
    final ch = (e & f) ^ (~e & g);
    final temp1 = h + s1 + ch + k[t] + w[t];
    final s0 =
        ((a >>> 2) | (a << 30)) ^
        ((a >>> 13) | (a << 19)) ^
        ((a >>> 22) | (a << 10));
    final maj = (a & b) ^ (a & c) ^ (b & c);
    final temp2 = s0 + maj;
    h = g;
    g = f;
    f = e;
    e = (d + temp1) & 0xffffffff;
    d = c;
    c = b;
    b = a;
    a = (temp1 + temp2) & 0xffffffff;
  }

  // Add the compressed block to the state
  state[0] += a;
  state[1] += b;
  state[2] += c;
  state[3] += d;
  state[4] += e;
  state[5] += f;
  state[6] += g;
  state[7] += h;
}

// .............................................................................
/// Base64 encodes `_sha256Digest` and returns the first `length` characters
String _base64Prefix(int length) {
  // A base64 encoded SHA-256 digest has 44 characters
  if (length > 44) {
    throw RangeError.range(length, 0, 44, 'hashLength');
  }

  final digest = _sha256Digest;
  final alphabet = _base64Alphabet;
  final chars = _base64Chars;

  // Encode only as many of the ten complete three byte groups into
  // four characters each as are needed for the requested length
  final groupEnd = length >= 40 ? 30 : ((length + 3) >> 2) * 3;
  var ci = 0;
  for (var i = 0; i < groupEnd; i += 3) {
    final n = (digest[i] << 16) | (digest[i + 1] << 8) | digest[i + 2];
    chars[ci] = alphabet[(n >>> 18) & 63];
    chars[ci + 1] = alphabet[(n >>> 12) & 63];
    chars[ci + 2] = alphabet[(n >>> 6) & 63];
    chars[ci + 3] = alphabet[n & 63];
    ci += 4;
  }

  // Encode the two remaining bytes into three characters and a padding "="
  if (length > 40) {
    final n = (digest[30] << 8) | digest[31];
    chars[40] = alphabet[(n >>> 10) & 63];
    chars[41] = alphabet[(n >>> 4) & 63];
    chars[42] = alphabet[(n << 2) & 63];
    chars[43] = 0x3d; // '='
  }

  return String.fromCharCodes(chars, 0, length);
}

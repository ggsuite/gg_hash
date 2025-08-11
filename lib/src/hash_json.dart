// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// ...........................................................................
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

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
    final copy = _copyJson(json);
    _addHashesToObject(copy);
    return copy;
  }

  /// Calculates a SHA-256 hash of a string
  String calcHash(String string) {
    final digest = sha256.convert(utf8.encode(string));
    return base64Encode(digest.bytes).substring(0, hashLength);
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  /// Recursively adds hashes to a nested object.
  void _addHashesToObject(Map<String, dynamic> obj) {
    // Recursively process child elements
    obj.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        _addHashesToObject(value);
      } else if (value is List<dynamic>) {
        _processList(value);
      }
    });

    // Build a new object to represent the current object for hashing
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
      } else if (_isBasicType(value)) {
        objToHash[key] = value;
      } else {
        // coverage:ignore-start
        throw Exception('Unsupported type: ${value.runtimeType}');
        // coverage:ignore-end
      }
    }

    // Sort the object keys to ensure consistent key order
    final sortedMap = SplayTreeMap<String, dynamic>.from(objToHash);
    final sortedMapJson = _jsonString(sortedMap);

    // Compute the SHA-256 hash of the JSON string
    var hash = calcHash(sortedMapJson);

    // Add the hash to the original object
    obj['_hash'] = hash;
  }

  // ...........................................................................
  /// Builds a representation of a list for hashing.
  List<dynamic> _flattenList(List<dynamic> list) {
    var flattenedList = <dynamic>[];

    for (final element in list) {
      if (element is Map<String, dynamic>) {
        flattenedList.add(element['_hash'] as String);
      } else if (element is List<dynamic>) {
        flattenedList.add(_flattenList(element));
      } else if (_isBasicType(element)) {
        flattenedList.add(element.toString());
      }
    }

    return flattenedList;
  }

  // ...........................................................................
  /// Recursively processes a list, adding hashes to nested objects and lists.
  void _processList(List<dynamic> list) {
    for (final element in list) {
      if (element is Map<String, dynamic>) {
        _addHashesToObject(element);
      } else if (element is List<dynamic>) {
        _processList(element);
      }
    }
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
  /// For test purposes we are exposing these private methods
  static Map<String, dynamic> get privateMethods => {
    '_copyJson': _copyJson,
    '_copyList': _copyList,
    '_isBasicType': _isBasicType,
    '_truncate': _truncate,
    '_jsonString': _jsonString,
  };
}

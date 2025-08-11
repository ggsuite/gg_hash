// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:typed_data';

// .............................................................................
/// Calculates an fnv1 hash on an list
int fnv1(Iterable<dynamic> data, [int start = 0, int? end]) {
  const int prime = 16777619;
  int hash = 2166136261; // FNV offset basis

  // Write buffer length into hashcode
  hash ^= ((end ?? data.length) - start).hashCode;

  end ??= data.length;

  // ..................................................
  // If data is typed data, convert it to 64 bit chunks
  if (data is TypedData) {
    // Turn data to typed data
    final typedData = Int8List.sublistView(data as TypedData, start, end);

    // Estimate byte length
    final byteCount = typedData.lengthInBytes;

    // Is byte count devidable by 8?
    final isDevidableBy8 = byteCount % 8 == 0;

    // .............................................
    // If not devidable by 8, increase buffer length
    if (!isDevidableBy8) {
      // Create a new buffer with a length devidable by 8
      final requiredByteCount = byteCount % 8 > 0
          ? (byteCount ~/ 8 + 1) * 8
          : byteCount;
      final dataNew = Uint8List(requiredByteCount);

      // Copy data over to new buffer
      dataNew.setRange(0, byteCount, typedData);
      start = 0;
      end = requiredByteCount;

      // Use the new buffer for calculation
      data = dataNew;
    }

    // ............................
    // Turn data into an int64 list
    data = Int64List.sublistView(data as TypedData, start, end);
    start = 0;
    end = data.length;
  }

  // Calculate hashcode
  for (int i = start; i < end; i++) {
    final val = data.elementAt(i);
    hash = hash * prime; // Multiply the current hash with the prime
    hash =
        hash ^
        ((val is Enum)
            ? val.name.hashCode
            : val is int
            ? val
            : val.hashCode); // XOR with the current data
  }

  return hash;
}

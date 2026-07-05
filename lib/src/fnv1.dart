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

  end ??= data.length;

  // Write buffer length into hashcode
  hash ^= (end - start).hashCode;

  // ..................................................
  // If data is typed data, convert it to 64 bit chunks
  if (data is TypedData) {
    // Turn data to typed data
    final typedData = Int8List.sublistView(data as TypedData, start, end);

    // Estimate byte length
    final byteCount = typedData.lengthInBytes;

    // Number of bytes not filling a complete 64 bit chunk
    final remainingBytes = byteCount & 7;

    // ...................................................
    // If devidable by 8, hash the 64 bit chunks directly
    if (remainingBytes == 0) {
      final chunks = Int64List.sublistView(data as TypedData, start, end);
      for (int i = 0; i < chunks.length; i++) {
        hash = hash * prime; // Multiply the current hash with the prime
        hash = hash ^ chunks[i]; // XOR with the current data
      }
      return hash;
    }

    // ..........................................................
    // If not devidable by 8, hash the complete 64 bit chunks and
    // treat the remaining bytes as a zero padded last chunk.
    if (typedData.offsetInBytes & 7 == 0) {
      // Hash the complete chunks
      final completeByteCount = byteCount - remainingBytes;
      final chunks = Int64List.sublistView(typedData, 0, completeByteCount);
      for (int i = 0; i < chunks.length; i++) {
        hash = hash * prime; // Multiply the current hash with the prime
        hash = hash ^ chunks[i]; // XOR with the current data
      }

      // Hash the remaining bytes as a zero padded 64 bit chunk
      final lastChunkBytes = Uint8List(8);
      lastChunkBytes.setRange(0, remainingBytes, typedData, completeByteCount);
      hash = hash * prime;
      hash = hash ^ Int64List.sublistView(lastChunkBytes)[0];
      return hash;
    }

    // ...............................................................
    // Otherwise copy the data into a buffer with a length devidable
    // by 8 and hash the 64 bit chunks of the copy.
    final requiredByteCount = (byteCount ~/ 8 + 1) * 8;
    final dataNew = Uint8List(requiredByteCount);
    dataNew.setRange(0, byteCount, typedData);

    final chunks = Int64List.sublistView(dataNew);
    for (int i = 0; i < chunks.length; i++) {
      hash = hash * prime; // Multiply the current hash with the prime
      hash = hash ^ chunks[i]; // XOR with the current data
    }
    return hash;
  }

  // .....................................................
  // Hash lists of ints and strings with specialized loops
  if (data is List<int>) {
    for (int i = start; i < end; i++) {
      hash = hash * prime; // Multiply the current hash with the prime
      hash = hash ^ data[i]; // XOR with the current data
    }
    return hash;
  }

  if (data is List<String>) {
    for (int i = start; i < end; i++) {
      hash = hash * prime; // Multiply the current hash with the prime
      hash = hash ^ data[i].hashCode; // XOR with the current data
    }
    return hash;
  }

  if (data is List) {
    for (int i = start; i < end; i++) {
      final val = data[i];
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

  // ..................................
  // Hash lazy iterables of ints
  if (data is Iterable<int>) {
    for (int i = start; i < end; i++) {
      hash = hash * prime; // Multiply the current hash with the prime
      hash = hash ^ data.elementAt(i); // XOR with the current data
    }
    return hash;
  }

  // ..................................
  // Hash all other iterables
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

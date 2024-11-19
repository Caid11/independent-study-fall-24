/*-----------------------------------------------------------------------------
  Utility functions for maps.
-----------------------------------------------------------------------------*/

module lib/map/utils

import std/num/int32

// Index and bit calculation utilities. Based on code in "Optimizing Hash-Array
// Mapped Tries for Fast and Lean Immutable JVM Collections", listing 2.

pub fun calc-bit-pos(hash : int32, shift-width : int) : int32
  // We store up to 32 children at a time, and need 5 bits to select the child at each level.
  val idx-msk = 31.i32 
  val bit-idx = hash.shr(shift-width).and(idx-msk).int
  val res = (1.int32).shl(bit-idx)
  res

pub fun calc-idx(bitmap : int32, bitpos : int32) : int
  // NOTE (because I got confused about this): bitpos is a bitvector with a
  // single bit set to indicate the position. This means that it will never be
  // 0, so we don't need to worry about subtracting from 0 and wrapping.
  val msk = (bitpos - 1.int32)
  val res = popcount( bitmap.and( msk ))
  res

pub fun show-bin(bitmap : int32) : string
  list(0,31).map(fn(i)
    if 1.int32.shl(i).and(bitmap) != 0.int32 then "1"
    else "0"
  ).reverse().join()

// List utility functions

pub fun list/insert(l : list<a>, x : a, idx : int) : list<a>
  l.take(idx) ++ [x] ++ l.drop(idx)

pub fun list/set(l : list<a>, x : a, idx : int) : list<a>
  l.take(idx) ++ [x] ++ l.drop(idx + 1)

pub fun list/delete(l : list<a>, idx : int) : list<a>
  l.take(idx) ++ l.drop(idx + 1)

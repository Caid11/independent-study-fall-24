/*-----------------------------------------------------------------------------
  Misc utilities
-----------------------------------------------------------------------------*/

module lib/util/misc

import std/num/int32

import std/core/undiv

extern import
  c file "misc-inline.c"

pub extern get-curr-mem-usage() : io int
  c "kk_getCurrMemUsage"

pub extern get-peak-mem-usage() : io int
  c "kk_getPeakMemUsage"

struct xorshiftState
  a : int32

fun step( s : xorshiftState ) : xorshiftState
  val x1 = s.a.or( s.a.shl( 13 ) )
  val x2 = x1.or( x1.shr( 17 ) )
  val x3 = x2.or( x2.shl( 5 ) )
  XorshiftState( x3 )

fun insert-s(l: list<(a,int)>, (x,t) : (a,int)) : list<(a,int)>
  val insert-idx = l.index-of(fn((_,ty)) { ty >= t })
  if insert-idx < 0 then
    l ++ [(x,t)]
  else
    l.take(insert-idx) ++ [(x,t)] ++ l.drop(insert-idx)

pub fun sort(l: list<(a,int)>, sorted : list<(a,int)> = []): list<(a,int)>
  match l
    Nil -> sorted
    Cons(head, tail) -> sort(tail, sorted.insert-s(head))

// Shuffle the given list of numbers.
pub fun shuffle(l: list<a>, seed : int) : _e list<a>
  var rnd-state := XorshiftState( seed.int32 )

  l.map(fn(n) 
    rnd-state := rnd-state.step()
    (n, rnd-state.a.int)
  )
    .sort()
    .map(fn((x,_)) x)

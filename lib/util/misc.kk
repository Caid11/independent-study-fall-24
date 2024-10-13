/*-----------------------------------------------------------------------------
  Misc utilities
-----------------------------------------------------------------------------*/

module lib/util/misc

import lib/util/sort

import std/num/int32
import std/num/random

extern import
  c file "misc-inline.c"

pub extern get-curr-mem-usage() : io int
  c "kk_getCurrMemUsage"

pub extern get-peak-mem-usage() : io int
  c "kk_getPeakMemUsage"

// Generate a shuffled list of numbers from 0 to input size - 1
pub fun shuffle(l: list<a>, seed : int) : _e list<a>
  var rnd-state := sfc-init(seed)

  l.map(fn(n) 
    val rnd-step = rnd-state.sfc-step()
    rnd-state := rnd-step.rstate()
    val arg = rnd-step.rnd()
    (n, arg)
  )
    .sort(?cmp=fn((_,x : int32), (_,y : int32)) int32/cmp(x, y))
    .map(fn((x,_)) x)

/*-----------------------------------------------------------------------------
  Memory footprint benchmarks.

  This is a separate executable so we can invoke it as a separate process and
  use GetProcessMemoryInfo (PeakWorkingSetSize) to get the approximate
  footprint of data structures.
-----------------------------------------------------------------------------*/

module bench-mem

import lib/map/map
import lib/util/misc
import lib/util/sort

import std/os/env

//==============================================================================
// Argument parsing

type implementation
  ArrayBacked
  HamtBacked
  ChampBacked

struct args
  implementation : implementation
  seed : int
  num-inputs : int

effect parseError
  ctl show-help() : a

fun print-usage()
  println("Usage: bench-mem [implementation] [seed] [num inputs]")
  println("Options: [implementation]  Map implementation to use. Can be one of: ArrayBacked, HAMT, CHAMP")
  println("         [seed]            Random number seed to use when generating inputs.")
  println("         [num inputs]      Number of inputs to insert into the data structure")

fun parse-args()
  val args = get-args()
  if args.length() != 3 then
    show-help()
  else
    val implementation = match args[0]
      Just(s) -> match s
        "ArrayBacked" -> ArrayBacked
        "HAMT" -> HamtBacked
        "CHAMP" -> ChampBacked
        _ -> show-help()
      _ -> show-help()

    val seed = match args[1]
      Just(s) -> match s.parse-int()
        Nothing -> show-help()
        Just(x) -> x
      _ -> show-help()

    val num-inputs = match args[2]
      Just(s) -> match s.parse-int()
        Nothing -> show-help()
        Just(x) -> x
      _ -> show-help()

    Args(implementation, seed, num-inputs)

// End argument parsing
//==============================================================================

fun hashInt(x: int) : int
  x

fun keyCmpInt(x : int, y : int) : bool
  x == y

// Generate a shuffled list of numbers from 0 to input size - 1
fun get-bench-inputs(input-size : int, seed : int) : _e list<int>
  list(0, input-size).shuffle(seed)

fun main()
  with handler
    final ctl show-help() print-usage()

  val args = parse-args()

  val inputs = list(0, args.num-inputs - 1).shuffle(args.seed)

  val mi = match args.implementation
    ArrayBacked -> create-array-backed(hashInt, keyCmpInt, args.num-inputs, False)
    HamtBacked -> create-hamt-backed(hashInt, keyCmpInt)
    ChampBacked -> create-champ-backed(hashInt, keyCmpInt)

  inputs.foldl(mi, fn(m, x) m.insert(x, x))

  println(get-peak-mem-usage())

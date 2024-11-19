/*-----------------------------------------------------------------------------
  Performance benchmarks for map implementations
-----------------------------------------------------------------------------*/

module bench

import lib/map/arrayBacked
import lib/map/hamtBacked
import lib/map/map
import lib/util/bench
import lib/util/misc

import std/num/random
import std/num/ddouble
import std/os/env
import std/os/process
import std/text/regex
import std/time/duration
import std/time/timer

type implementation
  ArrayBacked
  HamtBacked
  ChampBacked

fun string(x : implementation)
  match x
    ArrayBacked -> "ArrayBacked"
    HamtBacked -> "HAMT"
    ChampBacked -> "CHAMP"

fun hashInt(x: int) : int
  x

fun keyCmpInt(x : int, y : int) : bool
  x == y

// Argument parsing
//==============================================================================

type runMode
  Fast
  Full

struct args
  mode : runMode

effect parseError
  ctl show-help() : a

fun print-usage()
  println("Usage: bench [mode]")

fun parse-args()
  val args = get-args()
  if args.length() != 1 then
    show-help()
  else
    val run-mode = match args[0]
      Just(s) -> match s
        "fast" -> Fast
        "full" -> Full
        _ -> show-help()
      _ -> show-help()

    Args(run-mode)

// Table printing
//==============================================================================

struct table
  col-widths : list<int>

fun get-print-tbl(implementations : list<implementation>)
  val columns = list(1,implementations.length).map(fn(_) 13)
  Table([10] ++ columns)

fun fmt-col(msg : string, column-width : int)
  val num-pad-chars = column-width - msg.count
  val pad-chars = list(1, num-pad-chars).map(fn(_) ' ').string
  msg ++ pad-chars ++ "| "

fun print(tbl : table, vals : list<string>)
  if tbl.col-widths.length != vals.length then
    throw("Bad number of values")
  else
    val msg = vals.zip(tbl.col-widths).map(fn((v,w)) fmt-col(v,w)).join()
    println(msg)

// Memory footprint measurements (also see mem-bench.kk)
//==============================================================================

// Ensure mem-bench.kk is built and return its path.
fun build-mem-bench()
  // Ensure memory bench exe is built and get path.
  val build-output = match run-system-read("koka -O2 bench-mem.kk")
    Ok(res) -> res
    Error(err) -> throw(err.message)

  val rx-exe-path = regex(r"^created : (\S+)", multiline=True)
  val m = match build-output.find(rx-exe-path)
    Nothing -> throw("unable to parse mem-bench build output")
    Just(c) -> c

  m.replace-all("created : ", "")

fun measure-mem-footprint(exe-path : string, impl : string, seed : int, size : int) : io int
  val cmd = exe-path ++ " " ++ impl ++ " " ++ seed.show ++ " " ++ size.show
  val cmd-output = match run-system-read(cmd)
    Ok(o) -> o
    Error(e) -> throw(e.message())

  match cmd-output.replace-all("\n", "").parse-int
    Nothing -> throw("unable to parse bench-mem output: [" ++ cmd-output ++ "]")
    Just(i) -> i

fun measure-mem-footprints(implementations : list<implementation>,
                           input-sizes : list<int>,
                           seeds : list<int>)
  val exe-path = build-mem-bench()

  println("Memory footprint (bytes)")

  val impls = implementations.map(fn(i) i.string)

  val mem-tbl = get-print-tbl(implementations)
  mem-tbl.print(["Num items"] ++ impls)

  input-sizes.map(fn(size)
    val to-print = impls.map(fn(impl)
      var footprint-sum := 0
      seeds.map(fn(seed)
        val footprint = measure-mem-footprint(exe-path, impl, seed, size)
        footprint-sum := footprint-sum + footprint
      )

      (footprint-sum / seeds.length).show
    )

    mem-tbl.print([size.show] ++ to-print)
  )

  ()

// Operation runtime benchmarking
//==============================================================================

struct implInput
  ty : implementation
  ins : list<(list<int>,map<int,int>)>

struct testInput
  size : int
  impls : list<implInput>

fun benchmark-implementations(implementations : list<implementation>,
                              input-sizes : list<int>,
                              seeds : list<int>)
  val num-to-test = 8

  println("Generating inputs...")

  val inputs = input-sizes.map(fn(size)
    TestInput(size,
      implementations.map(fn(impl)
        ImplInput(impl,
          seeds.map(fn(seed)
            val input-vals = list(1,size).shuffle(seed)

            val m = match impl
              ArrayBacked -> input-vals.foldl(create-array-backed(hashInt, keyCmpInt),
                                             fn(m, x) m.insert(x,x))
              HamtBacked -> input-vals.foldl(create-hamt-backed(hashInt, keyCmpInt),
                                             fn(m, x) m.insert(x,x))
              ChampBacked -> input-vals.foldl(create-champ-backed(hashInt, keyCmpInt),
                                             fn(m, x) m.insert(x,x))
            (input-vals, m)
           )
         )
       )
     )
   )

  println("")
  println("Benchmarking lookup...")

  val lookup-tbl = get-print-tbl(implementations)
  lookup-tbl.print(["Num items"] ++ implementations.map(string))

  inputs.map(fn(input)
    val impl-times = input.impls.map(fn(i)
      var time-sum := 0

      i.ins.map(fn((ins,m))
        val to-lookup = ins.take(num-to-test)

        val begin = ticks().nano-seconds()
        val res = to-lookup.map(fn(v) m.lookup(v))
        val elapsed = ticks().nano-seconds - begin

        time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    lookup-tbl.print([input.size.show] ++ impl-times)
  )


  println("")

  println("Benchmarking insert...")

  val insert-tbl = get-print-tbl(implementations)
  insert-tbl.print(["Num items"] ++ implementations.map(string))

  inputs.map(fn(input)
    val impl-times = input.impls.map(fn(i)
      var time-sum := 0

      i.ins.map(fn((_,m))
        val to-insert = list(input.size, input.size + num-to-test)

        val begin = ticks().nano-seconds()
        val res = to-insert.map(fn(v) m.insert(v,v))
        val elapsed = ticks().nano-seconds - begin

        time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    lookup-tbl.print([input.size.show] ++ impl-times)
  )

  println("")

  println("Benchmarking delete...")

  val delete-tbl = get-print-tbl(implementations)
  delete-tbl.print(["Num items"] ++ implementations.map(string))

  inputs.map(fn(input)
    val impl-times = input.impls.map(fn(i)
      var time-sum := 0

      i.ins.map(fn((ins,m))
        val to-delete = ins.take(num-to-test)

        val begin = ticks().nano-seconds()
        val res = to-delete.map(fn(v) m.delete(v))
        val elapsed = ticks().nano-seconds - begin

        time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    delete-tbl.print([input.size.show] ++ impl-times)
  )

  println("")

  println("Benchmarking lookup (fail)...")

  val lookup-fail-tbl = get-print-tbl(implementations)
  lookup-fail-tbl.print(["Num items"] ++ implementations.map(string))

  inputs.map(fn(input)
    val impl-times = input.impls.map(fn(i)
      var time-sum := 0

      i.ins.map(fn((_,m))
        val to-lookup = list(input.size, input.size + num-to-test)

        val begin = ticks().nano-seconds()
        val res = to-lookup.map(fn(v) m.lookup(v))
        val elapsed = ticks().nano-seconds - begin

        time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    lookup-fail-tbl.print([input.size.show] ++ impl-times)
  )

  println("")

  println("Benchmarking update...")

  val update-tbl = get-print-tbl(implementations)
  update-tbl.print(["Num items"] ++ implementations.map(string))

  inputs.map(fn(input)
    val impl-times = input.impls.map(fn(i)
      var time-sum := 0

      i.ins.map(fn((ins,m))
        val to-update = ins.take(num-to-test)

        val begin = ticks().nano-seconds()
        val res = to-update.map(fn(v) m.insert(v,v))
        val elapsed = ticks().nano-seconds - begin

        time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    update-tbl.print([input.size.show] ++ impl-times)
  )

  println("")

  println("Benchmarking iteration (key + value)...")

  val map-tbl = get-print-tbl(implementations)
  map-tbl.print(["Num items"] ++ implementations.map(string))

  inputs.map(fn(input)
    val impl-times = input.impls.map(fn(i)
      var time-sum := 0

      i.ins.map(fn((_,m))
        val begin = ticks().nano-seconds()
        m.map-with-key(fn(_,v) v)
        val elapsed = ticks().nano-seconds - begin

        time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    map-tbl.print([input.size.show] ++ impl-times)
  )

  println("")

  println("Benchmarking equality...")

  val equal-tbl = get-print-tbl(implementations)
  equal-tbl.print(["Num items"] ++ implementations.map(string))

  inputs.map(fn(input)
    val impl-times = input.impls.map(fn(i)
      var time-sum := 0

      i.ins.map(fn((ins,m))
        val m1 = m
        val k-to-delete = ins[0].unjust
        val m2 = m1.delete(k-to-delete).insert(k-to-delete, k-to-delete)
        
        val begin = ticks().nano-seconds()
        m1.equals(m2, keyCmpInt)
        val elapsed = ticks().nano-seconds - begin

        time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    equal-tbl.print([input.size.show] ++ impl-times)
  )

  ()

fun main()
  with handler
    final ctl show-help() print-usage()

  val args = parse-args()

  val input-sizes = match args.mode
    Full -> list(0,6).map(fn(i) 10.pow(i))
    Fast -> [10.pow(6)]

  val implementations = match args.mode
    Full -> [ArrayBacked, HamtBacked, ChampBacked]
    Fast -> [HamtBacked, ChampBacked]

  val seeds = match args.mode
    Full -> list(0,4)
    Fast -> [0]

  val begin = ticks().nano-seconds()

  match args.mode
    Full ->
      measure-mem-footprints(implementations, input-sizes, seeds)
      println("")
    _ -> ()

  benchmark-implementations(implementations, input-sizes, seeds)

  val elapsed = ticks().nano-seconds - begin
  val minutes = (elapsed.ddouble / 1000000000.ddouble / 60.ddouble).show(3)
  println("")
  println("Total time: " ++ minutes ++ " minutes")

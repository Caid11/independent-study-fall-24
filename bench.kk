/*-----------------------------------------------------------------------------
  Performance benchmarks for map implementations
-----------------------------------------------------------------------------*/

module bench

import lib/map/arrayBacked
import lib/map/hamtBacked
import lib/util/bench
import lib/util/misc

import std/num/random
import std/num/ddouble
import std/os/process
import std/text/regex
import std/time/duration
import std/time/timer

type implementation
  ArrayBacked
  HAMT

fun string(x : implementation)
  match x
    ArrayBacked -> "ArrayBacked"
    HAMT -> "HAMT"

val input-sizes = list(0,5).map(fn(i) 10.pow(i))
val implementations = [ArrayBacked, HAMT]
val seeds = list(0,4)

fun hashInt(x: int) : int
  x

fun keyCmpInt(x : int, y : int) : bool
  x == y

// Table printing
//==============================================================================

struct table
  col-widths : list<int>

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
  val build-output = match run-system-read("koka bench-mem.kk")
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

fun measure-mem-footprints()
  val exe-path = build-mem-bench()

  println("Memory footprint (bytes)")

  val impls = implementations.map(fn(i) i.string)

  val mem-tbl = Table([10, 13, 8])
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

fun benchmark-implementations()
  val num-to-test = 8

  println("Benchmarking lookup...")

  val lookup-tbl = Table([10, 13, 8])
  lookup-tbl.print(["Num items"] ++ implementations.map(string))

  input-sizes.map(fn(size)
    val impl-times = implementations.map(fn(impl)
      var time-sum := 0

      seeds.map(fn(seed)
        val inputs = list(1,size)
        val to-lookup = inputs.shuffle(seed).take(num-to-test)

        match impl
          ArrayBacked ->
            val mi = create-map(hashInt, keyCmpInt, 0, 0, inputs.length)
            val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

            val begin = ticks().nano-seconds()

            val res = to-lookup.map(fn(v) m.lookup(v))

            val elapsed = ticks().nano-seconds - begin
            time-sum := time-sum + elapsed

          HAMT ->
            val mi = create-map(hashInt, keyCmpInt)
            val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

            val begin = ticks().nano-seconds()

            val res = to-lookup.map(fn(v) m.lookup(v))

            val elapsed = ticks().nano-seconds - begin
            time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    lookup-tbl.print([size.show] ++ impl-times)
  )
  println("")

  println("Benchmarking insert...")

  val insert-tbl = Table([10, 13, 8])
  insert-tbl.print(["Num items"] ++ implementations.map(string))

  input-sizes.map(fn(size)
    val impl-times = implementations.map(fn(impl)
      var time-sum := 0

      seeds.map(fn(seed)
        val inputs = list(1,size + num-to-test).shuffle(seed)
        val initial-vals = inputs.take(size)
        val to-insert = inputs.drop(size)

        match impl
          ArrayBacked ->
           val mi = create-map(hashInt, keyCmpInt, 0, 0, initial-vals.length)
           val m = initial-vals.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           to-insert.foldl(m, fn(mx,v) mx.insert(v,v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed

          HAMT ->
           val mi = create-map(hashInt, keyCmpInt)
           val m = initial-vals.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           to-insert.foldl(m, fn(mx,v) mx.insert(v,v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    insert-tbl.print([size.show] ++ impl-times)
  )
  println("")

  println("Benchmarking delete...")

  val delete-tbl = Table([10, 13, 8])
  delete-tbl.print(["Num items"] ++ implementations.map(string))

  input-sizes.map(fn(size)
    val impl-times = implementations.map(fn(impl)
      var time-sum := 0

      seeds.map(fn(seed)
        val inputs = list(1,size).shuffle(seed)
        val to-delete = inputs.shuffle(seed).take(num-to-test)

        match impl
          ArrayBacked ->
           val mi = create-map(hashInt, keyCmpInt, 0, 0, inputs.length)
           val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           val res = to-delete.map(fn(v) m.delete(v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed

          HAMT ->
           val mi = create-map(hashInt, keyCmpInt)
           val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           val res = to-delete.map(fn(v) m.delete(v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    delete-tbl.print([size.show] ++ impl-times)
  )
  println("")

  println("Benchmarking lookup (fail)...")

  val lookup-fail-tbl = Table([10, 13, 8])
  lookup-fail-tbl.print(["Num items"] ++ implementations.map(string))

  input-sizes.map(fn(size)
    val impl-times = implementations.map(fn(impl)
      var time-sum := 0

      seeds.map(fn(seed)
        val inputs = list(1,size + num-to-test).shuffle(seed)
        val initial-vals = inputs.take(size)
        val to-lookup-fail = inputs.drop(size)

        match impl
          ArrayBacked ->
           val mi = create-map(hashInt, keyCmpInt, 0, 0, inputs.length)
           val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           val res = to-lookup-fail.map(fn(v) m.lookup(v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed

          HAMT ->
           val mi = create-map(hashInt, keyCmpInt)
           val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           val res = to-lookup-fail.map(fn(v) m.lookup(v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    lookup-fail-tbl.print([size.show] ++ impl-times)
  )
  println("")

  println("Benchmarking update...")

  val update-tbl = Table([10, 13, 8])
  update-tbl.print(["Num items"] ++ implementations.map(string))

  input-sizes.map(fn(size)
    val impl-times = implementations.map(fn(impl)
      var time-sum := 0

      seeds.map(fn(seed)
        val inputs = list(1,size).shuffle(seed)
        val to-update = inputs.shuffle(seed).take(num-to-test)

        match impl
          ArrayBacked ->
           val mi = create-map(hashInt, keyCmpInt, 0, 0, inputs.length)
           val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           to-update.foldl(m, fn(mx,v) mx.insert(v,v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed

          HAMT ->
           val mi = create-map(hashInt, keyCmpInt)
           val m = inputs.foldl(mi, fn(m,v) m.insert(v,v))

           val begin = ticks().nano-seconds()

           to-update.foldl(m, fn(mx,v) mx.insert(v,v))

           val elapsed = ticks().nano-seconds - begin
           time-sum := time-sum + elapsed
      )

      (time-sum.ddouble / seeds.length.ddouble / 1000000.ddouble).show(3)
    )

    update-tbl.print([size.show] ++ impl-times)
  )

  ()

fun main()
  measure-mem-footprints()
  println("")
  benchmark-implementations()

  ()

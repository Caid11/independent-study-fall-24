/*-----------------------------------------------------------------------------
  Performance benchmarks for map implementations
-----------------------------------------------------------------------------*/

import lib/map/arrayBacked
import lib/util/bench
import std/num/random

fun hashInt(x: int) : int
  x

fun keyCmpInt(x : int, y : int) : bool
  x == y

fun get-bench-inputs(input-size : int) : _e list<int>
  list(0, input-size).map(fn(_) random-int())

fun main()
  println("Generating inputs...")
  val input-sizes = list(1, 5).map(fn(i) pow(10, i)).list/vector
  val bench-inputs = input-sizes.map(get-bench-inputs)

  fun bench-func(idx)
    val mi = create-map(hashInt, keyCmpInt, 0, 0, input-sizes[idx] * 2)
    bench-inputs[idx].foldl(mi, fn(m, i) m.insert(i, i))
    ()

  println("Benchmarking...")

  bench(bench-func, input-sizes, 0, 1)

  println("Finished!")

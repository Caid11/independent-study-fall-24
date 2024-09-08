/*-----------------------------------------------------------------------------
  Performance benchmarks for map implementations
-----------------------------------------------------------------------------*/

import lib/map/arrayBacked
import lib/map/hamtBacked
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
  val input-sizes = list(1, 4).map(fn(i) pow(10, i)).list/vector
  val bench-inputs = input-sizes.map(get-bench-inputs)

  fun bench-func-array-backed(idx)
    val mi = create-map(hashInt, keyCmpInt, 0, 0, input-sizes[idx] * 2)
    bench-inputs[idx].foldl(mi, fn(m, i) m.insert(i, i))
    ()

  println("Benchmarking array backed...")

  bench(bench-func-array-backed, input-sizes, 0, 1)

  fun bench-func-hamt-backed(idx : int)
    val mi = create-map(hashInt, keyCmpInt, 0)
    bench-inputs[idx].foldl(mi, fn(m, i) m.insert(i, i))
    ()

  println("Benchmarking hamt backed...")

  bench(bench-func-hamt-backed, input-sizes, 0, 1)

  println("Finished!")

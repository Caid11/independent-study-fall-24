/*-----------------------------------------------------------------------------
  Utilities for benchmarking
-----------------------------------------------------------------------------*/

module lib/util/bench

import std/time/duration
import std/time/timer

// Benchmark the target function and write a CSV file with the results.
//
// Parameters:
//   bench-func: Function to benchmark. Should take input from inputs-func
//   inputs-func: Provides number of inputs as a list. e.g. when given 10,000, provide 10,000 inputs.
//   num-inputs: list of numbers representing input steps
//   warmup-iterations: number of warmup iterations to perform
//   iterations: number of iterations to perform per input step
pub fun bench(bench-func : (int) -> _e (),
              input-sizes : vector<int>,
              num-warmup-iterations : int,
              num-iterations : int)
  list(0, input-sizes.length).map(fn(idx)
    // Warmup
    repeat(num-warmup-iterations, { bench-func(idx) })

    val begin = ticks().nano-seconds

    repeat(num-iterations, { bench-func(idx) })

    val elapsed-ns = ticks().nano-seconds - begin
    val elapsed-avg-ns = elapsed-ns / num-iterations
    val elapsed-ms = elapsed-avg-ns / 1000000
    println(input-sizes[idx].show ++ " " ++ elapsed-ms.show)
  )

  ()

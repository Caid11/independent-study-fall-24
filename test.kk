/*-----------------------------------------------------------------------------
  Correctness test for map implementations

  NOTE: For string hashing bringup, maybe try using hash function from
  \koka\lib\v1\std\text\atom.kk
-----------------------------------------------------------------------------*/

import lib/map/arrayBacked
import lib/util/test

import std/num/int64

fun hashFunc(x : int64) : int
  x.int

val tests = [
  Case(
    "array-backed",
    [
      Test(
        "array-insert-lookup",
        fn()
          val m = create-map( hashFunc ).insert( 1.int64, "hello" )
          match m.lookup( 1.int64 )
            Just("hello") -> ()
            _ -> test-fail( "bad value found" )
      )
    ]
  )
]

fun main()
  run-tests(tests)

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

fun keyCmp(x : int64, y : int64) : bool
  x == y

val tests = [
  Case(
    "array-backed",
    [
      Test(
        "array-insert-lookup",
        fn()
          val m = create-map( hashFunc, keyCmp, 0.int64, "" ).insert( 1.int64, "hello" )
          match m.lookup( 1.int64 )
            Just("hello") -> ()
            _ -> test-fail( "bad value found" )
      ),

      Test(
        "array-insert-lookup-force-resize",
        fn()
          val m = create-map( hashFunc, keyCmp, 0.int64, "", 0 ).insert( 1.int64, "hello" )
          match m.lookup( 1.int64 )
            Just("hello") -> ()
            _ -> test-fail( "bad value found" )
      ),

      Test(
        "array-insert-lookup-update",
        fn()
          val mi = create-map( hashFunc, keyCmp, 0.int64, "" )
          val m1 = mi.insert( 1.int64, "foo" )
          val m2 = m1.insert( 1.int64, "bar" )

          match m1.lookup( 1.int64 )
            Just(x) ->
              if x == "foo" then ()
              else test-fail( "bad value found m1: " ++ x)
            _ -> test-fail( "bad value found m1" )

          match m2.lookup( 1.int64 )
            Just("bar") -> ()
            Just(x) -> test-fail( "bad value found m2: " ++ x)
            _ -> test-fail( "bad value found m2" )
      ),

      Test(
        "array-insert-delete",
        fn()
          val mi = create-map( hashFunc, keyCmp, 0.int64, "" )
          val m1 = mi.insert( 1.int64, "foo" )
          val m2 = m1.delete( 1.int64 )

          match m1.lookup( 1.int64 )
            Just(x) ->
              if x == "foo" then ()
              else test-fail( "bad value found m1: " ++ x)
            _ -> test-fail( "bad value found m1" )

          match m2.lookup( 1.int64 )
            Just(x) -> test-fail( "bad value found m2: " ++ x)
            Nothing -> ()
      ),
    ]
  )
]

fun main()
  run-tests(tests)

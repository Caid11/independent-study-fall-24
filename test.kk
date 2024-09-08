/*-----------------------------------------------------------------------------
  Correctness test for map implementations

  NOTE: For string hashing bringup, maybe try using hash function from
  \koka\lib\v1\std\text\atom.kk
-----------------------------------------------------------------------------*/

import lib/map/arrayBacked
import lib/map/hamtBacked
import lib/util/test

fun hashFunc(x : int) : int
  x

fun keyCmp(x : int, y : int) : bool
  x == y

val tests = [
  Case(
    "array-backed",
    [
      Test(
        "array-insert-lookup",
        fn()
          val m = create-map( hashFunc, keyCmp, 0, "" ).insert( 1, "hello" )
          match m.lookup( 1 )
            Just("hello") -> ()
            _ -> test-fail( "bad value found" )
      ),

      Test(
        "array-insert-lookup-force-resize",
        fn()
          val m = create-map( hashFunc, keyCmp, 0, "", 0 ).insert( 1, "hello" )
          match m.lookup( 1 )
            Just("hello") -> ()
            _ -> test-fail( "bad value found" )
      ),

      Test(
        "array-insert-lookup-update",
        fn()
          val mi = create-map( hashFunc, keyCmp, 0, "" )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.insert( 1, "bar" )

          match m1.lookup( 1 )
            Just(x) ->
              if x == "foo" then ()
              else test-fail( "bad value found m1: " ++ x)
            _ -> test-fail( "bad value found m1" )

          match m2.lookup( 1 )
            Just("bar") -> ()
            Just(x) -> test-fail( "bad value found m2: " ++ x)
            _ -> test-fail( "bad value found m2" )
      ),

      Test(
        "array-insert-delete",
        fn()
          val mi = create-map( hashFunc, keyCmp, 0, "" )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.delete( 1 )

          match m1.lookup( 1 )
            Just(x) ->
              if x == "foo" then ()
              else test-fail( "bad value found m1: " ++ x)
            _ -> test-fail( "bad value found m1" )

          match m2.lookup( 1 )
            Just(x) -> test-fail( "bad value found m2: " ++ x)
            Nothing -> ()
      ),
    ]
  ),

  Case(
    "hamt-backed",
    [
      Test(
        "hamt-insert-lookup",
        fn()
          val m = create-map( hashFunc, keyCmp, "" ).insert( 1, "hello" )
          match m.lookup( 1 )
            Just("hello") -> ()
            _ -> test-fail( "bad value found" )
      ),

      Test(
        "hamt-insert-lookup-update",
        fn()
          val mi = create-map( hashFunc, keyCmp, "" )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.insert( 1, "bar" )

          match m1.lookup( 1 )
            Just(x) ->
              if x == "foo" then ()
              else test-fail( "bad value found m1: " ++ x)
            _ -> test-fail( "bad value found m1" )

          match m2.lookup( 1 )
            Just(x) ->
              if x == "bar" then ()
              else test-fail( "bad value found m2: " ++ x)
            _ -> test-fail( "bad value found m2" )
      ),

      Test(
        "hamt-insert-delete",
        fn()
          val mi = create-map( hashFunc, keyCmp, "" )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.delete( 1 )

          match m1.lookup( 1 )
            Just(x) ->
              if x == "foo" then ()
              else test-fail( "bad value found m1: " ++ x)
            _ -> test-fail( "bad value found m1" )

          match m2.lookup( 1 )
            Just(x) -> test-fail( "bad value found m2: " ++ x)
            Nothing -> ()
      ),
    ]
  )
]

fun main()
  run-tests(tests)

/*-----------------------------------------------------------------------------
  Correctness test for map implementations

  NOTE: For string hashing bringup, maybe try using hash function from
  \koka\lib\v1\std\text\atom.kk
-----------------------------------------------------------------------------*/

module test

import lib/map/arrayBacked
import lib/map/hamtBacked
import lib/map/map
import lib/util/misc
import lib/util/test

fun hash-func(x : int) : int
  x

fun keyCmp(x : int, y : int) : bool
  x == y

fun assert-lookup-returns(m : map<int,string>, k : int, v : string)
   match m.lookup( k )
    Just(str) ->
      if str == v then ()
      else test-fail( "bad value found: " ++ str )
    Nothing -> test-fail("key not found")

fun assert-lookup-key-not-found(m : map<int,string>, k : int)
   match m.lookup( k )
    Just(str) -> test-fail( "value found when key not expected: " ++ str )
    Nothing -> ()

val tests = [
  Case(
    "array-backed",
    [
      Test(
        "array-insert-lookup",
        fn()
          val m = create-array-backed( hash-func, keyCmp ).insert( 1, "hello" )
          m.assert-lookup-returns(1, "hello")
      ),

      Test(
        "array-insert-lookup-force-resize",
        fn()
          val m = create-array-backed( hash-func, keyCmp, 0 ).insert( 1, "hello" )
          m.assert-lookup-returns(1, "hello")
      ),

      Test(
        "array-insert-lookup-insert-idx-wraps",
        fn()
          val m = create-array-backed( hash-func, keyCmp, 2, allow-resize = False)
            .insert( 1, "foo" )
            .insert( 3, "bar" )
          m.assert-lookup-returns(3, "bar")
      ),

      Test(
        "array-insert-lookup-update",
        fn()
          val mi = create-array-backed( hash-func, keyCmp )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.insert( 1, "bar" )

          m1.assert-lookup-returns(1, "foo")
          m2.assert-lookup-returns(1, "bar")
      ),

      Test(
        "array-insert-delete",
        fn()
          val mi = create-array-backed( hash-func, keyCmp )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.delete( 1 )


          m1.assert-lookup-returns(1, "foo")
          m2.assert-lookup-key-not-found(1)
      ),

      Test(
        "array-map",
        fn()
          val inputs = list(1,10).zip(list(11,20).map(show))
          val m = inputs.foldl(
            create-array-backed( hash-func, keyCmp ),
            fn(curr-m, (k,v)) curr-m.insert(k, v)
          )

          val result = m.map/map-with-key(fn(k,x) x)

          if result.count != inputs.length then
            test-fail("result map has bad number of values: " ++ result.count.show)
          else
            inputs.map(fn((k,v)) result.assert-lookup-returns(k,v))
            ()
      ),
    ]
  ),

  Case(
    "hamt-backed",
    [
      Test(
        "hamt-insert-lookup",
        fn()
          val m = create-hamt-backed( hash-func, keyCmp ).insert( 1, "hello" )
          match m.lookup( 1 )
            Just("hello") -> ()
            _ -> test-fail( "bad value found" )
      ),

      Test(
        "hamt-insert-lookup-update",
        fn()
          val mi = create-hamt-backed( hash-func, keyCmp )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.insert( 1, "bar" )

          m1.assert-lookup-returns(1, "foo")
          m2.assert-lookup-returns(1, "bar")
      ),

      Test(
        "hamt-insert-delete",
        fn()
          val mi = create-hamt-backed( hash-func, keyCmp )
          val m1 = mi.insert( 1, "foo" )
          val m2 = m1.delete( 1 )

          m1.assert-lookup-returns(1, "foo")
          m2.assert-lookup-key-not-found(1)
      ),
    ]
  )
]

fun main()
  run-tests(tests)

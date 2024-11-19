/*-----------------------------------------------------------------------------
  Correctness test for map implementations

  NOTE: For string hashing bringup, maybe try using hash function from
  \koka\lib\v1\std\text\atom.kk
-----------------------------------------------------------------------------*/

module test

import lib/map/arrayBacked
import lib/map/hamtBacked
import lib/map/champBacked
import lib/map/map
import lib/util/misc
import lib/util/test

fun hash-func(x : int) : int
  x

fun keyCmp(x : int, y : int) : bool
  x == y

fun string/assert-lookup-returns(m : map<int,string>, k : int, v : string)
   match m.lookup( k )
    Just(str) ->
      if str == v then ()
      else test-fail( "bad value found: " ++ str )
    Nothing -> test-fail("key not found: " ++ k.show)

fun int/assert-lookup-returns(m : map<int,int>, k : int, v : int)
   match m.lookup( k )
    Just(mv) ->
      if mv == v then ()
      else test-fail( "bad value found: " ++ mv.show )
    Nothing -> test-fail("key not found: " ++ k.show)

fun assert-lookup-key-not-found(m : map<int,string>, k : int)
   match m.lookup( k )
    Just(str) -> test-fail( "value found when key not expected: " ++ str )
    Nothing -> ()

val tests = [
  Case(
    "sort",
    [
      Test(
        "sort-two-items",
        fn()
          val inputs = [(2,2), (1,1)]

          val sorted = inputs.sort()

          val expected = [(1,1), (2,2)]
          assert(sorted == expected, "lists not equal")
      ),

      Test(
        "sort-two-items-sorted",
        fn()
          val inputs = [(1,1), (2,2)]

          val sorted = inputs.sort()

          val expected = [(1,1), (2,2)]
          assert(sorted == expected, "lists not equal")
      ),

      Test(
        "sort-nontrivial",
        fn()
          val inputs = [ (5,15), (6,16), (7,17), (8,18), (9,19), (10,20), (4,14), (3,13), (2,12), (1,11) ]

          val sorted = inputs.sort()

          val expected = [ (1,11), (2,12), (3,13), (4,14), (5,15), (6,16), (7,17), (8,18), (9,19), (10,20) ]
          assert(sorted == expected, "lists not equal")
      )
    ]
  ),

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

      Test(
        "array-equals-empty",
        fn()
          val m1 = create-array-backed( hash-func, keyCmp )
          val m2 = create-array-backed( hash-func, keyCmp )

          val result = m1.equals(m2, keyCmp)

          assert(result, "maps should match")
      ),

      Test(
        "array-equals-one-empty-one-with-value",
        fn()
          val m1 = create-array-backed( hash-func, keyCmp )
          val m2 = create-array-backed( hash-func, keyCmp ).insert(1,1)

          val result = m1.equals(m2, keyCmp)

          assert(!result, "maps should not match")
      ),

      Test(
        "array-equals-insert-delete-values",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m1 = inputs.foldl(create-array-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val (to-delete-k, to-delete-v) = match inputs[0]
            Just((k,v)) -> (k,v)
          val m2 = m1.delete(to-delete-k).insert(to-delete-k, to-delete-v)

          val result = m1.equals(m2, keyCmp)

          assert(result, "maps should match")
      ),

      Test(
        "array-equals-same-values-inserted",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m1 = inputs.foldl(create-array-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))
          val m2 = inputs.foldl(create-array-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val result = m1.equals(m2, keyCmp)

          assert(result, "maps should match")
      ),

      Test(
        "array-equals-value-deleted",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m1 = inputs.foldl(create-array-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val (to-delete-k, _) = match inputs[0]
            Just((k,v)) -> (k,v)
          val m2 = m1.delete(to-delete-k)

          val result = m1.equals(m2, keyCmp)

          assert(!result, "maps should not match")
      ),

      Test(
        "array-equals-diff-values-inserted",
        fn()
          val inputs-m1 = list(1,10).zip(list(11,20))
          val m1 = inputs-m1.foldl(create-array-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))
          val inputs-m2 = list(21,30).zip(list(31,40))
          val m2 = inputs-m2.foldl(create-array-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val result = m1.equals(m2, keyCmp)

          assert(!result, "maps should not match")
      ),

      Test(
        "array-batch-insert",
        fn()
          val inputs = list(1,10).zip(list(11,20)).shuffle(1)

          val m = inputs.create-array-backed-batch( hash-func, keyCmp )

          inputs.map(fn((k,v))
            assert-lookup-returns(m, k, v)
          )

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
          val mi = create-hamt-backed( hash-func, keyCmp )

          val m = mi.insert( 1, "hello" )

          m.assert-lookup-returns(1, "hello")
      ),

      Test(
        "hamt-insert-lookup-subtree",
        fn()
          val mi = create-hamt-backed( hash-func, keyCmp )

          val m = mi
            .insert( 1, "hello" )
            .insert( 33, "there" )

          m.assert-lookup-returns(1, "hello")
          m.assert-lookup-returns(33, "there")
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

      Test(
        "hamt-map",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m = inputs.foldl(
            create-hamt-backed( hash-func, keyCmp ),
            fn(curr-m, (k,v))
              curr-m.insert(k, v)
          )

          val result = m.map/map-with-key(fn(k,x) x + 1)

          if result.count != inputs.length then
            test-fail("result map has bad number of values: " ++ result.count.show)
          else
            inputs.map(fn((k,v)) result.assert-lookup-returns(k,v + 1))
            ()
      ),

      Test(
        "hamt-equals-empty",
        fn()
          val m1 = create-hamt-backed( hash-func, keyCmp )
          val m2 = create-hamt-backed( hash-func, keyCmp )

          val result = m1.equals(m2, keyCmp)

          assert(result, "maps should match")
      ),

      Test(
        "hamt-equals-one-empty-one-with-value",
        fn()
          val m1 = create-hamt-backed( hash-func, keyCmp )
          val m2 = create-hamt-backed( hash-func, keyCmp ).insert(1,1)

          val result = m1.equals(m2, keyCmp)

          assert(!result, "maps should not match")
      ),

      Test(
        "hamt-equals-insert-delete-values",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m1 = inputs.foldl(create-hamt-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val (to-delete-k, to-delete-v) = match inputs[0]
            Just((k,v)) -> (k,v)
          val m2 = m1.delete(to-delete-k).insert(to-delete-k, to-delete-v)

          val result = m1.equals(m2, keyCmp)

          assert(result, "maps should match")
      ),

      Test(
        "hamt-equals-same-values-inserted",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m1 = inputs.foldl(create-hamt-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))
          val m2 = inputs.foldl(create-hamt-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val result = m1.equals(m2, keyCmp)

          assert(result, "maps should match")
      ),

      Test(
        "hamt-equals-value-deleted",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m1 = inputs.foldl(create-hamt-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val (to-delete-k, _) = match inputs[0]
            Just((k,v)) -> (k,v)
          val m2 = m1.delete(to-delete-k)

          val result = m1.equals(m2, keyCmp)

          assert(!result, "maps should not match")
      ),

      Test(
        "hamt-equals-diff-values-inserted",
        fn()
          val inputs-m1 = list(1,10).zip(list(11,20))
          val m1 = inputs-m1.foldl(create-hamt-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))
          val inputs-m2 = list(21,30).zip(list(31,40))
          val m2 = inputs-m2.foldl(create-hamt-backed( hash-func, keyCmp ),
                                fn(m, (k,v)) m.insert(k,v))

          val result = m1.equals(m2, keyCmp)

          assert(!result, "maps should not match")
      ),

      Test(
        // Regression test with random values from benchmark run.
        // These inputs caused the tree to recursively insert infinitely until we ran out of levels.
        "hamt-regression-1",
        fn()
          val inputs = [1000000, 999999, 999998, 999997, 999996, 999995, 999994, 999993, 999992, 999991, 999990, 999989, 999988, 999987, 999986, 999985, 999984, 999983, 999982, 999981, 999980, 999979, 999978, 999977, 999976, 999975, 999974, 999973, 999972, 999971, 999970, 999969, 999968]

          val m = inputs.foldl(create-hamt-backed( hash-func, keyCmp ),
                               fn(m, i) m.insert(i,i))

          inputs.foreach(fn(i)
            m.assert-lookup-returns(i,i)
          )
        ),
    ]
  ),

  Case(
    "champ-backed",
    [
      Test(
        "champ-insert-lookup",
        fn()
          val m = create-champ-backed( hash-func, keyCmp ).insert( 1, "hello" )
          m.assert-lookup-returns(1, "hello")
      ),

      Test(
        "champ-insert-lookup-recurse",
        fn()
          val mi = create-champ-backed( hash-func, keyCmp )

          val m = mi
            .insert( 1, "hello" )
            .insert( 33, "bar" )

          m.assert-lookup-returns(1, "hello")
          m.assert-lookup-returns(33, "bar")
      ),

      Test(
        "champ-map",
        fn()
          val inputs = list(1,10).zip(list(11,20))
          val m = inputs.foldl(
            create-champ-backed( hash-func, keyCmp ),
            fn(curr-m, (k,v)) curr-m.insert(k, v)
          )

          val result = m.map/map-with-key(fn(k,x) x + 1)

          if result.count != inputs.length then
            test-fail("result map has bad number of values: " ++ result.count.show)
          else
            inputs.map(fn((k,v)) result.assert-lookup-returns(k,v + 1))
            ()
      ),

      Test(
        // Regression test with random values from benchmark run.
        // These inputs caused the tree to recursively insert infinitely until we ran out of levels.
        "champ-regression-1",
        fn()
          val inputs = [1000000, 999999, 999998, 999997, 999996, 999995, 999994, 999993, 999992, 999991, 999990, 999989, 999988, 999987, 999986, 999985, 999984, 999983, 999982, 999981, 999980, 999979, 999978, 999977, 999976, 999975, 999974, 999973, 999972, 999971, 999970, 999969, 999968]

          val m = inputs.foldl(create-champ-backed( hash-func, keyCmp ),
                               fn(m, i) m.insert(i,i))

          inputs.foreach(fn(i)
            m.assert-lookup-returns(i,i)
          )
      ),

      Test(
        "champ-regression-2",
        fn()
          val inputs = [1000000, 999999, 999998, 999997, 999996, 999995, 999994, 999993, 999992, 999991, 999990, 999989, 999988, 999987, 999986, 999985, 999984, 999983, 999982, 999981, 999980, 999979, 999978, 999977, 999976, 999975, 999974, 999973, 999972, 999971, 999970, 999969, 999968, 999967, 999966, 999965, 999964, 999963, 999962, 999961, 999960, 999959, 999958, 999957, 999956, 999955, 999954, 999953, 999952, 999951, 999950, 999949, 999948, 999947, 999946, 999945, 999944, 999943, 999942, 999941, 999940, 999939, 999938, 999937, 999936, 999935]
          val m = inputs.foldl(create-champ-backed( hash-func, keyCmp ),
                               fn(m, i) m.insert(i,i))

          inputs.foreach(fn(i)
            m.assert-lookup-returns(i,i)
          )
      ),
    ]
  ),
]

pub fun main()
  run-tests(tests)

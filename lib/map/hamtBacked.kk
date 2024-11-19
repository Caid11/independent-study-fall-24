/*-----------------------------------------------------------------------------
  HAMT backed hashmap

  This version makes use of the bitmap member to 

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module lib/map/hamtBacked

import std/num/int32

import lib/map/utils

// TODO: At some point try using popc
// TODO: Switch values to ptrs (also, how does that relate to boxing?)
// TODO: We're not using the bitmap

val arity = 32

value struct hamtLeaf<k,v>
  key : k
  hash : int32
  stored : v

struct hamtArray<k,v>
  bitmap : int32
  children : list<hamtNode<k,v>>

type hamtNode<k,v>
  Array(a : hamtArray<k,v>)
  Leaf(l : hamtLeaf<k,v>)

pub struct hamtBackedMap<k,v>
  hashFunc : k -> int
  keyCmp : (k,k) -> bool
  root : hamtNode<k,v>

// Create a new map
pub fun create-map(hashFunc : k -> int, keyCmp : (k,k) -> bool) : hamtBackedMap<k,v>
  HamtBackedMap(
    hashFunc,
    keyCmp,
    Array(HamtArray(0.int32, []))
  )

fun hamtNode/count(n : hamtNode<k,v>) : div int
  match n
    Leaf -> 1
    Array(a) -> a.children.map(count).sum

pub fun count(m : hamtBackedMap<k,v>) : div int
  m.root.hamtNode/count()

// Basic operations

fun insert-i(n : hamtNode<k,v>, h : int32, shift-width : int, key-a : k, x : v) : <div,exn> hamtNode<k,v>
  match n
    Leaf(l) ->
      if l.hash == h then
        Leaf(HamtLeaf(key-a, h, x))
      else
        Array(HamtArray(0.i32, []))
          .insert-i(l.hash, shift-width, l.key, l.stored)
          .insert-i(h, shift-width, key-a, x)

    Array(a) ->
      val bit-pos = calc-bit-pos(h, shift-width)
      val idx = calc-idx(a.bitmap, bit-pos)

      if( a.bitmap.and( bit-pos ) == 0.int32 ) then
        // Slot is free. Create a new leaf, add it to the list of children, and
        // update the bitmap.
        val new-leaf = Leaf(HamtLeaf(key-a, h, x))
        Array(HamtArray(a.bitmap.or(bit-pos), a.children.insert(new-leaf, idx)))
      else
        val insert-node = match a.children[idx] 
          Nothing ->
            throw("hamt bad insert idx")
          Just(x) -> x

        val new-node = insert-node.insert-i(h, shift-width + 5, key-a, x)
        Array(HamtArray(a.bitmap.or(bit-pos), a.children.set(new-node, idx)))

pub fun insert(m : hamtBackedMap<k,v>, key : k, x : v) : <div,exn> hamtBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  val new-root = insert-i(m.root, hash, 0, key, x)
  m(root = new-root)

fun lookup-i(m : hamtNode<k,v>, h : int32, shift-width : int) : <div,exn> maybe<v>
  match m
    Leaf(l) ->
      if l.hash == h then Just(l.stored)
      else Nothing

    Array(a) ->
      val bit-pos = calc-bit-pos(h, shift-width)
      val idx = calc-idx(a.bitmap, bit-pos)

      if( a.bitmap.and( bit-pos ) == 0.int32 ) then Nothing
      else
        val lookup-node = match a.children[idx]
          Nothing -> throw("hamt bad lookup idx")
          Just(x) -> x

        lookup-node.lookup-i(h, shift-width + 5)

pub fun lookup(m : hamtBackedMap<k,v>, key : k) : <div,exn> maybe<v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  lookup-i(m.root, hash, 0)

fun delete-i(n : hamtNode<k,v>, h : int32, shift-width : int) : <div,exn> hamtNode<k,v>
  match n
    Leaf(_) -> throw("hamt delete called on leaf")

    Array(a) ->
      val bit-pos = calc-bit-pos(h, shift-width)
      val idx = calc-idx(a.bitmap, bit-pos)

      // Item isn't present in map, simply return
      if( a.bitmap.and( bit-pos ) == 0.int32 ) then n
      else
        val delete-node = match a.children[idx]
          Nothing -> throw("hamt bad delete idx")
          Just(x) -> x

        match delete-node
          Leaf(l) ->
            // Node is a leaf. Clear bit from bitmap and remove from list (if leaf hash is same).
            if l.hash == h then
              val new-bitmap = a.bitmap.and(bit-pos.not)
              val new-children = a.children.delete(idx)
              
              // If there is a single leaf left in the bitmap, return a leaf instead of an array.
              if new-bitmap.popcount() == 1 then
                val node = match a.children[0]
                  Nothing -> throw("hamt expected child")
                  Just(n) -> n

                match node
                  Leaf(_) -> node
                  Array(_) -> Array(HamtArray(new-bitmap, new-children))
              else Array(HamtArray(new-bitmap, new-children))
            else
              n
          Array(_) ->
            // Node is an array. Recursively delete.
            val new-array = delete-node.delete-i(h, shift-width + 5)
            Array(HamtArray(a.bitmap, a.children.set(new-array, idx)))

// TODO: What if key isn't present in map?
pub fun delete(m : hamtBackedMap<k,v>, key : k) : <exn,div> hamtBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  val new-root = delete-i(m.root, hash, 0)
  m(root = new-root)

// Traversal operations

// TODO: The Haskell function can take type a and transform it to type b. That
// probably works because it can enforce that b is Hashable. Can we do
// something like that?

fun eval-if-present( f : v -> a, x : maybe<v> ) : maybe<a>
  match x
    Nothing -> Nothing
    Just(xv) ->
      val new = f(xv)
      Just(new)

// pub fun map(m : hamtBackedMap<k,v>, f : v -> a) : hamtBackedMap<k,a>
//   m

//fun hamtNode/map-with-key(n : hamtNode<k,v>, f : (k, v) -> e a) : <div|e> hamtNode<k,a>
fun map-with-key-node(n, f)
  match n
    Leaf(l) -> Leaf(HamtLeaf(l.key, l.hash, f(l.key, l.stored)))
    Array(a) ->
      val new-children = a.children.map(fn(c) map-with-key-node(c,f))
      Array(HamtArray(a.bitmap, new-children))

pub fun map-with-key(m, f)
  HamtBackedMap(m.hashFunc, m.keyCmp, map-with-key-node(m.root, f))

pub fun filter(m : hamtBackedMap<k,v>, f : v -> bool) : hamtBackedMap<k,v>
  m

pub fun filter-with-key(m : hamtBackedMap<k,v>, f : (k, v) -> bool) : hamtBackedMap<k,v>
  m

// Set operations

pub fun union(m1 : hamtBackedMap<k,v>, m2 : hamtBackedMap<k,v>) : hamtBackedMap<k,v>
  m1

pub fun difference(m1 : hamtBackedMap<k,v>, m2 : hamtBackedMap<k,v>) : hamtBackedMap<k,v>
  m1

pub fun intersection(m1 : hamtBackedMap<k,v>, m2 : hamtBackedMap<k,v>) : hamtBackedMap<k,v>
  m1

fun equals-i(n1 : hamtNode<k,v>, n2 : hamtNode<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  val nodes = (n1,n2)
  match nodes
    (Leaf(l1), Leaf(l2)) -> l1.hash == l2.hash && cmp(l1.stored, l2.stored)
    (Array(a1), Array(a2)) ->
      if a1.bitmap != a2.bitmap then False
      else
        a1.children.zip(a2.children).foldl(True, fn(children-match, (c1,c2))
          children-match && equals-i(c1, c2, cmp)
        )

    _ -> False

pub fun equals(m1 : hamtBackedMap<k,v>, m2 : hamtBackedMap<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  equals-i(m1.root, m2.root, cmp)
  

/*-----------------------------------------------------------------------------
  HAMT backed hashmap

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module lib/map/hamtBacked

import std/num/int32

// TODO: At some point try using popc
// TODO: Switch values to ptrs (also, how does that relate to boxing?)
// TODO: We're not using the bitmap

val arity = 32

value struct hamtLeaf<v>
  hash : int32
  stored : v

struct hamtArray<v>
  bitmap : int32
  children : vector<hamtNode<v>>

type hamtNode<v>
  Array(a : hamtArray<v>)
  Leaf(l : hamtLeaf<v>)
  Null

pub struct hamtBackedMap<k,v>
  hashFunc : k -> int
  keyCmp : (k,k) -> bool
  root : hamtNode<v>

// Create a new map
pub fun create-map(hashFunc : k -> int, keyCmp : (k,k) -> bool) : hamtBackedMap<k,v>
  HamtBackedMap(
    hashFunc,
    keyCmp,
    Null
  )

// Basic operations

fun calc-idx(hash : int32, shift-width : int) : int
  hash.shr(shift-width).and(31.i32).int

fun is-set(bitmask : int32, pos : int) : bool
  val i = 1.i32.shl(pos)
  i.and(bitmask) != 0.i32

fun set(bitmask : int32, pos : int) : int32
  val i = 1.i32.shl(pos)
  i.or(bitmask)

fun unset(bitmask : int32, pos : int) : int32
  val i = 1.i32.shl(pos)
  i.xor(bitmask).and(bitmask)

fun insert-i(n : hamtNode<v>, h : int32, shift-width : int, x : v) : <div,exn> hamtNode<v>
  match n
    Null -> Leaf(HamtLeaf(h, x))
    Leaf(l) ->
      if l.hash == h then Leaf(HamtLeaf(h, x))
      else
        val arr = Array(HamtArray(0.i32, vector/vector(arity, Null)))
        insert-i(arr, l.hash, shift-width, l.stored)
          .insert-i(h, shift-width, x)
    Array(a) ->
      val idx = calc-idx(h, shift-width)
      val to-insert = insert-i(a.children[idx], h, shift-width + 5, x)

      fun init-children(i)
        if i == idx then to-insert
        else a.children[i]

      val new-children = vector-init(32, init-children)
      Array(HamtArray(a.bitmap.hamtBacked/set(idx), new-children))

pub fun insert(m : hamtBackedMap<k,v>, key : k, x : v) : <div,exn> hamtBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  val new-root = insert-i(m.root, hash, 0, x)
  m(root = new-root)

fun lookup-i(m : hamtNode<v>, h : int32, shift-width : int) : <div,exn> maybe<v>
  match m
    Null -> Nothing
    Leaf(l) ->
      if l.hash == h then Just(l.stored)
      else Nothing
    Array(a) ->
      val idx = calc-idx(h, shift-width)
      lookup-i(a.children[idx], h, shift-width + 5)

pub fun lookup(m : hamtBackedMap<k,v>, key : k) : <div,exn> maybe<v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  lookup-i(m.root, hash, 0)

fun delete-i(n : hamtNode<v>, h : int32, shift-width : int) : <div,exn> hamtNode<v>
  match n
    Null -> Null
    Leaf(l) ->
      if l.hash == h then Null
      else n
    Array(a) ->
      val idx = calc-idx(h, shift-width)
      val to-insert = delete-i(a.children[idx], h, shift-width + 5)

      fun init-children(i)
        if i == idx then to-insert
        else a.children[i]

      val new-children = vector-init(32, init-children)
      val new-bitmap =
        match new-children[idx]
          Null -> a.bitmap.hamtBacked/unset(idx)
          _ -> a.bitmap.hamtBacked/set(idx)

      Array(HamtArray(new-bitmap, new-children))

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

// pub fun map-with-key(m : hamtBackedMap<k,v>, f : (k, v) -> a) : hamtBackedMap<k,a>
//   create-map(m.hashFunc)

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

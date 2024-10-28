/*-----------------------------------------------------------------------------
  HAMT backed hashmap

  This version makes use of the bitmap member to 

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module lib/map/hamtBacked

import std/num/int32

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
  children : vector<hamtNode<k,v>>

type hamtNode<k,v>
  Array(a : hamtArray<k,v>)
  Leaf(l : hamtLeaf<k,v>)
  Null

pub struct hamtBackedMap<k,v>
  hashFunc : k -> int
  keyCmp : (k,k) -> bool
  root : hamtNode<k,v>

// Create a new map
pub fun create-map(hashFunc : k -> int, keyCmp : (k,k) -> bool) : hamtBackedMap<k,v>
  HamtBackedMap(
    hashFunc,
    keyCmp,
    Null
  )

fun hamtNode/count(n : hamtNode<k,v>) : div int
  match n
    Null -> 0
    Leaf -> 1
    Array(a) -> a.children.map(count).vlist.sum

pub fun count(m : hamtBackedMap<k,v>) : div int
  m.root.hamtNode/count()

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

fun insert-i(n : hamtNode<k,v>, h : int32, shift-width : int, key-a : k, x : v) : <div,exn> hamtNode<k,v>
  match n
    Null -> Leaf(HamtLeaf(key-a, h, x))
    Leaf(l) ->
      if l.hash == h then Leaf(HamtLeaf(key-a, h, x))
      else
        val arr = Array(HamtArray(0.i32, vector/vector(arity, Null)))
        insert-i(arr, l.hash, shift-width, l.key, l.stored)
          .insert-i(h, shift-width, key-a, x)
    Array(a) ->
      val idx = calc-idx(h, shift-width)
      val to-insert = insert-i(a.children[idx], h, shift-width + 5, key-a, x)

      fun init-children(i)
        if i == idx then to-insert
        else a.children[i]

      val new-children = vector-init(32, init-children)
      Array(HamtArray(a.bitmap.hamtBacked/set(idx), new-children))

pub fun insert(m : hamtBackedMap<k,v>, key : k, x : v) : <div,exn> hamtBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  val new-root = insert-i(m.root, hash, 0, key, x)
  m(root = new-root)

fun lookup-i(m : hamtNode<k,v>, h : int32, shift-width : int) : <div,exn> maybe<v>
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

fun delete-i(n : hamtNode<k,v>, h : int32, shift-width : int) : <div,exn> hamtNode<k,v>
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

      val new-children = vector-init(arity, init-children)
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

//fun hamtNode/map-with-key(n : hamtNode<k,v>, f : (k, v) -> e a) : <div|e> hamtNode<k,a>
fun map-with-key-node(n, f)
  match n
    Null -> Null
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
    (Null, Null) -> True
    (Leaf(l1), Leaf(l2)) -> l1.hash == l2.hash && cmp(l1.stored, l2.stored)
    (Array(a1), Array(a2)) ->
      if a1.bitmap != a2.bitmap then False
      else
        var children-match := True
        a1.children.vector/foreach-indexed(fn(i, c1)
          val c2 = a2.children[i]
          if !equals-i(c1, c2, cmp) then
            children-match := False
            ()
          else ()
        )
        children-match


    _ -> False

pub fun equals(m1 : hamtBackedMap<k,v>, m2 : hamtBackedMap<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  equals-i(m1.root, m2.root, cmp)
  

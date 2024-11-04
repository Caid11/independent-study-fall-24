/*-----------------------------------------------------------------------------
  CHAMP backed hashmap

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module lib/map/champBacked

import std/num/int32

val arity = 32
val arity-log-two = 5

value struct champLeaf<k,v>
  key : k
  hash : int32
  stored : v

// TODO: We should be able to get rid of maybe types by implementing canonicalization
struct champNode<k,v>
  datamap : int32
  nodemap : int32
  children : vector<maybe<champNode<k,v>>>
  data : vector<maybe<champLeaf<k,v>>>

fun get-empty-node()
  ChampNode(0.int32,
            0.int32,
            vector/vector(arity, Nothing),
            vector/vector(arity, Nothing))

pub struct champBackedMap<k,v>
  hashFunc : k -> int
  keyCmp : (k,k) -> bool
  root : champNode<k,v>

// Create a new map
pub fun create-map(hashFunc : k -> int, keyCmp : (k,k) -> bool) : champBackedMap<k,v>
  ChampBackedMap(
    hashFunc,
    keyCmp,
    get-empty-node()
  )

fun champNode/count(n : champNode<k,v>) : <div> int
  val num-contained = n.datamap.popcount() - n.nodemap.popcount()

  var num-children-contained := 0
  n.children.foreach(fn(c)
    match c
      Nothing -> ()
      Just(c) ->
        num-children-contained := num-children-contained + champNode/count(c)
        ()
  )
  num-contained + num-children-contained

pub fun count(m : champBackedMap<k,v>) : div int
  m.root.champNode/count()

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

fun vector/set(v : vector<a>, x : a, idx : int) : _e vector<a>
  vector-init(arity, fn(i)
    if i == idx then x
    else v[i]
  )

fun insert-i(n : champNode<k,v>, h : int32, shift-width : int, key-a : k, x : v) : <div,exn> champNode<k,v>
  val data-idx = calc-idx(h, shift-width)

  // Key not present; insert value into datamap and data
  if( !n.datamap.is-set(data-idx) ) then
    n(datamap = n.datamap.set(data-idx),
      data = n.data.set(Just(ChampLeaf(key-a, h, x)), data-idx))
  // Key is present and there is a subtree; recurse
  else if( n.nodemap.is-set(data-idx) ) then
    val sub-node = match n.children[data-idx]
      Just(node) -> node
      Nothing -> throw("expected node to be present")
    n(nodemap = n.nodemap.set(data-idx),
      children = n.children.set(Just(insert-i(sub-node, h, shift-width + arity-log-two, key-a, x)), data-idx))
  else
    val d = match n.data[data-idx]
      Just(d) -> d
      Nothing -> throw("expected data to be present")

    // Value is present but doesn't match key; create subarray and recurse
    if d.hash != h then
      val subarray = get-empty-node()
        .insert-i(d.hash, shift-width + arity-log-two, d.key, d.stored)
        .insert-i(h, shift-width + arity-log-two, key-a, x)

      n(nodemap = n.nodemap.set(data-idx),
        data = n.data.set(Nothing, data-idx),
        children = n.children.set(Just(subarray), data-idx))
    // Value is present and matches key; replace and return
    else
      n(data = n.data.set(Just(ChampLeaf(key-a, h, x)), data-idx))

pub fun insert(m : champBackedMap<k,v>, key : k, x : v) : <div,exn> champBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  val new-root = insert-i(m.root, hash, 0, key, x)
  m(root = new-root)

fun lookup-i(m : champNode<k,v>, h : int32, shift-width : int) : <div,exn> maybe<v>
  val idx = calc-idx(h, shift-width)
  
  // If contained in data array but not node array, return data
  if( m.datamap.is-set(idx) && !m.nodemap.is-set(idx)) then
    val d = match m.data[idx]
      Just(d) -> d
      Nothing -> throw("expected data")
    Just(d.stored)
  // If contained in both arrays, recurse
  else if( m.datamap.is-set(idx) && m.nodemap.is-set(idx) ) then
    val n = match m.children[idx]
      Just(n) -> n
      Nothing -> throw("expected node")
    lookup-i(n, h, shift-width + arity-log-two)
  // Not contained
  else
    Nothing

pub fun lookup(m : champBackedMap<k,v>, key : k) : <div,exn> maybe<v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  lookup-i(m.root, hash, 0)

pub fun delete(m : champBackedMap<k,v>, key : k) : <exn,div> champBackedMap<k,v>
  m

// Traversal operations
fun map-with-key-node(n, f)
  val new-data = n.data.map(fn(d)
    match d
      Nothing -> Nothing
      Just(d) -> Just(ChampLeaf(d.key, d.hash, f(d.key, d.stored)))
  )
  val new-children = n.children.map(fn(c)
    match c
      Nothing -> Nothing
      Just(c) -> Just(map-with-key-node(c, f))
  )
  n(data = new-data, children = new-children)

pub fun map-with-key(m, f)
  ChampBackedMap(m.hashFunc, m.keyCmp, map-with-key-node(m.root, f))

pub fun equals(m1 : champBackedMap<k,v>, m2 : champBackedMap<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  False
  

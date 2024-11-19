/*-----------------------------------------------------------------------------
  CHAMP backed hashmap

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module lib/map/champBacked

import std/num/int32

import lib/map/utils

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
  children : list<champNode<k,v>>
  data : list<champLeaf<k,v>>

fun get-empty-node()
  ChampNode(0.int32,
            0.int32,
            [],
            [])

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
  val num-children-contained = n.children.foldl(0, fn(curr-count, child)
    curr-count + child.champNode/count()
  )
  num-contained + num-children-contained

pub fun count(m : champBackedMap<k,v>) : div int
  m.root.champNode/count()

// Basic operations

fun insert-i(n : champNode<k,v>, h : int32, shift-width : int, key-a : k, x : v) : <div,exn> champNode<k,v>
  val bit-pos = calc-bit-pos(h, shift-width)
  val data-idx = calc-idx(n.datamap, bit-pos)
  val child-idx = calc-idx(n.nodemap, bit-pos)

  // Key is present and there is a subtree; recurse
  if n.nodemap.and( bit-pos ) != 0.int32 then
    val sub-node = match n.children[child-idx]
      Just(node) -> node
      Nothing -> throw("champ bad inset idx subtree (idx = " ++ child-idx.show ++ " length = " ++ n.children.length.show ++ ")")

    n(nodemap = n.nodemap.or( bit-pos ),
      children = n.children.set(insert-i(sub-node, h, shift-width + arity-log-two, key-a, x), child-idx))
  else if n.datamap.and( bit-pos ) == 0.int32 then
    n(datamap = n.datamap.or( bit-pos ),
      data = n.data.insert(ChampLeaf(key-a, h, x), data-idx))
  else
    val d = match n.data[data-idx]
      Just(d) -> d
      Nothing -> throw("champ bad insert idx leaf")

    // Value is present but doesn't match key; create subarray and recurse
    if d.hash != h then
      val subarray = get-empty-node()
        .insert-i(d.hash, shift-width + arity-log-two, d.key, d.stored)
        .insert-i(h, shift-width + arity-log-two, key-a, x)

      val new-nodemap = n.nodemap.or( bit-pos )
      val new-datamap = n.datamap.and( bit-pos.not )
      val new-data = n.data.delete( data-idx )
      val new-children = n.children.insert(subarray, child-idx)

      n(nodemap = new-nodemap,
        datamap = new-datamap,
        data = new-data,
        children = new-children)
    // Value is present and matches key; replace and return
    else
      val new-leaf = ChampLeaf(key-a, h, x)
      val new-data = n.data.set(new-leaf, data-idx)
      n(data = new-data)

pub fun insert(m : champBackedMap<k,v>, key : k, x : v) : <div,exn> champBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32


  val new-root = insert-i(m.root, hash, 0, key, x)
  m(root = new-root)

fun lookup-i(m : champNode<k,v>, h : int32, shift-width : int) : <div,exn> maybe<v>
  val bit-pos = calc-bit-pos(h, shift-width)
  val data-idx = calc-idx(m.datamap, bit-pos)
  val child-idx = calc-idx(m.nodemap, bit-pos)

  // Key contained in subarray. Recurse.
  if m.nodemap.and( bit-pos ) != 0.int32 then
    val n = match m.children[child-idx]
      Just(n) -> n
      Nothing -> throw("champ bad lookup node idx")
    n.lookup-i(h, shift-width + arity-log-two)
  // Key contained in data array. Return value.
  else if m.datamap.and( bit-pos ) != 0.int32 then
    val d = match m.data[data-idx]
      Just(d) -> d
      Nothing -> throw("champ bad lookup leaf idx (idx = " ++ data-idx.show ++ " length = " ++ m.data.length.show ++ ")")
    if d.hash == h then Just(d.stored)
    else Nothing
  // Key not contained in either array.
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
  val new-data = n.data.map(fn(d) ChampLeaf(d.key, d.hash, f(d.key, d.stored)))
  val new-children = n.children.map(fn(c) map-with-key-node(c, f))
  n(data = new-data, children = new-children)

pub fun map-with-key(m, f)
  ChampBackedMap(m.hashFunc, m.keyCmp, map-with-key-node(m.root, f))

pub fun equals(m1 : champBackedMap<k,v>, m2 : champBackedMap<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  False
  

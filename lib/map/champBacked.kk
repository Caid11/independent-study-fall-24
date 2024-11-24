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
  // children : vector<champNode<k,v>>
  // data : vector<champLeaf<k,v>>
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
  //val num-children-contained = n.children.vlist.foldl(0, fn(curr-count, child)
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
    //val sub-node = n.children[child-idx]
    val sub-node = match n.children[child-idx]
      Nothing -> throw("insert bad child idx")
      Just(v) -> v

    n(nodemap = n.nodemap.or( bit-pos ),
      children = n.children.set(insert-i(sub-node, h, shift-width + arity-log-two, key-a, x), child-idx))
  else if n.datamap.and( bit-pos ) == 0.int32 then
    n(datamap = n.datamap.or( bit-pos ),
      data = n.data.insert(ChampLeaf(key-a, h, x), data-idx))
  else
    // val d = n.data[data-idx]
    val d = match n.data[data-idx]
      Nothing -> throw("lookup bad child idx")
      Just(v) -> v

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
    // val n = m.children[child-idx]
    val n = match m.children[child-idx]
      Nothing -> throw("lookup bad child idx")
      Just(v) -> v
    n.lookup-i(h, shift-width + arity-log-two)
  // Key contained in data array. Return value.
  else if m.datamap.and( bit-pos ) != 0.int32 then
    // val d = m.data[data-idx]
    val d = match m.data[data-idx]
      Nothing -> throw("lookup bad data idx")
      Just(v) -> v
    if d.hash == h then Just(d.stored)
    else Nothing
  // Key not contained in either array.
  else
    Nothing

pub fun lookup(m : champBackedMap<k,v>, key : k) : <div,exn> maybe<v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32

  lookup-i(m.root, hash, 0)

fun delete-i(n : champNode<k,v>, h : int32, shift-width : int) : <div,exn> champNode<k,v>
  val bit-pos = calc-bit-pos(h, shift-width)
  val data-idx = calc-idx(n.datamap, bit-pos)
  val child-idx = calc-idx(n.nodemap, bit-pos)

  // Key is present and there is a subtree; recurse
  if n.nodemap.and( bit-pos ) != 0.int32 then
    //val sub-node = n.children[child-idx]
    val sub-node = match n.children[child-idx]
      Nothing -> throw("insert bad child idx")
      Just(v) -> v

    val new-subnode = sub-node.delete-i(h, shift-width + 5)
    
    // if the subnode is empty, clear its bit in the nodemap and delete the subtree.
    if new-subnode.datamap.popcount() == 0 && new-subnode.nodemap.popcount() == 0 then
      val new-nodemap = n.nodemap.and( bit-pos.not )
      val new-children = n.children.delete( child-idx )
      n(nodemap = new-nodemap, children = new-children)
    else
      n(children = n.children.set(new-subnode, child-idx))
  // Key is present in datamap. Delete leaf and update map.
  else if n.datamap.and( bit-pos ) != 0.int32 then
    val new-datamap = n.datamap.and( bit-pos.not )
    val new-data = n.data.delete( data-idx )
    n(datamap = new-datamap, data = new-data)
  // Key not present in either map. Return
  else
    n

pub fun delete(m : champBackedMap<k,v>, key : k) : <exn,div> champBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash = hash-func(key).int32
  
  val new-root = delete-i(m.root, hash, 0)
  m(root = new-root)

// Traversal operations
fun map-with-key-node(n, f)
  val new-data = n.data.map(fn(d) ChampLeaf(d.key, d.hash, f(d.key, d.stored)))
  val new-children = n.children.map(fn(c) map-with-key-node(c, f))
  n(data = new-data, children = new-children)

pub fun map-with-key(m, f)
  ChampBackedMap(m.hashFunc, m.keyCmp, map-with-key-node(m.root, f))

fun equals-i(n1 : champNode<k,v>, n2 : champNode<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  if n1.nodemap != n2.nodemap || n1.datamap != n2.datamap then False
  else
    // Compare leaves
    val leaves-equal = n1.data.zip(n2.data).foldl(True, fn(are-equal, (c1,c2))
      if c1.hash != c2.hash || cmp(c1.stored, c2.stored) == False then False
      else are-equal
    )

    if !leaves-equal then False
    else
      val children-equal = n1.children.zip(n2.children).foldl(True, fn(are-equal, (c1,c2))
        if !c1.equals-i(c2, cmp) then False
        else are-equal
      )

      children-equal

pub fun equals(m1 : champBackedMap<k,v>, m2 : champBackedMap<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  equals-i(m1.root, m2.root, cmp)
  

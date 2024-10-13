/*-----------------------------------------------------------------------------
  Flat array backed hashmap

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module lib/map/arrayBacked

import std/num/int64

// TODO: Instead of storing separate bitvector, use maybe type?

// TODO: Add an option to disable resizing

pub struct arrayBackedMap<k,v>
  hashFunc : k -> int
  keyCmp : (k,k) -> bool
  default-key : k
  default-val : v
  occupied : vector<bool>
  keys : vector<k>
  members : vector<v>

// Create a new map
pub fun create-map(hashFunc : k -> int, keyCmp : (k,k) -> bool, default-key : k, default-value : v, initial-capacity : int = 32) : arrayBackedMap<k,v>
  ArrayBackedMap(
    hashFunc,
    keyCmp,
    default-key,
    default-value,
    vector/vector(initial-capacity, False),
    vector/vector(initial-capacity, default-key),
    vector/vector(initial-capacity, default-value)
  )

fun resize(m : arrayBackedMap<k,v>) : <div,exn> arrayBackedMap<k,v>
  val new-capacity = max(32, m.occupied.length * 2)
  val new-m = m(
    occupied = vector(new-capacity, False),
    keys = vector(new-capacity, m.default-key),
    members = vector(new-capacity, m.default-val)
  )

  zip(m.occupied.list, m.keys.list)
    .zip(m.members.list)
    .filter(fn(((o,_),_)) o != False)
    .foldl(new-m, fn(im, ((_,k),v)) im.insert(k, v))

// Basic operations

fun find-unoccupied-slot(m : arrayBackedMap<k,v>, start-idx : int, key : k) : <div,exn> int
  val cmp-key = m.keyCmp

  fun find-slot(idx)
    if idx >= m.occupied.length then -1 // TODO: We should wrap
    else
      if (m.occupied[idx] == False || cmp-key(key, m.keys[idx])) then idx
      else find-slot(idx + 1)

  find-slot(start-idx)

pub fun insert(m : arrayBackedMap<k,v>, key : k, x : v) : <div,exn> arrayBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash-idx = hash-func(key) % m.occupied.length

  val slot = find-unoccupied-slot(m, hash-idx, key)
  val (insert-idx, resized-m) = if slot >= 0 then (slot, m) 
    else
      val resized = m.resize
      val idx = resized.find-unoccupied-slot(hash-idx, key)
      (idx, resized)

  val updated-occupied = vector-init(resized-m.occupied.length, fn(i)
    if i == insert-idx then True
    else resized-m.occupied[i]
  )

  val updated-keys = vector-init(resized-m.keys.length, fn(i)
    if i == insert-idx then key
    else  resized-m.keys[i]
  )

  val updated-members = vector-init(resized-m.members.length, fn(i)
    if i == insert-idx then x
    else resized-m.members[i]
  )

  resized-m(occupied = updated-occupied, keys = updated-keys, members = updated-members)

pub fun lookup(m : arrayBackedMap<k,v>, key : k) : <div,exn> maybe<v>
  val hash-func = m.hashFunc
  val hash-idx = hash-func(key) % m.occupied.length

  val k-cmp = m.keyCmp

  fun lookup-at(i : int)
    if i >= m.occupied.length || m.occupied[i] == False then Nothing
    else
      if k-cmp(m.keys[i], key) then Just(m.members[i])
      else lookup-at(i + 1)
          
  lookup-at(hash-idx)
  
// TODO: What if key isn't present in map?
pub fun delete(m : arrayBackedMap<k,v>, key : k) : <exn,div> arrayBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash-idx = hash-func(key) % m.occupied.length

  val k-cmp = m.keyCmp

  fun lookup-at(i : int)
    if i >= m.occupied.length || m.occupied[i] == False then Nothing
    else
      if k-cmp(m.keys[i], key) then Just(i)
      else lookup-at(i + 1)

  val remove-idx-maybe = lookup-at(hash-idx)
  match remove-idx-maybe
    Nothing -> m // TODO: Throw exn here?
    Just(idx) ->
      fun get-new-key(i)
        if i == idx then m.default-key
        else m.keys[i]

      fun get-new-occupied(i)
        if i == idx then False
        else m.occupied[i]

      fun get-new-member(i)
        if i == idx then m.default-val
        else m.members[i]

      val new-occupied = vector-init(m.occupied.length, get-new-occupied)
      val new-keys = vector-init(m.keys.length, get-new-key)
      val new-members = vector-init(m.members.length, get-new-member)

      m(
        occupied = new-occupied,
        keys = new-keys,
        members = new-members
      )
 

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

// pub fun map(m : arrayBackedMap<k,v>, f : v -> a) : arrayBackedMap<k,a>
//   m

// pub fun map-with-key(m : arrayBackedMap<k,v>, f : (k, v) -> a) : arrayBackedMap<k,a>
//   create-map(m.hashFunc)

pub fun filter(m : arrayBackedMap<k,v>, f : v -> bool) : arrayBackedMap<k,v>
  m

pub fun filter-with-key(m : arrayBackedMap<k,v>, f : (k, v) -> bool) : arrayBackedMap<k,v>
  m

// Set operations

pub fun union(m1 : arrayBackedMap<k,v>, m2 : arrayBackedMap<k,v>) : arrayBackedMap<k,v>
  m1

pub fun difference(m1 : arrayBackedMap<k,v>, m2 : arrayBackedMap<k,v>) : arrayBackedMap<k,v>
  m1

pub fun intersection(m1 : arrayBackedMap<k,v>, m2 : arrayBackedMap<k,v>) : arrayBackedMap<k,v>
  m1

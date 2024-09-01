/*-----------------------------------------------------------------------------
  Flat array backed hashmap

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module map/arrayBacked

import std/num/int64

pub struct arrayBackedMap<k,v>
  hashFunc : k -> int
  keyCmp : (k,k) -> bool
  occupied : vector<bool>
  keys : vector<k>
  members : vector<v>
  default-key : k
  default-val : v

// Create a new map
pub fun create-map(hashFunc : k -> int, keyCmp : (k,k) -> bool, default-key : k, default-value : v, initial-capacity : int = 32) : arrayBackedMap<k,v>
  ArrayBackedMap(
    hashFunc,
    keyCmp,
    vector/vector(initial-capacity, False),
    vector/vector(initial-capacity, default-key),
    vector/vector(initial-capacity, default-value),
    default-key,
    default-value
  )

fun resize(m : arrayBackedMap<k,v>) : <div> arrayBackedMap<k,v>
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
fun has-unoccupied-slot(m : arrayBackedMap<k,v>) : bool
  val occupied-maybe = m.occupied.foreach-while(fn(o)
    if o == False then Just(True)
    else Nothing
  )
  match occupied-maybe
    Nothing -> False
    _ -> True

fun find-unoccupied-slot(m : arrayBackedMap<k,v>, start-idx : int, key : k) : maybe<int>
  val cmp-key = m.keyCmp

  list(0, m.occupied.length)
    .zip(m.occupied.list)
    .zip(m.keys.list)
    .find-maybe(fn(((i,o),ki))
      if i >=start-idx && (o == False || cmp-key(key,ki)) then Just(start-idx)
      else Nothing
    )

pub fun insert(m : arrayBackedMap<k,v>, key : k, x : v) : <div> arrayBackedMap<k,v>
  val resized-m = if m.has-unoccupied-slot
    then m
    else m.resize

  val hash-func = resized-m.hashFunc
  val hash-idx = hash-func(key) % resized-m.occupied.length
  val insert-idx = match find-unoccupied-slot(resized-m, hash-idx, key)
    Just(idx) -> idx
    Nothing -> 0

  fun get-new-members(i)
    if i == insert-idx then x
    else 
      match resized-m.members.at(i)
        Just(s) -> s
        Nothing -> resized-m.default-val

  fun get-new-keys(i)
    if i == insert-idx then key
    else 
      match resized-m.keys.at(i)
        Just(s) -> s
        Nothing -> resized-m.default-key

  fun get-new-occupied(i)
    if i == insert-idx then True
    else 
      match resized-m.occupied.at(i)
        Just(s) -> s
        Nothing -> False

  val updated-occupied = vector-init(resized-m.occupied.length, get-new-occupied)
  val updated-keys = vector-init(resized-m.keys.length, get-new-keys)
  val updated-members = vector-init(resized-m.members.length, get-new-members)
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
  
pub fun delete(m : arrayBackedMap<k,v>, key : k) : arrayBackedMap<k,v>
  m

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

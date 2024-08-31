/*-----------------------------------------------------------------------------
  Flat array backed hashmap

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module map/arrayBacked

import std/num/int64

pub value struct arrayBackedMap<k,v>
  hashFunc : k -> int
  members : vector<maybe<v>>

// Create a new map
pub fun create-map(hashFunc)
  ArrayBackedMap(hashFunc, vector())

// Basic operations

pub fun insert(m : arrayBackedMap<k,v>, key : k, x : v) : arrayBackedMap<k,v>
  val hash-func = m.hashFunc
  val idx = hash-func(key)
  
  val new-size = max(idx + 1, m.members.length)

  fun get-new-members(i)
    if i == idx then Just(x)
    else 
      match m.members.at(idx)
        Nothing -> Nothing
        Just(s) ->
          match s
            Nothing -> Nothing
            Just(sv) -> Just(sv)

  val updated-members = vector-init(new-size, get-new-members)
  m(members = updated-members)

pub fun lookup(m : arrayBackedMap<k,v>, key : k) : maybe<v>
  val hash-func = m.hashFunc
  val idx = hash-func(key)

  val stored = m.members.at(idx)
  match stored
    Just(x) ->
      match x
        Just(x) -> Just(x)
        Nothing -> Nothing
    Nothing -> Nothing
  
pub fun delete(m : arrayBackedMap<k,v>, key : k) : arrayBackedMap<k,v>
  m

// Traversal operations

// TODO: The Haskell function can take type a and transform it to type b. That
// probably works because it can enforce that b is Hashable. Can we do
// something like that?

pub fun map(m : arrayBackedMap<k,v>, f : v -> v) : arrayBackedMap<k,v>
  m

pub fun map-with-key(m : arrayBackedMap<k,v>, f : (k, v) -> v ) : arrayBackedMap<k,v>
  m

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

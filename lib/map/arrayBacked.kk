/*-----------------------------------------------------------------------------
  Flat array backed hashmap

  Operations based on
  https://hackage.haskell.org/package/containers-0.5.10.2/docs/Data-Map-Strict.html
-----------------------------------------------------------------------------*/

module lib/map/arrayBacked

import lib/util/misc

import std/num/int64

// TODO: Instead of storing separate bitvector, use maybe type?

// TODO: Add an option to disable resizing

//type mapMember<k,v>
pub type mapMember<k,v>
  Unoccupied
  Occupied(key: k, value: v)

pub struct arrayBackedMap<k,v>
  hashFunc : k -> int
  keyCmp : (k,k) -> bool
  allow-resize : bool
  members: vector<mapMember<k,v>>

// Create a new map
pub fun create-map(hashFunc : k -> int,
                   keyCmp : (k,k) -> bool,
                   initial-capacity : int = 32,
                   allow-resize : bool = True) : arrayBackedMap<k,v>
  ArrayBackedMap(
    hashFunc,
    keyCmp,
    allow-resize,
    vector/vector(initial-capacity, Unoccupied)
  )

fun insert-unoccupied( mems : list<(mapMember<k,v>, int)>,
                       curr-hash : int = 0,
                       inserted : list<(mapMember<k,v>, int)> = [] ) : _e list<(mapMember<k,v>, int)>
  match mems
    Nil -> inserted
    Cons((mem, next-hash), tail) ->
      if curr-hash < next-hash then
        insert-unoccupied(mems, curr-hash + 1, inserted ++ [(Unoccupied,curr-hash)])
      else if curr-hash == next-hash then
        insert-unoccupied(tail, curr-hash + 1, inserted ++ [(mem,next-hash)])
      else
        insert-unoccupied(tail, curr-hash, inserted ++ [(mem,next-hash)])

pub fun create-map-batch(vals : list<(k,v)>,
                         hashFunc : k -> int,
                         keyCmp : (k,k) -> bool,
                         initial-capacity : int = 32,
                         allow-resize : bool = True) : <exn,div> arrayBackedMap<k,v>
  val capacity = max(vals.length, initial-capacity)
  if capacity > initial-capacity && allow-resize == False then
    throw("resized when resizing is disabled")
  else
    val members = vals
      .map(fn((k,v)) ( Occupied(k, v), hashFunc(k) ))
      .sort()
      .insert-unoccupied()
      .map(fn((m, _)) m)
      .vector

    ArrayBackedMap(
      hashFunc,
      keyCmp,
      allow-resize,
      members
    )

pub fun count(m : arrayBackedMap<k,v>) : int
  m.members.map(fn(mx) if mx.is-unoccupied() then 0 else 1).vlist.sum

fun resize(m : arrayBackedMap<k,v>) : <div,exn> arrayBackedMap<k,v>
  val new-capacity = max(32, m.members.length * 2)
  val new-m = create-map(m.hashFunc, m.keyCmp, new-capacity)

  m.members.vlist.foldl(new-m, fn(m-curr, member)
    match member
      Unoccupied -> m-curr
      Occupied(key, value) -> m-curr.insert(key, value)
  )

// Basic operations

fun find-unoccupied-slot(m : arrayBackedMap<k,v>, start-idx : int, key : k) : <div,exn> int
  val cmp-key = m.keyCmp

  fun find-slot(offset)
    if offset >= m.members.length then -1
    else
      val idx = (start-idx + offset) % m.members.length
      match m.members[idx]
        Unoccupied -> idx
        Occupied(member-key, _) ->
          if cmp-key(key, member-key) then idx
          else find-slot(offset + 1)

  find-slot(0)

pub fun insert(m : arrayBackedMap<k,v>, key : k, x : v) : <div,exn> arrayBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash-idx = hash-func(key) % m.members.length

  val slot = find-unoccupied-slot(m, hash-idx, key)
  val (insert-idx, resized-m) = if slot >= 0 then (slot, m) 
    else if m.allow-resize then
      val resized = m.resize
      val idx = resized.find-unoccupied-slot(hash-idx, key)
      (idx, resized)
    else throw("resized when resizing is disabled")

  val updated-members = vector-init(resized-m.members.length, fn(i)
    if i == insert-idx then Occupied(key, x)
    else resized-m.members[i]
  )

  resized-m(members = updated-members)

pub fun lookup(m : arrayBackedMap<k,v>, key : k) : <div,exn> maybe<v>
  val hash-func = m.hashFunc
  val hash-idx = hash-func(key) % m.members.length

  val k-cmp = m.keyCmp

  fun lookup-at(offset : int)
    if offset >= m.members.length then Nothing
    else
      val idx = (hash-idx + offset) % m.members.length
      match m.members[idx]
        Unoccupied -> Nothing
        Occupied(member-key, value) ->
          if k-cmp(key, member-key) then Just(value)
          else lookup-at( offset + 1)
          
  lookup-at(0)
  
// TODO: What if key isn't present in map?
pub fun delete(m : arrayBackedMap<k,v>, key : k) : <exn,div> arrayBackedMap<k,v>
  val hash-func = m.hashFunc
  val hash-idx = hash-func(key) % m.members.length

  val k-cmp = m.keyCmp

  // TODO: Factor out to something like find?
  fun lookup-at(i : int)
    if i >= m.members.length then Nothing
    else
      match m.members[i]
        Unoccupied -> Nothing
        Occupied(member-key, _) ->
          if k-cmp(key, member-key) then Just(i)
          else lookup-at( i + 1)
 
  val remove-idx-maybe = lookup-at(hash-idx)
  match remove-idx-maybe
    Nothing -> m // TODO: Throw exn here?
    Just(idx) ->
      fun get-new-member(i)
        if i == idx then Unoccupied
        else m.members[i]

      val new-members = vector-init(m.members.length, get-new-member)

      m( members = new-members)
 

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

// pub fun traverse(m : arrayBackedMap<k,v>, f : v -> a, default-value: a) : arrayBackedMap<k,a>
//   fun eval
//   val new-members = m.members.map(f)
//   m

pub fun map-with-key(m: arrayBackedMap<k,v>, f : (k,v) -> e a) : e arrayBackedMap<k,a>
  val new-mems = m.members.map(fn(mem)
    match mem
      Unoccupied -> Unoccupied
      Occupied(ka,va) -> Occupied(ka, f(ka,va))
  )
  ArrayBackedMap(m.hashFunc, m.keyCmp, m.allow-resize, new-mems)

pub fun equals(m1 : arrayBackedMap<k,v>, m2 : arrayBackedMap<k,v>, cmp: (v,v) -> bool) : <div,exn> bool
  val num-occupied-m1 = m1.members.map(fn(m) if m.is-occupied then 1 else 0).vlist.sum()
  val num-occupied-m2 = m2.members.map(fn(m) if m.is-occupied then 1 else 0).vlist.sum()
  if num-occupied-m1 != num-occupied-m2 then False
  else
    val mems-match = m1.members.foreach-while(fn(member-m1)
      match member-m1
        Unoccupied -> Nothing
        Occupied(key, mem) ->
          match m2.lookup(key) 
            Nothing -> Just(True)
            Just(mem-m2) ->
              if mem.cmp(mem-m2) then Nothing
              else Just(True)
    )
    mems-match.is-nothing

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

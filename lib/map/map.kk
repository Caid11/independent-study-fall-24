module lib/map/map

import lib/map/arrayBacked
import lib/map/hamtBacked

pub type map<k,v>
  Array(m: arrayBackedMap<k,v>)
  Hamt(m: hamtBackedMap<k,v>)

pub fun create-array-backed(hashFunc : k -> int,
                            keyCmp : (k,k) -> bool,
                            initial-capacity : int = 32,
                            allow-resize : bool = True) : map<k,v>
  Array(create-map(hashFunc, keyCmp, initial-capacity, allow-resize))

pub fun create-hamt-backed(hashFunc : k -> int, keyCmp : (k,k) -> bool) : map<k,v>
  Hamt(hamtBacked/create-map(hashFunc, keyCmp))

pub fun insert(m : map<k,v>, key : k, x : v) : <div,exn> map<k,v>
  match m
    Array(ma) -> Array(ma.insert(key, x))
    Hamt(mh) -> Hamt(mh.insert(key,x))

pub fun lookup(m : map<k,v>, key : k) : <div,exn> maybe<v>
  match m
    Array(ma) -> ma.lookup(key)
    Hamt(mh) -> mh.lookup(key)

pub fun delete(m : map<k,v>, key : k) : <exn,div> map<k,v>
  match m
    Array(ma) -> Array(ma.delete(key))
    Hamt(mh) -> Hamt(mh.delete(key))

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

pub fun create-array-backed-batch(vals : list<(k,v)>,
                                  hashFunc : k -> int,
                                  keyCmp : (k,k) -> bool,
                                  initial-capacity : int = 32,
                                  allow-resize : bool = True) : <div,exn> map<k,v>
  Array(create-map-batch(vals, hashFunc, keyCmp, initial-capacity, allow-resize))

pub fun create-hamt-backed(hashFunc : k -> int, keyCmp : (k,k) -> bool) : map<k,v>
  Hamt(hamtBacked/create-map(hashFunc, keyCmp))

pub fun count(m : map<k,v>) : <div,exn> int
  match m
    Array(ma) -> ma.arrayBacked/count()
    Hamt(mh) -> mh.count()

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

//pub fun map-with-key(m : map<k,v>, f : ((k,v)) -> e a) : e map<k,a>
pub fun map-with-key(m, f)
  match m
    Array(ma) -> Array(ma.arrayBacked/map-with-key(f))
    Hamt(mh) -> Hamt(mh.hamtBacked/map-with-key(f))

pub fun equals(m1 : map<k,v>, m2 : map<k,v>, cmp : (v,v) -> bool ) : <div,exn> bool
  match m1
    Array(m1a) ->
      match m2
        Array(m2a) -> m1a.arrayBacked/equals(m2a, cmp)
        _ -> False
    Hamt(m1h) ->
      match m2
        Hamt(m2h) -> m1h.hamtBacked/equals(m2h, cmp)
        _ -> False

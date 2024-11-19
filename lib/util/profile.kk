// Below are some utilities to generate Chrome event format traces.
//
// Format details:
// https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU

// Usage: Wrap interesting regions of the code in the "profile" function. This
// will generate prof-evt effects, which can be written to a JSON file and
// viewed in Chrome's trace viewer (open address chrome://tracing in Google Chrome)
//
// Example:
// fun my-cool-func()
//   do-some-work()
//
// var prof-state := create-prof-state( "profile.json ")
//
// fun main()
//   with handler
//     ctl prof-evt( evt ) prof-state := prof-state.handle-evt( evt )
//
//   profile( "my-cool-func", my-cool-func() )
//
//   p.close()

module lib/util/profile

import std/os/process
import std/num/ddouble
import std/time/duration
import std/time/timer

extern import
  c file "prof-inline.c"

// NOTE: Using this drastically slows the program down (by about 1000x), but is
// good to get a rough picture or to profile specific regions.

// Set to True to enable profiling. If False, the profile() function is a no-op.
val prof-enabled = True

type phase
  Begin
  End

// Struct describing profiler event.
struct profEvent
  name : string
  phase : phase
  ts : int

fun ticks-microseconds()
  ticks().nano-seconds / 1000

fun get-prof-evt( name : string, p : phase )
  ProfEvent( name, p, ticks-microseconds() )

fun to-json( e : profEvent ) : string
  val phase-str = match e.phase
    Begin -> "B"
    End -> "E"
  return "{ \"name\": \"" ++ e.name ++ "\", \"cat\": \"PERF\", \"ph\": \"" ++ phase-str ++ "\", \"ts\": " ++ e.ts.show ++ ", \"pid\": 0, \"tid\": 0 },"

pub extern profile-init(path : string) : io ()
  c "kk_profile_init"

pub extern profile-write(evt : string) : io ()
  c "kk_profile_write"

pub extern profile-deinit() : io ()
  c "kk_profile_deinit"

fun prof-emit(name : string, p : phase)
  profile-write(get-prof-evt(name, p).to-json ++ "\n")

pub val profile = 
  if prof-enabled then
    fn( name : string, func )
      prof-emit(name, Begin)
      val res = func()
      prof-emit(name, End)
      res
  else
    fn( name : string, func )
      func()

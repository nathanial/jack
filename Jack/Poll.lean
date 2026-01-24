/-
  Jack Poll Interface
  Non-blocking I/O and poll-based event handling.
-/
import Jack.Socket

namespace Jack

/-- Poll events for socket readiness -/
inductive PollEvent where
  | readable   -- POLLIN
  | writable   -- POLLOUT
  | error      -- POLLERR
  | hangup     -- POLLHUP
  deriving Repr, BEq, Inhabited

namespace PollEvent

/-- Convert to poll flag bit -/
def toBit : PollEvent → UInt16
  | .readable => 0x0001  -- POLLIN
  | .writable => 0x0004  -- POLLOUT
  | .error => 0x0008     -- POLLERR
  | .hangup => 0x0010    -- POLLHUP

/-- Convert array of events to bitmask -/
def arrayToMask (events : Array PollEvent) : UInt16 :=
  events.foldl (· ||| ·.toBit) 0

/-- Convert bitmask to array of events -/
def maskToArray (mask : UInt16) : Array PollEvent := Id.run do
  let mut arr := #[]
  if mask &&& 0x0001 != 0 then arr := arr.push .readable
  if mask &&& 0x0004 != 0 then arr := arr.push .writable
  if mask &&& 0x0008 != 0 then arr := arr.push .error
  if mask &&& 0x0010 != 0 then arr := arr.push .hangup
  return arr

end PollEvent

/-- Entry for multi-socket poll -/
structure PollEntry where
  socket : Socket
  events : Array PollEvent

/-- Result from multi-socket poll -/
structure PollResult where
  socket : Socket
  events : Array PollEvent

namespace Socket

/-- Set socket to non-blocking mode -/
@[extern "jack_socket_set_nonblocking"]
opaque setNonBlocking (sock : @& Socket) (nonBlocking : Bool) : IO Unit

/-- Poll a single socket for events.
    Returns the events that occurred, or empty array on timeout.
    timeoutMs: -1 for infinite wait, 0 for immediate return, >0 for milliseconds -/
@[extern "jack_socket_poll"]
opaque poll (sock : @& Socket) (events : @& Array PollEvent) (timeoutMs : Int32) : IO (Array PollEvent)

end Socket

namespace Poll

/-- Poll multiple sockets for events.
    Returns array of sockets that have events ready.
    timeoutMs: -1 for infinite wait, 0 for immediate return, >0 for milliseconds -/
@[extern "jack_poll_wait"]
opaque wait (entries : @& Array PollEntry) (timeoutMs : Int32) : IO (Array PollResult)

end Poll

end Jack

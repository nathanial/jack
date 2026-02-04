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

/-- Connect using a structured address with a timeout (milliseconds).
    Returns `none` on timeout; socket remains non-blocking. -/
def connectAddrWithTimeout (sock : Socket) (addr : SockAddr) (timeoutMs : Int32) : IO (Option Unit) := do
  sock.setNonBlocking true
  match ← sock.connectAddrTry addr with
  | .ok _ => pure (some ())
  | .error err => throw (IO.userError s!"Socket connect error: {err}")
  | .wouldBlock =>
      let events ← sock.poll #[.writable, .error, .hangup] timeoutMs
      if events.isEmpty then
        return none
      match ← sock.getError with
      | none => pure (some ())
      | some err => throw (IO.userError s!"Socket connect error: {err}")

/-- Accept a connection with a timeout (milliseconds).
    Returns `none` on timeout; socket remains non-blocking. -/
def acceptWithTimeout (sock : Socket) (timeoutMs : Int32) : IO (Option Socket) := do
  sock.setNonBlocking true
  match ← sock.acceptTry with
  | .ok client => pure (some client)
  | .error err => throw (IO.userError s!"Socket accept error: {err}")
  | .wouldBlock =>
      let events ← sock.poll #[.readable, .error, .hangup] timeoutMs
      if events.isEmpty then
        return none
      match ← sock.acceptTry with
      | .ok client => pure (some client)
      | .wouldBlock => pure none
      | .error err => throw (IO.userError s!"Socket accept error: {err}")

/-- Connect to a host and port with a timeout (milliseconds) per address.
    Returns `none` if all candidates time out. -/
def connectHostPortWithTimeout (host : String) (port : UInt16) (timeoutMs : Int32) : IO (Option Socket) := do
  let addrs ← SockAddr.resolveHostPort host port
  if addrs.isEmpty then
    throw (IO.userError s!"No addresses resolved for {host}:{port}")
  let mut lastErr : Option String := none
  for addr in addrs do
    let family? : Option AddressFamily :=
      match addr with
      | .ipv4 _ _ => some .inet
      | .ipv6 _ _ => some .inet6
      | _ => none
    match family? with
    | none => pure ()
    | some family =>
        let sock ← Socket.create family .stream .tcp
        let outcome ← try
          let res ← connectAddrWithTimeout sock addr timeoutMs
          pure (Except.ok res)
        catch e =>
          pure (Except.error (toString e))
        match outcome with
        | .ok (some ()) => return some sock
        | .ok none =>
            Socket.close sock
        | .error msg =>
            lastErr := some msg
            Socket.close sock
  match lastErr with
  | some msg => throw (IO.userError s!"Failed to connect to {host}:{port}: {msg}")
  | none => pure none

end Socket

namespace Poll

/-- Poll multiple sockets for events.
    Returns array of sockets that have events ready.
    timeoutMs: -1 for infinite wait, 0 for immediate return, >0 for milliseconds -/
@[extern "jack_poll_wait"]
opaque wait (entries : @& Array PollEntry) (timeoutMs : Int32) : IO (Array PollResult)

end Poll

end Jack

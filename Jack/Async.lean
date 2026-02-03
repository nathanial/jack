/-
  Jack Async Interface
  Async-friendly API built on non-blocking sockets and Poll.wait.
-/
import Jack.Socket
import Jack.Poll
import Std.Data.HashMap
import Std.Sync.Channel
import Std.Sync.Mutex

namespace Jack

namespace Async

/-- Errors from async wait operations. -/
inductive WaitError where
  | canceled
  | shutdown
  deriving Repr, BEq, Inhabited

structure CancelHandle where
  cancel : IO Unit

private structure Waiter where
  socket : Socket
  events : Array PollEvent
  promise : IO.Promise (Except WaitError (Array PollEvent))

private inductive Command where
  | add (id : UInt64) (waiter : Waiter)
  | cancel (id : UInt64)

private structure Manager where
  chan : Std.CloseableChannel.Sync Command
  nextId : Std.Mutex UInt64
  worker : Task (Except IO.Error Unit)

private structure EntryAgg where
  socket : Socket
  mask : UInt16

private def mergeMasks (a b : UInt16) : UInt16 :=
  a ||| b

private def buildEntries (pending : Std.HashMap UInt64 Waiter) : Array PollEntry := Id.run do
  let mut agg : Std.HashMap UInt32 EntryAgg := {}
  for (_, waiter) in pending.toList do
    let fd := waiter.socket.fd
    let mask := PollEvent.arrayToMask waiter.events
    match agg.get? fd with
    | some entry =>
        agg := agg.insert fd { entry with mask := mergeMasks entry.mask mask }
    | none =>
        agg := agg.insert fd { socket := waiter.socket, mask }
  let mut entries : Array PollEntry := #[]
  for (_, entry) in agg.toList do
    entries := entries.push { socket := entry.socket, events := PollEvent.maskToArray entry.mask }
  return entries

private def handleCommand
    (pending : Std.HashMap UInt64 Waiter)
    (cmd : Command) : IO (Std.HashMap UInt64 Waiter) := do
  match cmd with
  | .add id waiter =>
      return pending.insert id waiter
  | .cancel id =>
      if let some waiter := pending.get? id then
        waiter.promise.resolve (.error .canceled)
      return pending.erase id

private def drainCommands
    (pending : Std.HashMap UInt64 Waiter)
    (chan : Std.CloseableChannel.Sync Command) : IO (Std.HashMap UInt64 Waiter) := do
  let mut pending := pending
  let mut cmd? ← chan.tryRecv
  while cmd?.isSome do
    match cmd? with
    | some cmd =>
        pending ← handleCommand pending cmd
    | none => pure ()
    cmd? ← chan.tryRecv
  return pending

private def resolveReady
    (pending : Std.HashMap UInt64 Waiter)
    (results : Array PollResult) : IO (Std.HashMap UInt64 Waiter) := do
  let mut eventMap : Std.HashMap UInt32 UInt16 := {}
  for res in results do
    let mask := PollEvent.arrayToMask res.events
    eventMap := eventMap.insert res.socket.fd mask
  let mut pending := pending
  for (id, waiter) in pending.toList do
    match eventMap.get? waiter.socket.fd with
    | some mask =>
        let requested := PollEvent.arrayToMask waiter.events
        let matched := mask &&& requested
        if matched != 0 then
          waiter.promise.resolve (.ok (PollEvent.maskToArray matched))
          pending := pending.erase id
    | none => pure ()
  return pending

private def resolveAll
    (pending : Std.HashMap UInt64 Waiter)
    (err : WaitError) : IO Unit := do
  for (_, waiter) in pending.toList do
    waiter.promise.resolve (.error err)

private partial def managerLoop (chan : Std.CloseableChannel.Sync Command) : IO Unit := do
  let rec loop (pending : Std.HashMap UInt64 Waiter) : IO Unit := do
    if pending.isEmpty then
      let cmd? ← chan.recv
      match cmd? with
      | none =>
          resolveAll pending .shutdown
          return ()
      | some cmd =>
          let pending ← handleCommand pending cmd
          loop pending
    else
      let pending ← drainCommands pending chan
      let entries := buildEntries pending
      let results ← Poll.wait entries 100
      let pending ← resolveReady pending results
      loop pending
  loop {}

private def startManager : IO Manager := do
  let chan ← Std.CloseableChannel.Sync.new
  let nextId ← Std.Mutex.new 1
  let worker ← (managerLoop chan).asTask Task.Priority.dedicated
  return { chan, nextId, worker }

initialize managerRef : IO.Ref (Option Manager) ← IO.mkRef none
initialize managerMutex : Std.Mutex Unit ← Std.Mutex.new ()

private def getManager : IO Manager := do
  managerMutex.atomically do
    let current ← managerRef.get
    match current with
    | some m => return m
    | none =>
        let m ← startManager
        managerRef.set (some m)
        return m

/-- Shutdown the async manager and stop background polling. -/
def shutdown : IO Unit := do
  let manager? ← managerMutex.atomically do
    let current ← managerRef.get
    match current with
    | none => return none
    | some m =>
        managerRef.set none
        return some m
  match manager? with
  | none => pure ()
  | some m =>
      try
        let _ ← Std.CloseableChannel.Sync.close m.chan
        let _ := m.worker.get
        pure ()
      catch _ =>
        pure ()

/-- Await events on a socket, returning task and cancellation handle. -/
def awaitEventsCancelable
    (sock : Socket)
    (events : Array PollEvent)
    : IO (Task (Except WaitError (Array PollEvent)) × CancelHandle) := do
  let manager ← getManager
  let id ← manager.nextId.atomically do
    let current ← get
    set (current + 1)
    return current
  let promise : IO.Promise (Except WaitError (Array PollEvent)) ← IO.Promise.new
  let waiter : Waiter := { socket := sock, events := events, promise := promise }
  let _ ← Std.CloseableChannel.Sync.send manager.chan (.add id waiter)
  let cancel : CancelHandle := {
    cancel := do
      let _ ← Std.CloseableChannel.Sync.send manager.chan (.cancel id)
      pure ()
  }
  let task : Task (Except WaitError (Array PollEvent)) := promise.result!
  return (task, cancel)

/-- Await events on a socket. Throws on cancellation/shutdown. -/
def awaitEvents (sock : Socket) (events : Array PollEvent) : IO (Array PollEvent) := do
  let (task, _) ← awaitEventsCancelable sock events
  let result ← IO.wait task
  match result with
  | .ok ev => pure ev
  | .error .canceled =>
      throw (IO.userError "Async wait canceled")
  | .error .shutdown =>
      throw (IO.userError "Async manager shut down")

/-- Await readability (includes error/hangup). -/
def awaitReadable (sock : Socket) : IO (Array PollEvent) :=
  awaitEvents sock #[.readable, .error, .hangup]

/-- Await writability (includes error/hangup). -/
def awaitWritable (sock : Socket) : IO (Array PollEvent) :=
  awaitEvents sock #[.writable, .error, .hangup]

private def ensureNonBlocking (sock : Socket) : IO Unit :=
  sock.setNonBlocking true

/-- Async receive (waits until readable). -/
partial def recvAsync (sock : Socket) (maxBytes : UInt32) : IO ByteArray := do
  ensureNonBlocking sock
  let rec loop : IO ByteArray := do
    match ← sock.recvTry maxBytes with
    | .ok data => pure data
    | .wouldBlock =>
        let _ ← awaitReadable sock
        loop
    | .error err =>
        throw (IO.userError s!"Socket recv error: {err}")
  loop

/-- Async receive from (waits until readable). -/
partial def recvFromAsync (sock : Socket) (maxBytes : UInt32) : IO (ByteArray × SockAddr) := do
  ensureNonBlocking sock
  let rec loop : IO (ByteArray × SockAddr) := do
    match ← sock.recvFromTry maxBytes with
    | .ok value => pure value
    | .wouldBlock =>
        let _ ← awaitReadable sock
        loop
    | .error err =>
        throw (IO.userError s!"Socket recvFrom error: {err}")
  loop

/-- Async send (waits until writable). Returns bytes sent. -/
partial def sendAsync (sock : Socket) (data : ByteArray) : IO UInt32 := do
  ensureNonBlocking sock
  let rec loop : IO UInt32 := do
    match ← sock.sendTry data with
    | .ok n => pure n
    | .wouldBlock =>
        let _ ← awaitWritable sock
        loop
    | .error err =>
        throw (IO.userError s!"Socket send error: {err}")
  loop

/-- Async send to address (waits until writable). Returns bytes sent. -/
partial def sendToAsync (sock : Socket) (data : ByteArray) (addr : SockAddr) : IO UInt32 := do
  ensureNonBlocking sock
  let rec loop : IO UInt32 := do
    match ← sock.sendToTry data addr with
    | .ok n => pure n
    | .wouldBlock =>
        let _ ← awaitWritable sock
        loop
    | .error err =>
        throw (IO.userError s!"Socket sendTo error: {err}")
  loop

/-- Async accept (waits until readable). -/
partial def acceptAsync (sock : Socket) : IO Socket := do
  ensureNonBlocking sock
  let rec loop : IO Socket := do
    match ← sock.acceptTry with
    | .ok client =>
        client.setNonBlocking true
        pure client
    | .wouldBlock =>
        let _ ← awaitReadable sock
        loop
    | .error err =>
        throw (IO.userError s!"Socket accept error: {err}")
  loop

/-- Async connect using structured address. -/
partial def connectAsync (sock : Socket) (addr : SockAddr) : IO Unit := do
  ensureNonBlocking sock
  let rec loop : IO Unit := do
    match ← sock.connectAddrTry addr with
    | .ok _ => pure ()
    | .wouldBlock =>
        let _ ← awaitWritable sock
        match ← sock.getError with
        | none => pure ()
        | some err =>
            throw (IO.userError s!"Socket connect error: {err}")
    | .error err =>
        throw (IO.userError s!"Socket connect error: {err}")
  loop

/-- Async connect using string host/port. -/
partial def connectAsyncHost (sock : Socket) (host : String) (port : UInt16) : IO Unit := do
  ensureNonBlocking sock
  let rec loop : IO Unit := do
    match ← sock.connectTry host port with
    | .ok _ => pure ()
    | .wouldBlock =>
        let _ ← awaitWritable sock
        match ← sock.getError with
        | none => pure ()
        | some err =>
            throw (IO.userError s!"Socket connect error: {err}")
    | .error err =>
        throw (IO.userError s!"Socket connect error: {err}")
  loop

end Async

end Jack

# Jack

BSD socket bindings for Lean 4.

## Features

- TCP client/server sockets
- UDP datagram sockets
- IPv4 and IPv6 support
- Unix domain sockets (including Linux abstract namespace)
- Non-blocking I/O + poll support
- Async-friendly API built on poll
- Socket options (SO_REUSEADDR, TCP_NODELAY, etc.)
- Scatter/gather I/O (`sendmsg`/`recvmsg`)
- Zero-copy-ish file transfer (`sendFile`) with fallback
- Out-of-band (urgent) data helpers

## Quick Start

```lean
import Jack

def main : IO Unit := do
  let socket ← Socket.create .inet .stream .tcp
  socket.connect "127.0.0.1" 8080
  socket.send "Hello, World!".toUTF8
  let response ← socket.recv 1024
  socket.close
```

## API Overview

### Errors

`Jack.SocketError` provides structured error tags. Helper predicates:

- `SocketError.isRetryable`
- `SocketError.isConnectionLost`

### Addressing

`SockAddr` is a sum type:

- `.ipv4 (addr : IPv4Addr) (port : UInt16)`
- `.ipv6 (bytes : ByteArray) (port : UInt16)`
- `.unix (path : String)`
- `.unixAbstract (name : String)` (Linux)

Common constructors:

- `SockAddr.ipv4Any`, `SockAddr.ipv4Loopback`
- `SockAddr.ipv6Any`, `SockAddr.ipv6Loopback`
- `SockAddr.unix`, `SockAddr.unixAbstract`

### Socket Creation

- `Socket.new` — convenience TCP/IPv4 socket
- `Socket.create (family) (sockType) (protocol)`
- `Socket.pair (family) (sockType) (protocol)` — connected sockets

### Connection Lifecycle

- `Socket.connect`, `Socket.connectAddr`
- `Socket.bind`, `Socket.bindAddr`
- `Socket.listen`
- `Socket.accept`
- `Socket.shutdown` — half-close read/write sides
- `Socket.close`

### Send/Recv

- `Socket.recv`, `Socket.send`, `Socket.sendAll`
- UDP: `Socket.sendTo`, `Socket.recvFrom`
- Scatter/gather: `Socket.sendMsg`, `Socket.recvMsg`
- Out-of-band: `Socket.sendOob`, `Socket.recvOob`
- File transfer: `Socket.sendFile path offset count`

### Non-blocking + Poll

- `Socket.setNonBlocking`
- `Socket.poll` (single socket)
- `Poll.wait` (multiple sockets)

### Async-friendly API

`Jack.Async` provides polling-based helpers:

- `recvAsync`, `recvFromAsync`
- `sendAsync`, `sendToAsync`
- `acceptAsync`
- `connectAsync`, `connectAsyncHost`
- `awaitReadable`, `awaitWritable`
- `shutdown` (async manager teardown)

## Tutorial: Chat Server (TCP)

Below is a minimal chat server that broadcasts messages to all clients. This is intentionally small
and single-process; it uses one task per client.

```lean
import Jack
open Jack

def handleClient (sock : Socket) (peers : IO.Ref (Array Socket)) : IO Unit := do
  let rec loop : IO Unit := do
    let msg ← sock.recv 1024
    if msg.size == 0 then
      sock.close
    else
      let peersNow ← peers.get
      for p in peersNow do
        if p.fd != sock.fd then
          p.send msg
      loop
  loop

def main : IO Unit := do
  let server ← Socket.new
  server.bind "127.0.0.1" 9000
  server.listen 16

  let peers ← IO.mkRef (#[] : Array Socket)
  while true do
    let client ← server.accept
    peers.modify (·.push client)
    let _ ← IO.asTask do
      handleClient client peers
```

## Tutorial: HTTP Client Basics

This example performs a basic HTTP/1.1 GET against a local server:

```lean
import Jack
open Jack

def main : IO Unit := do
  let sock ← Socket.create .inet .stream .tcp
  sock.connect "127.0.0.1" 8080
  let request :=
    "GET / HTTP/1.1\r\n" ++
    "Host: 127.0.0.1\r\n" ++
    "Connection: close\r\n" ++
    "\r\n"
  sock.sendAll request.toUTF8
  let response ← sock.recv 4096
  IO.println (String.fromUTF8! response)
  sock.close
```

## Build / Test

```bash
lake build && lake test
```

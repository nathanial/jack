# CLAUDE.md - Jack

BSD socket bindings for Lean 4 with TCP, UDP, IPv4/IPv6, and Unix domain socket support.

## Build / Test

```bash
lake build && lake test
```

## Architecture

Jack wraps POSIX sockets via FFI. The C layer (`ffi/socket.c`) manages socket handles with automatic cleanup.

**Core types:**
- `Socket` - Opaque handle wrapping a file descriptor
- `SockAddr` - Discriminated union: `ipv4`, `ipv6`, `unix`
- `IPv4Addr` - Four-octet address with parsing/formatting
- `SocketError` - Structured error mapping errno values

## Module Structure

| Module | Purpose |
|--------|---------|
| `Jack.Socket` | Socket operations: create, bind, listen, accept, connect, send, recv |
| `Jack.Address` | `IPv4Addr` and `SockAddr` types with constructors |
| `Jack.Types` | Enums: `AddressFamily`, `SocketType`, `Protocol` |
| `Jack.Poll` | Non-blocking I/O with `poll()` for single/multiple sockets |
| `Jack.Error` | `SocketError` enum with `isRetryable`, `isConnectionLost` helpers |

## Socket API

```lean
-- TCP
let sock ← Socket.new                           -- Create TCP socket
sock.bind "127.0.0.1" 8080                      -- Bind to address
sock.listen 5                                    -- Start listening
let client ← sock.accept                         -- Accept connection
let data ← client.recv 1024                      -- Receive data
client.send "response".toUTF8                    -- Send data
sock.close                                       -- Close socket

-- Structured addresses
sock.bindAddr (SockAddr.ipv4Loopback 8080)
sock.connectAddr addr

-- UDP
let udp ← Socket.create .inet .dgram .udp
udp.sendTo data (SockAddr.ipv4 ip port)
let (data, fromAddr) ← udp.recvFrom 1024

-- Non-blocking I/O
sock.setNonBlocking true
let events ← sock.poll #[.readable, .writable] 1000  -- 1s timeout
let results ← Poll.wait entries timeoutMs             -- Multiple sockets

-- Async-friendly API (poll-based)
let _ ← Jack.Async.recvAsync sock 1024
let _ ← Jack.Async.sendAsync sock "hello".toUTF8
```

## FFI Pattern

Socket handles use the external class pattern with automatic finalization:

```c
// Registration
g_socket_class = lean_register_external_class(jack_socket_finalizer, jack_socket_foreach);

// Boxing/unboxing
lean_alloc_external(g_socket_class, sock);
(jack_socket_t *)lean_get_external_data(obj);
```

Errors map errno to `SocketError` enum or wrap in `IO.Error.userError`.

## Dependencies

- `crucible` - Test framework

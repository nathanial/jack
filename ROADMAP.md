# Jack Roadmap

Development plan for BSD socket bindings in Lean 4.

## Current Status

Jack provides working IPv4/IPv6 TCP and UDP socket bindings used in production by Citadel (HTTP server). Includes structured address types, error handling, and poll-based non-blocking I/O.

## Phase 1: Core Types and FFI Foundation

- [x] Define socket handle type (opaque FFI pointer)
- [x] Address family enum (`AF_INET`, `AF_INET6`, `AF_UNIX`)
- [x] Socket type enum (`SOCK_STREAM`, `SOCK_DGRAM`)
- [x] Protocol enum (`IPPROTO_TCP`, `IPPROTO_UDP`)
- [x] Error types mapping errno values (`SocketError`)
- [x] Basic C FFI scaffolding with proper finalizers

## Phase 2: IPv4 TCP Client

- [x] `Socket.new` - create socket file descriptor
- [x] `Socket.create` - create socket with family/type/protocol
- [x] `Socket.connect` - connect to remote host (string address)
- [x] `Socket.connectAddr` - connect using structured address
- [x] `Socket.send` - send bytes
- [x] `Socket.sendAll` - send all bytes (loop until complete)
- [x] `Socket.recv` - receive bytes into buffer
- [x] `Socket.close` - close and cleanup
- [x] Address parsing (`IPv4Addr.parse`) and structured addresses (`SockAddr`)
- [x] Integration tests with local echo server

## Phase 3: TCP Server

- [x] `Socket.bind` - bind to local address/port (string)
- [x] `Socket.bindAddr` - bind using structured address
- [x] `Socket.listen` - mark socket as passive
- [x] `Socket.accept` - accept incoming connection
- [x] `Socket.getLocalAddr` - get local bound address
- [x] `Socket.getPeerAddr` - get remote peer address
- [x] Echo server integration test

## Phase 4: UDP Support

- [x] `Socket.sendTo` - send datagram to address
- [x] `Socket.recvFrom` - receive datagram with source address
- [x] UDP send/recv tests
- [x] UDP roundtrip test

## Phase 5: IPv6 Support

- [x] `SockAddr.ipv6` variant (16-byte address)
- [x] FFI support for `sockaddr_in6`
- [x] Dual-stack socket option (`IPV6_V6ONLY`)
- [x] Address parsing for IPv6
- [x] Tests for IPv6 connectivity

## Phase 6: Socket Options

- [x] `Socket.setOption` / `Socket.getOption` generic interface
- [x] `SO_REUSEADDR` - address reuse (set by default in `new`)
- [x] `SO_REUSEPORT` - port reuse
- [x] `SO_KEEPALIVE` - TCP keepalive
- [x] `SO_RCVBUF` / `SO_SNDBUF` - buffer sizes
- [x] `TCP_NODELAY` - disable Nagle's algorithm
- [x] `SO_LINGER` - linger on close
- [x] `Socket.setTimeout` - recv/send timeouts

## Phase 7: Non-blocking I/O

- [x] `Socket.setNonBlocking` - set O_NONBLOCK flag
- [x] `EAGAIN` / `EWOULDBLOCK` handling (via `SocketError.wouldBlock`)
- [x] `Socket.poll` - poll single socket for events
- [x] `Poll.wait` - poll multiple sockets
- [x] `PollEvent` enum (readable, writable, error, hangup)
- [x] Async-friendly API design

## Phase 8: Unix Domain Sockets

- [x] `AF_UNIX` address family enum
- [x] `SockAddr.unix` variant with path
- [x] FFI support for `sockaddr_un`
- [x] Abstract namespace (Linux)
- [x] Unix socket tests

## Phase 9: Advanced Features

- [x] `Socket.shutdown` - half-close connections
- [x] `Socket.sendFile` - zero-copy file transfer (where available)
- [x] Scatter/gather I/O (`sendmsg` / `recvmsg`)
- [x] Socket pair creation
- [x] Out-of-band data

## Phase 10: Documentation and Polish

- [ ] API documentation for all public functions
- [ ] Tutorial: building a chat server
- [ ] Tutorial: HTTP client basics
- [ ] Performance benchmarks
- [ ] Platform compatibility notes (macOS, Linux)

## Implemented API

```lean
-- Jack/Error.lean
inductive SocketError where
  | accessDenied | addressInUse | addressNotAvailable
  | connectionRefused | connectionReset | connectionAborted
  | networkUnreachable | hostUnreachable | timedOut
  | wouldBlock | interrupted | invalidArgument
  | notConnected | alreadyConnected | badDescriptor
  | permissionDenied | unknown (errno : Int) (message : String)

-- Jack/Types.lean
inductive AddressFamily where | inet | inet6 | unix
inductive SocketType where | stream | dgram
inductive Protocol where | default | tcp | udp

-- Jack/Address.lean
structure IPv4Addr where (a b c d : UInt8)
namespace IPv4Addr
  def parse (s : String) : Option IPv4Addr
  def any : IPv4Addr      -- 0.0.0.0
  def loopback : IPv4Addr -- 127.0.0.1

inductive SockAddr where
  | ipv4 (addr : IPv4Addr) (port : UInt16)
  | ipv6 (bytes : ByteArray) (port : UInt16)
  | unix (path : String)

-- Jack/Socket.lean
namespace Jack.Socket
  opaque new : IO Socket
  opaque create (family : AddressFamily) (sockType : SocketType) (protocol : Protocol) : IO Socket
  opaque connect (sock : @& Socket) (host : @& String) (port : UInt16) : IO Unit
  opaque connectAddr (sock : @& Socket) (addr : @& SockAddr) : IO Unit
  opaque bind (sock : @& Socket) (host : @& String) (port : UInt16) : IO Unit
  opaque bindAddr (sock : @& Socket) (addr : @& SockAddr) : IO Unit
  opaque listen (sock : @& Socket) (backlog : UInt32) : IO Unit
  opaque accept (sock : @& Socket) : IO Socket
  opaque recv (sock : @& Socket) (maxBytes : UInt32) : IO ByteArray
  opaque send (sock : @& Socket) (data : @& ByteArray) : IO Unit
  opaque close (sock : Socket) : IO Unit
  opaque fd (sock : @& Socket) : UInt32
  opaque setTimeout (sock : @& Socket) (timeoutSecs : UInt32) : IO Unit
  opaque getLocalAddr (sock : @& Socket) : IO SockAddr
  opaque getPeerAddr (sock : @& Socket) : IO SockAddr
  opaque sendTo (sock : @& Socket) (data : @& ByteArray) (addr : @& SockAddr) : IO Unit
  opaque recvFrom (sock : @& Socket) (maxBytes : UInt32) : IO (ByteArray × SockAddr)
  opaque setNonBlocking (sock : @& Socket) (nonBlocking : Bool) : IO Unit
  opaque poll (sock : @& Socket) (events : @& Array PollEvent) (timeoutMs : Int32) : IO (Array PollEvent)

-- Jack/Poll.lean
inductive PollEvent where | readable | writable | error | hangup
structure PollEntry where (socket : Socket) (events : Array PollEvent)
structure PollResult where (socket : Socket) (events : Array PollEvent)

namespace Poll
  opaque wait (entries : @& Array PollEntry) (timeoutMs : Int32) : IO (Array PollResult)
```

## Downstream Users

- **Citadel** - HTTP server using Jack for plain TCP sockets (TLS handled separately)

## Future Considerations

- TLS integration (separate library, builds on Jack)
- Higher-level abstractions (connection pools, retry logic)
- io_uring support (Linux)
- kqueue/epoll wrappers for event loops

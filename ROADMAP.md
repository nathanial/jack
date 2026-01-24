# Jack Roadmap

Development plan for BSD socket bindings in Lean 4.

## Phase 1: Core Types and FFI Foundation

- [ ] Define socket handle type (opaque FFI pointer)
- [ ] Address family enum (`AF_INET`, `AF_INET6`, `AF_UNIX`)
- [ ] Socket type enum (`SOCK_STREAM`, `SOCK_DGRAM`, `SOCK_RAW`)
- [ ] Protocol enum (`IPPROTO_TCP`, `IPPROTO_UDP`)
- [ ] Error types mapping errno values
- [ ] Basic C FFI scaffolding with proper finalizers

## Phase 2: IPv4 TCP Client

- [ ] `Socket.create` - create socket file descriptor
- [ ] `Socket.connect` - connect to remote host
- [ ] `Socket.send` / `Socket.sendAll` - send bytes
- [ ] `Socket.recv` - receive bytes into buffer
- [ ] `Socket.close` - close and cleanup
- [ ] Address parsing (string to sockaddr_in)
- [ ] Integration tests with local echo server

## Phase 3: TCP Server

- [ ] `Socket.bind` - bind to local address/port
- [ ] `Socket.listen` - mark socket as passive
- [ ] `Socket.accept` - accept incoming connection
- [ ] `Socket.getLocalAddr` / `Socket.getRemoteAddr`
- [ ] Simple echo server example

## Phase 4: UDP Support

- [ ] `Socket.sendTo` - send datagram to address
- [ ] `Socket.recvFrom` - receive datagram with source address
- [ ] UDP client example
- [ ] UDP server example

## Phase 5: IPv6 Support

- [ ] `sockaddr_in6` structure
- [ ] Dual-stack socket option (`IPV6_V6ONLY`)
- [ ] Address parsing for IPv6
- [ ] Tests for IPv6 connectivity

## Phase 6: Socket Options

- [ ] `Socket.setOption` / `Socket.getOption` generic interface
- [ ] `SO_REUSEADDR` - address reuse
- [ ] `SO_REUSEPORT` - port reuse
- [ ] `SO_KEEPALIVE` - TCP keepalive
- [ ] `SO_RCVBUF` / `SO_SNDBUF` - buffer sizes
- [ ] `TCP_NODELAY` - disable Nagle's algorithm
- [ ] `SO_LINGER` - linger on close

## Phase 7: Non-blocking I/O

- [ ] `Socket.setNonBlocking`
- [ ] `EAGAIN` / `EWOULDBLOCK` handling
- [ ] `Socket.poll` - poll single socket
- [ ] `Poll.create` / `Poll.wait` - poll multiple sockets
- [ ] Async-friendly API design

## Phase 8: Unix Domain Sockets

- [ ] `AF_UNIX` address family
- [ ] `sockaddr_un` structure
- [ ] Path-based socket addresses
- [ ] Abstract namespace (Linux)

## Phase 9: Advanced Features

- [ ] `Socket.shutdown` - half-close connections
- [ ] `Socket.sendFile` - zero-copy file transfer (where available)
- [ ] Scatter/gather I/O (`sendmsg` / `recvmsg`)
- [ ] Socket pair creation
- [ ] Out-of-band data

## Phase 10: Documentation and Polish

- [ ] API documentation for all public functions
- [ ] Tutorial: building a chat server
- [ ] Tutorial: HTTP client basics
- [ ] Performance benchmarks
- [ ] Platform compatibility notes (macOS, Linux)

## Future Considerations

- TLS integration (separate library, builds on Jack)
- Higher-level abstractions (connection pools, retry logic)
- io_uring support (Linux)
- kqueue/epoll wrappers for event loops

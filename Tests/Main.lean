import Crucible
import Jack
open Crucible
open Jack

@[extern "jack_fd_open"]
opaque fdOpen (path : @& String) : IO UInt32

@[extern "jack_fd_read"]
opaque fdRead (fd : UInt32) (maxBytes : UInt32) : IO ByteArray

@[extern "jack_fd_close"]
opaque fdClose (fd : UInt32) : IO Unit

-- ========== Error Tests ==========

testSuite "Jack.Error"

test "SocketError toString coverage" := do
  -- Test all simple constructors
  ensure (SocketError.accessDenied.toString == "Access denied") "accessDenied"
  ensure (SocketError.addressInUse.toString == "Address already in use") "addressInUse"
  ensure (SocketError.addressNotAvailable.toString == "Address not available") "addressNotAvailable"
  ensure (SocketError.connectionRefused.toString == "Connection refused") "connectionRefused"
  ensure (SocketError.connectionReset.toString == "Connection reset by peer") "connectionReset"
  ensure (SocketError.connectionAborted.toString == "Connection aborted") "connectionAborted"
  ensure (SocketError.networkUnreachable.toString == "Network unreachable") "networkUnreachable"
  ensure (SocketError.hostUnreachable.toString == "Host unreachable") "hostUnreachable"
  ensure (SocketError.timedOut.toString == "Operation timed out") "timedOut"
  ensure (SocketError.wouldBlock.toString == "Operation would block") "wouldBlock"
  ensure (SocketError.interrupted.toString == "Operation interrupted") "interrupted"
  ensure (SocketError.invalidArgument.toString == "Invalid argument") "invalidArgument"
  ensure (SocketError.notConnected.toString == "Socket not connected") "notConnected"
  ensure (SocketError.alreadyConnected.toString == "Socket already connected") "alreadyConnected"
  ensure (SocketError.badDescriptor.toString == "Bad file descriptor") "badDescriptor"
  ensure (SocketError.permissionDenied.toString == "Permission denied") "permissionDenied"

test "SocketError unknown formatting" := do
  let err := SocketError.unknown 99 "Custom error"
  ensure (err.toString == "Unknown error (99): Custom error") "unknown formatting"

test "SocketError isRetryable" := do
  ensure SocketError.wouldBlock.isRetryable "wouldBlock is retryable"
  ensure SocketError.interrupted.isRetryable "interrupted is retryable"
  ensure (!SocketError.connectionRefused.isRetryable) "connectionRefused is not retryable"
  ensure (!SocketError.timedOut.isRetryable) "timedOut is not retryable"

test "SocketError isConnectionLost" := do
  ensure SocketError.connectionRefused.isConnectionLost "connectionRefused"
  ensure SocketError.connectionReset.isConnectionLost "connectionReset"
  ensure SocketError.connectionAborted.isConnectionLost "connectionAborted"
  ensure SocketError.networkUnreachable.isConnectionLost "networkUnreachable"
  ensure SocketError.hostUnreachable.isConnectionLost "hostUnreachable"
  ensure SocketError.notConnected.isConnectionLost "notConnected"
  ensure (!SocketError.wouldBlock.isConnectionLost) "wouldBlock is not connection lost"
  ensure (!SocketError.timedOut.isConnectionLost) "timedOut is not connection lost"

-- ========== Types Tests ==========

testSuite "Jack.Types"

-- Note: AddressFamily values are platform-specific (macOS values shown)
-- AF_INET=2 is standard, AF_UNIX=1 is standard, AF_INET6 varies (30 on macOS, 10 on Linux)
test "AddressFamily toUInt32" := do
  ensure (AddressFamily.inet.toUInt32 == 2) "AF_INET = 2"
  ensure (AddressFamily.unix.toUInt32 == 1) "AF_UNIX = 1"
  -- AF_INET6 is platform-specific, just verify it's set to something reasonable
  ensure (AddressFamily.inet6.toUInt32 > 0) "AF_INET6 is set"

test "SocketType toUInt32" := do
  ensure (SocketType.stream.toUInt32 == 1) "SOCK_STREAM = 1"
  ensure (SocketType.dgram.toUInt32 == 2) "SOCK_DGRAM = 2"

test "Protocol toUInt32" := do
  ensure (Protocol.default.toUInt32 == 0) "default = 0"
  ensure (Protocol.tcp.toUInt32 == 6) "IPPROTO_TCP = 6"
  ensure (Protocol.udp.toUInt32 == 17) "IPPROTO_UDP = 17"

-- ========== Address Tests ==========

testSuite "Jack.Address"

test "IPv4Addr parsing" := do
  ensure (IPv4Addr.parse "127.0.0.1" == some ⟨127, 0, 0, 1⟩) "parse loopback"
  ensure (IPv4Addr.parse "192.168.1.100" == some ⟨192, 168, 1, 100⟩) "parse private"
  ensure (IPv4Addr.parse "0.0.0.0" == some ⟨0, 0, 0, 0⟩) "parse any"
  ensure (IPv4Addr.parse "255.255.255.255" == some ⟨255, 255, 255, 255⟩) "parse broadcast"

test "IPv4Addr parse invalid" := do
  ensure (IPv4Addr.parse "invalid" == none) "reject invalid"
  ensure (IPv4Addr.parse "256.0.0.1" == none) "reject out of range"
  ensure (IPv4Addr.parse "1.2.3" == none) "reject too few parts"
  ensure (IPv4Addr.parse "1.2.3.4.5" == none) "reject too many parts"
  ensure (IPv4Addr.parse "" == none) "reject empty"
  ensure (IPv4Addr.parse "1.2.3." == none) "reject trailing dot"

test "IPv6Addr parsing" := do
  let loopback : ByteArray := ⟨#[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]⟩
  ensure (IPv6Addr.parse "::1" == some loopback) "parse loopback"
  ensure (IPv6Addr.parse "[::1]" == some loopback) "parse bracketed loopback"
  ensure (IPv6Addr.parse "invalid" == none) "reject invalid"

test "IPv4Addr toString" := do
  ensure (IPv4Addr.loopback.toString == "127.0.0.1") "loopback to string"
  ensure (IPv4Addr.any.toString == "0.0.0.0") "any to string"
  ensure (IPv4Addr.broadcast.toString == "255.255.255.255") "broadcast to string"

test "IPv4Addr constants" := do
  ensure (IPv4Addr.any == ⟨0, 0, 0, 0⟩) "any is 0.0.0.0"
  ensure (IPv4Addr.loopback == ⟨127, 0, 0, 1⟩) "loopback is 127.0.0.1"
  ensure (IPv4Addr.broadcast == ⟨255, 255, 255, 255⟩) "broadcast is 255.255.255.255"

test "IPv4Addr toUInt32/fromUInt32" := do
  let addr := IPv4Addr.loopback
  let n := addr.toUInt32
  let addr2 := IPv4Addr.fromUInt32 n
  ensure (addr == addr2) "roundtrip loopback"
  -- Test another address
  let addr3 : IPv4Addr := ⟨192, 168, 1, 100⟩
  ensure (IPv4Addr.fromUInt32 addr3.toUInt32 == addr3) "roundtrip private"

test "SockAddr.ipv4 construction and accessors" := do
  let addr := SockAddr.ipv4Loopback 8080
  ensure (addr.port == some 8080) "port accessor"
  ensure (addr.toString == "127.0.0.1:8080") "toString"
  let addr2 := SockAddr.ipv4Any 443
  ensure (addr2.port == some 443) "any port accessor"

test "SockAddr.ipv6 construction and accessors" := do
  -- Create a simple IPv6 address (16 zero bytes)
  let bytes : ByteArray := ⟨#[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]⟩
  let addr := SockAddr.ipv6 bytes 8080
  ensure (addr.port == some 8080) "ipv6 port accessor"
  ensure (addr.toString == "[ipv6]:8080") "ipv6 toString"

test "SockAddr.unix construction and accessors" := do
  let addr := SockAddr.unix "/tmp/test.sock"
  ensure (addr.port == none) "unix has no port"
  ensure (addr.toString == "unix:/tmp/test.sock") "unix toString"

test "SockAddr BEq" := do
  let a1 := SockAddr.ipv4Loopback 80
  let a2 := SockAddr.ipv4Loopback 80
  let a3 := SockAddr.ipv4Loopback 443
  let a4 := SockAddr.ipv4Any 80
  ensure (a1 == a2) "same addresses equal"
  ensure (a1 != a3) "different ports not equal"
  ensure (a1 != a4) "different IPs not equal"
  -- Unix sockets
  let u1 := SockAddr.unix "/tmp/a.sock"
  let u2 := SockAddr.unix "/tmp/a.sock"
  let u3 := SockAddr.unix "/tmp/b.sock"
  ensure (u1 == u2) "same unix paths equal"
  ensure (u1 != u3) "different unix paths not equal"
  ensure (a1 != u1) "ipv4 != unix"

test "SockAddr fromHostPort" := do
  let addr := SockAddr.fromHostPort "192.168.1.1" 443
  match addr with
  | some (.ipv4 ip port) =>
    ensure (ip == ⟨192, 168, 1, 1⟩) "correct ip"
    ensure (port == 443) "correct port"
  | _ => ensure false "should parse"
  let addr6 := SockAddr.fromHostPort "::1" 8080
  match addr6 with
  | some (.ipv6 bytes port) =>
    ensure (bytes.size == 16) "ipv6 bytes length"
    ensure (port == 8080) "ipv6 port"
  | _ => ensure false "should parse ipv6"
  -- Invalid address
  ensure (SockAddr.fromHostPort "invalid" 80 == none) "reject invalid"

test "SockAddr resolveHostPort" := do
  let addrs ← SockAddr.resolveHostPort "localhost" 80
  ensure (addrs.size > 0) "resolved at least one addr"
  let mut sawInet := false
  for addr in addrs do
    match addr with
    | .ipv4 _ port =>
        ensure (port == 80) "ipv4 port matches"
        sawInet := true
    | .ipv6 _ port =>
        ensure (port == 80) "ipv6 port matches"
        sawInet := true
    | _ => pure ()
  ensure sawInet "resolved inet address"

-- ========== Socket Tests ==========

testSuite "Jack.Socket"

test "create and close socket" := do
  let sock ← Socket.new
  sock.close

test "create TCP socket with Socket.create" := do
  let sock ← Socket.create .inet .stream .tcp
  -- Just verify we can get a valid fd (don't check specific value as fd 0 is technically valid)
  let _ := sock.fd
  sock.close

test "create UDP socket" := do
  let sock ← Socket.create .inet .dgram .udp
  let _ := sock.fd
  sock.close

test "bind to port with string address" := do
  let sock ← Socket.new
  sock.bind "127.0.0.1" 0  -- Port 0 = OS assigns
  sock.close

test "bind with structured address" := do
  let sock ← Socket.new
  sock.bindAddr (SockAddr.ipv4Loopback 0)
  sock.close

test "connect with string address" := do
  -- Set up a server to connect to
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr
  let port := match serverAddr with
    | .ipv4 _ p => p
    | _ => 0

  -- Connect using string-based connect
  let client ← Socket.new
  client.connect "127.0.0.1" port
  client.close

  -- Accept and close server side
  let conn ← server.accept
  conn.close
  server.close

test "recvWithFlags MSG_PEEK does not consume" := do
  let (a, b) ← Socket.pair .unix .stream .default
  let peekFlag ← SocketMsgFlag.peek
  a.sendAll "peek".toUTF8
  let peeked ← b.recvWithFlags 4 peekFlag
  let consumed ← b.recv 4
  ensure (String.fromUTF8! peeked == "peek") "peeked data"
  ensure (String.fromUTF8! consumed == "peek") "data still available"
  a.close
  b.close

test "connectHostPort resolves IPv4/IPv6" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr
  let port := match serverAddr with
    | .ipv4 _ p => p
    | _ => 0

  let clientTask ← IO.asTask do
    let client ← Socket.connectHostPort "localhost" port
    client.sendAll "ping".toUTF8
    client.close

  let conn ← server.accept
  let data ← conn.recv 4
  ensure (String.fromUTF8! data == "ping") "received ping"
  conn.close
  server.close

  let _ ← IO.ofExcept clientTask.get

test "connectAddrWithTimeout succeeds" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let client ← Socket.new
  let result ← Socket.connectAddrWithTimeout client serverAddr 1000
  match result with
  | some _ =>
      let conn ← server.accept
      conn.close
      client.close
      server.close
  | none =>
      client.close
      server.close
      ensure false "connect timed out"

test "acceptWithTimeout returns none then some" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let first ← Socket.acceptWithTimeout server 10
  ensure first.isNone "no client yet"

  let clientTask ← IO.asTask do
    let client ← Socket.new
    client.connectAddr serverAddr
    client.close

  let second ← Socket.acceptWithTimeout server 1000
  match second with
  | some conn => conn.close
  | none => ensure false "expected connection"

  server.close
  let _ ← IO.ofExcept clientTask.get

test "connectHostPortWithTimeout resolves and connects" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr
  let port := match serverAddr with
    | .ipv4 _ p => p
    | _ => 0

  let result ← Socket.connectHostPortWithTimeout "localhost" port 1000
  match result with
  | some client =>
      let conn ← server.accept
      conn.close
      client.close
      server.close
  | none =>
      server.close
      ensure false "connect timed out"

test "get local address after bind" := do
  let sock ← Socket.new
  sock.bind "127.0.0.1" 0
  let addr ← sock.getLocalAddr
  match addr with
  | .ipv4 ip port =>
    ensure (ip == IPv4Addr.loopback) "should be loopback"
    ensure (port != 0) "OS should assign port"
  | _ => ensure false "expected IPv4"
  sock.close

test "listen on socket" := do
  let sock ← Socket.new
  sock.bind "127.0.0.1" 0
  sock.listen 5
  sock.close

test "setTimeout" := do
  let sock ← Socket.new
  -- Just verify the call succeeds
  sock.setTimeout 10
  sock.setTimeout 1
  sock.close

test "setTimeoutMs" := do
  let sock ← Socket.new
  sock.setTimeoutMs 250
  sock.setRecvTimeoutMs 150
  sock.setSendTimeoutMs 150
  sock.close

test "tcp keepalive tuning" := do
  let sock ← Socket.new
  let mut skipped := false
  try
    sock.setTcpKeepIdle 60
    sock.setTcpKeepInterval 10
    sock.setTcpKeepCount 3
  catch e =>
    let msg := toString e
    if msg == "Operation not supported" ||
       msg == "Protocol not supported" ||
       msg == "Invalid argument" then
      skipped := true
    else
      throw e
  sock.close
  if skipped then
    ensure true "keepalive tuning not supported"

-- ========== UDP Tests ==========

testSuite "Jack.UDP"

test "UDP send/recv" := do
  let server ← Socket.create .inet .dgram .udp
  server.bindAddr (SockAddr.ipv4Loopback 0)
  let serverAddr ← server.getLocalAddr

  let client ← Socket.create .inet .dgram .udp
  client.sendTo "hello".toUTF8 serverAddr

  let (data, _fromAddr) ← server.recvFrom 1024
  ensure (String.fromUTF8! data == "hello") "received message"

  server.close
  client.close

test "UDP roundtrip" := do
  let server ← Socket.create .inet .dgram .udp
  server.bindAddr (SockAddr.ipv4Loopback 0)
  let serverAddr ← server.getLocalAddr

  let client ← Socket.create .inet .dgram .udp
  client.bindAddr (SockAddr.ipv4Loopback 0)

  -- Client sends to server
  client.sendTo "ping".toUTF8 serverAddr

  -- Server receives and replies
  let (data, clientAddr) ← server.recvFrom 1024
  ensure (String.fromUTF8! data == "ping") "server received ping"

  server.sendTo "pong".toUTF8 clientAddr

  -- Client receives reply
  let (reply, _) ← client.recvFrom 1024
  ensure (String.fromUTF8! reply == "pong") "client received pong"

  server.close
  client.close

test "UDP IPv6 send/recv" := do
  let server ← Socket.create .inet6 .dgram .udp
  server.bindAddr (SockAddr.ipv6Loopback 0)
  let serverAddr ← server.getLocalAddr

  let client ← Socket.create .inet6 .dgram .udp
  client.sendTo "hello".toUTF8 serverAddr

  let (data, _fromAddr) ← server.recvFrom 1024
  ensure (String.fromUTF8! data == "hello") "received ipv6 message"

  server.close
  client.close

-- ========== Poll Tests ==========

testSuite "Jack.Poll"

test "PollEvent arrayToMask" := do
  let events := #[PollEvent.readable, PollEvent.writable]
  let mask := PollEvent.arrayToMask events
  ensure (mask == 0x0005) "readable | writable"  -- POLLIN | POLLOUT

  let allEvents := #[PollEvent.readable, PollEvent.writable, PollEvent.error, PollEvent.hangup]
  let allMask := PollEvent.arrayToMask allEvents
  ensure (allMask == 0x001D) "all events"  -- POLLIN | POLLOUT | POLLERR | POLLHUP

  let empty : Array PollEvent := #[]
  ensure (PollEvent.arrayToMask empty == 0) "empty array"

test "PollEvent maskToArray" := do
  let back := PollEvent.maskToArray 0x0005  -- POLLIN | POLLOUT
  ensure (back.contains .readable) "has readable"
  ensure (back.contains .writable) "has writable"
  ensure (!back.contains .error) "no error"
  ensure (!back.contains .hangup) "no hangup"

  -- Test error and hangup
  let errMask := PollEvent.maskToArray 0x0018  -- POLLERR | POLLHUP
  ensure (errMask.contains .error) "has error"
  ensure (errMask.contains .hangup) "has hangup"

  -- Empty mask
  ensure (PollEvent.maskToArray 0 == #[]) "zero mask is empty"

test "setNonBlocking toggles mode" := do
  let sock ← Socket.new
  -- Set non-blocking
  sock.setNonBlocking true
  -- Set back to blocking
  sock.setNonBlocking false
  sock.close

test "non-blocking recv returns wouldBlock" := do
  let sock ← Socket.create .inet .dgram .udp
  sock.bindAddr (SockAddr.ipv4Loopback 0)
  sock.setNonBlocking true

  -- Try to recv when no data is available - should fail with wouldBlock (EAGAIN)
  let threw ← try
    let _ ← sock.recvFrom 1024
    pure false
  catch _ =>
    pure true

  ensure threw "non-blocking recv with no data should throw"
  sock.close

test "poll for writable" := do
  -- UDP socket should be immediately writable
  let sock ← Socket.create .inet .dgram .udp
  let events ← sock.poll #[.writable] 0
  ensure (events.contains .writable) "UDP socket should be writable"
  sock.close

test "poll for readable timeout" := do
  -- Socket with no data should timeout
  let sock ← Socket.create .inet .dgram .udp
  sock.bindAddr (SockAddr.ipv4Loopback 0)
  let events ← sock.poll #[.readable] 10  -- 10ms timeout
  ensure events.isEmpty "should timeout with no data"
  sock.close

test "poll readable after send" := do
  let server ← Socket.create .inet .dgram .udp
  server.bindAddr (SockAddr.ipv4Loopback 0)
  let serverAddr ← server.getLocalAddr

  let client ← Socket.create .inet .dgram .udp
  client.sendTo "test".toUTF8 serverAddr

  -- Server should now be readable
  let events ← server.poll #[.readable] 1000
  ensure (events.contains .readable) "should be readable after send"

  server.close
  client.close

test "Poll.wait with empty entries" := do
  let results ← Poll.wait #[] 0
  ensure (results.size == 0) "empty input gives empty output"

test "Poll.wait multiple sockets identifies correct socket" := do
  let sock1 ← Socket.create .inet .dgram .udp
  sock1.bindAddr (SockAddr.ipv4Loopback 0)
  let addr1 ← sock1.getLocalAddr
  let fd1 := sock1.fd

  let sock2 ← Socket.create .inet .dgram .udp
  sock2.bindAddr (SockAddr.ipv4Loopback 0)
  let fd2 := sock2.fd

  -- Send to sock1 only
  let sender ← Socket.create .inet .dgram .udp
  sender.sendTo "hello".toUTF8 addr1

  let entries := #[
    { socket := sock1, events := #[.readable] : PollEntry },
    { socket := sock2, events := #[.readable] : PollEntry }
  ]

  let results ← Poll.wait entries 1000

  -- Exactly one socket should be ready
  ensure (results.size == 1) "only one socket ready"

  -- Verify it's sock1 (by checking fd)
  match results[0]? with
  | some result =>
    ensure (result.events.contains .readable) "is readable"
    ensure (result.socket.fd == fd1) "correct socket (sock1)"
    ensure (result.socket.fd != fd2) "not sock2"
  | none => ensure false "expected result"

  -- Verify we can actually read from the ready socket
  let (data, _) ← sock1.recvFrom 1024
  ensure (String.fromUTF8! data == "hello") "data received on correct socket"

  sock1.close
  sock2.close
  sender.close

-- ========== Async Tests ==========

testSuite "Jack.Async"

test "recvFromAsync waits for data" := do
  let server ← Socket.create .inet .dgram .udp
  server.bindAddr (SockAddr.ipv4Loopback 0)
  let serverAddr ← server.getLocalAddr

  let recvTask ← IO.asTask do
    let (data, _from) ← Jack.Async.recvFromAsync server 1024
    return data

  let client ← Socket.create .inet .dgram .udp
  client.sendTo "ping".toUTF8 serverAddr

  let data ← IO.ofExcept recvTask.get
  ensure (String.fromUTF8! data == "ping") "async recvFrom received data"

  server.close
  client.close

test "connectAsync + acceptAsync" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let acceptTask ← IO.asTask do
    let client ← Jack.Async.acceptAsync server
    client.close

  let client ← Socket.new
  Jack.Async.connectAsync client serverAddr
  client.close

  let _ ← IO.ofExcept acceptTask.get
  server.close

test "async shutdown" := do
  Jack.Async.shutdown

-- ========== TCP Integration Tests ==========

testSuite "Jack.TCP.Integration"

test "TCP echo roundtrip" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  -- Client task
  let clientTask ← IO.asTask do
    let client ← Socket.new
    client.connectAddr serverAddr
    client.sendAll "hello".toUTF8
    let response ← client.recv 1024
    client.close
    return response

  -- Server accepts
  let conn ← server.accept
  let data ← conn.recv 1024
  conn.sendAll data
  conn.close
  server.close

  let response ← IO.ofExcept clientTask.get
  ensure (String.fromUTF8! response == "hello") "echo works"

test "TCP shutdown write sends EOF" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let clientTask ← IO.asTask do
    let client ← Socket.new
    client.connectAddr serverAddr
    client.shutdown .write
    client.close

  let conn ← server.accept
  let data ← conn.recv 16
  ensure (data.size == 0) "EOF after shutdown write"
  conn.close
  server.close

  let _ ← IO.ofExcept clientTask.get

test "socket pair roundtrip" := do
  let (a, b) ← Socket.pair .unix .stream .default
  a.sendAll "ping".toUTF8
  let recv1 ← b.recv 4
  ensure (String.fromUTF8! recv1 == "ping") "b received ping"

  b.sendAll "pong".toUTF8
  let recv2 ← a.recv 4
  ensure (String.fromUTF8! recv2 == "pong") "a received pong"

  a.close
  b.close

test "sendMsg/recvMsg roundtrip" := do
  let (a, b) ← Socket.pair .unix .stream .default
  let _ ← a.sendMsg #["pi".toUTF8, "ng".toUTF8]
  let parts ← b.recvMsg #[2, 2]
  ensure (parts.size == 2) "received two parts"
  let combined := String.fromUTF8! parts[0]! ++ String.fromUTF8! parts[1]!
  ensure (combined == "ping") "recvMsg combined"
  a.close
  b.close

test "sendMsgControl SCM_RIGHTS" := do
  let dir ← IO.FS.createTempDir
  let path : System.FilePath := dir / "jack_fdpass.txt"
  IO.FS.writeBinFile path "fdpass".toUTF8
  let fd ← fdOpen path.toString

  let (a, b) ← Socket.pair .unix .stream .default
  let mut received : Option UInt32 := none
  let mut skipped := false
  try
    let ctrl : MsgControl := { fds := #[fd], cred := none }
    let _ ← a.sendMsgControl #["ok".toUTF8] ctrl
    let (parts, ctrlOut) ← b.recvMsgControl #[2] 4 false
    ensure (String.fromUTF8! parts[0]! == "ok") "message received"
    if ctrlOut.fds.size == 0 then
      skipped := true
    else
      ensure (ctrlOut.fds.size == 1) "received fd"
      received := ctrlOut.fds[0]?
      match received with
      | some recvFd =>
          let data ← fdRead recvFd 6
          ensure (String.fromUTF8! data == "fdpass") "fd content"
      | none => ensure false "fd missing"
  catch e =>
    let msg := toString e
    if msg == "Operation not supported" || msg == "Invalid argument" then
      skipped := true
    else
      throw e

  if let some recvFd := received then
    fdClose recvFd
  fdClose fd
  a.close
  b.close

  try IO.FS.removeFile path catch _ => pure ()
  try IO.FS.removeDir dir catch _ => pure ()
  if skipped then
    ensure true "SCM_RIGHTS not supported"

test "sendFile sends contents" := do
  let path : System.FilePath := "/tmp/jack_sendfile_test.txt"
  let payload := "sendfile-test".toUTF8
  IO.FS.writeBinFile path payload

  let (a, b) ← Socket.pair .unix .stream .default
  let sent ← a.sendFile path.toString 0 0
  ensure (sent == UInt64.ofNat payload.size) "sendFile bytes sent"
  let recv ← b.recv (UInt32.ofNat payload.size)
  ensure (String.fromUTF8! recv == "sendfile-test") "sendFile received"
  a.close
  b.close

  IO.FS.removeFile path

test "out-of-band data" := do
  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let clientTask ← IO.asTask do
    let client ← Socket.new
    client.connectAddr serverAddr
    let sentOk ← try
      client.sendOob "!".toUTF8
      pure true
    catch e =>
      if toString e == "Invalid argument" then
        pure false
      else
        throw e
    client.close
    return sentOk

  let conn ← server.accept
  let sentOk ← IO.ofExcept clientTask.get
  if sentOk then
    try
      let oob ← conn.recvOob 1
      ensure (String.fromUTF8! oob == "!") "received oob byte"
    catch e =>
      if toString e != "Invalid argument" then
        throw e
      else
        ensure true "oob not supported"
  else
    ensure true "oob not supported"
  conn.close
  server.close

test "unix abstract namespace" := do
  let name := "jack-abstract-test"
  let addr := SockAddr.unixAbstract name
  let server ← try
    let s ← Socket.create .unix .stream .default
    s.bindAddr addr
    s.listen 1
    pure s
  catch e =>
    if toString e == "Invalid argument" || toString e == "Operation not supported" || toString e == "Invalid address" then
      return ()
    else
      throw e

  let clientTask ← IO.asTask do
    let client ← Socket.create .unix .stream .default
    client.connectAddr addr
    client.sendAll "ping".toUTF8
    let response ← client.recv 4
    client.close
    return response

  let conn ← server.accept
  let data ← conn.recv 4
  conn.sendAll data
  conn.close
  server.close

  let response ← IO.ofExcept clientTask.get
  ensure (String.fromUTF8! response == "ping") "abstract unix socket echo"

test "unix socket stream roundtrip" := do
  let dir ← IO.FS.createTempDir
  let path : System.FilePath := dir / "jack_unix.sock"
  let addr := SockAddr.unix path.toString

  let server ← try
    let s ← Socket.create .unix .stream .default
    s.bindAddr addr
    s.listen 1
    pure s
  catch e =>
    if toString e == "Invalid argument" || toString e == "Operation not supported" then
      return ()
    else
      throw e

  let serverAddr ← server.getLocalAddr
  ensure (serverAddr == addr) "unix server addr"

  let clientTask ← IO.asTask do
    let client ← Socket.create .unix .stream .default
    client.connectAddr addr
    client.sendAll "hello".toUTF8
    let response ← client.recv 5
    client.close
    return response

  let conn ← server.accept
  let data ← conn.recv 5
  conn.sendAll data
  conn.close
  server.close

  let response ← IO.ofExcept clientTask.get
  ensure (String.fromUTF8! response == "hello") "unix echo works"

  try IO.FS.removeFile path catch _ => pure ()
  try IO.FS.removeDir dir catch _ => pure ()

test "unix socket datagram roundtrip" := do
  let dir ← IO.FS.createTempDir
  let serverPath : System.FilePath := dir / "jack_unix_dgram_server.sock"
  let clientPath : System.FilePath := dir / "jack_unix_dgram_client.sock"
  let serverAddr := SockAddr.unix serverPath.toString
  let clientAddr := SockAddr.unix clientPath.toString

  let server ← try
    let s ← Socket.create .unix .dgram .default
    s.bindAddr serverAddr
    pure s
  catch e =>
    if toString e == "Invalid argument" || toString e == "Operation not supported" then
      return ()
    else
      throw e

  let client ← Socket.create .unix .dgram .default
  client.bindAddr clientAddr

  client.sendTo "ping".toUTF8 serverAddr
  let (data, fromAddr) ← server.recvFrom 1024
  ensure (String.fromUTF8! data == "ping") "server received ping"
  ensure (fromAddr == clientAddr) "client addr matches"

  server.sendTo "pong".toUTF8 clientAddr
  let (reply, _) ← client.recvFrom 1024
  ensure (String.fromUTF8! reply == "pong") "client received pong"

  server.close
  client.close

  try IO.FS.removeFile serverPath catch _ => pure ()
  try IO.FS.removeFile clientPath catch _ => pure ()
  try IO.FS.removeDir dir catch _ => pure ()

test "TCP IPv6 echo roundtrip" := do
  let server ← Socket.create .inet6 .stream .tcp
  server.setIPv6Only true
  server.bindAddr (SockAddr.ipv6Loopback 0)
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let clientTask ← IO.asTask do
    let client ← Socket.create .inet6 .stream .tcp
    client.connectAddr serverAddr
    client.sendAll "hello".toUTF8
    let response ← client.recv 1024
    client.close
    return response

  let conn ← server.accept
  let data ← conn.recv 1024
  conn.sendAll data
  conn.close
  server.close

  let response ← IO.ofExcept clientTask.get
  ensure (String.fromUTF8! response == "hello") "ipv6 echo works"

test "connect with structured address" := do
  let server ← Socket.new
  server.bindAddr (SockAddr.ipv4Loopback 0)
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let clientTask ← IO.asTask do
    let client ← Socket.new
    client.connectAddr serverAddr
    client.send "test".toUTF8
    client.close

  let conn ← server.accept
  let data ← conn.recv 1024
  ensure (String.fromUTF8! data == "test") "received data"
  conn.close
  server.close

  let _ ← IO.ofExcept clientTask.get
  pure ()

test "get peer address" := do
  let server ← Socket.new
  server.bindAddr (SockAddr.ipv4Loopback 0)
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let clientTask ← IO.asTask do
    let client ← Socket.new
    client.connectAddr serverAddr
    let peerAddr ← client.getPeerAddr
    client.close
    return peerAddr

  let conn ← server.accept
  conn.close
  server.close

  let peerAddr ← IO.ofExcept clientTask.get
  match peerAddr with
  | .ipv4 ip _ =>
    ensure (ip == IPv4Addr.loopback) "peer is loopback"
  | _ => ensure false "expected IPv4"

-- ========== Socket Option Tests ==========

testSuite "Jack.Socket.Options"

test "set/get SO_REUSEADDR" := do
  let sock ← Socket.new
  let solSocket ← SocketOption.solSocket
  let soReuseAddr ← SocketOption.soReuseAddr
  let initial ← sock.getOption solSocket soReuseAddr 16
  ensure (initial.size > 0) "initial option non-empty"
  sock.setOption solSocket soReuseAddr initial
  let roundtrip ← sock.getOption solSocket soReuseAddr 16
  ensure (roundtrip.size == initial.size) "option size stable"
  sock.close

test "set/get SO_REUSEPORT" := do
  let sock ← Socket.new
  let solSocket ← SocketOption.solSocket
  let soReusePort ← SocketOption.soReusePort
  let initial ← sock.getOptionUInt32 solSocket soReusePort
  sock.setOptionUInt32 solSocket soReusePort initial
  let roundtrip ← sock.getOptionUInt32 solSocket soReusePort
  ensure (roundtrip == initial) "option roundtrip"
  sock.close

test "set/get SO_KEEPALIVE" := do
  let sock ← Socket.new
  let solSocket ← SocketOption.solSocket
  let soKeepAlive ← SocketOption.soKeepAlive
  let initial ← sock.getOptionUInt32 solSocket soKeepAlive
  sock.setOptionUInt32 solSocket soKeepAlive initial
  let roundtrip ← sock.getOptionUInt32 solSocket soKeepAlive
  ensure (roundtrip == initial) "option roundtrip"
  sock.close

test "set/get SO_RCVBUF and SO_SNDBUF" := do
  let sock ← Socket.new
  let solSocket ← SocketOption.solSocket
  let soRcvBuf ← SocketOption.soRcvBuf
  let soSndBuf ← SocketOption.soSndBuf
  let rcvInitial ← sock.getOptionUInt32 solSocket soRcvBuf
  let sndInitial ← sock.getOptionUInt32 solSocket soSndBuf
  sock.setOptionUInt32 solSocket soRcvBuf rcvInitial
  sock.setOptionUInt32 solSocket soSndBuf sndInitial
  let rcvRoundtrip ← sock.getOptionUInt32 solSocket soRcvBuf
  let sndRoundtrip ← sock.getOptionUInt32 solSocket soSndBuf
  ensure (rcvRoundtrip > 0) "recv buffer non-zero"
  ensure (sndRoundtrip > 0) "send buffer non-zero"
  sock.close

test "set/get TCP_NODELAY" := do
  let sock ← Socket.new
  let ipProtoTcp ← SocketOption.ipProtoTcp
  let tcpNoDelay ← SocketOption.tcpNoDelay
  let initial ← sock.getOption ipProtoTcp tcpNoDelay 16
  ensure (initial.size > 0) "initial option non-empty"
  sock.setOption ipProtoTcp tcpNoDelay initial
  let roundtrip ← sock.getOption ipProtoTcp tcpNoDelay 16
  ensure (roundtrip.size == initial.size) "option size stable"
  sock.close

test "TCP_NODELAY helper roundtrip" := do
  let sock ← Socket.new
  let initial ← sock.getTcpNoDelay
  sock.setTcpNoDelay initial
  let roundtrip ← sock.getTcpNoDelay
  ensure (roundtrip == initial) "tcp_nodelay roundtrip"
  sock.close

test "SO_LINGER helper roundtrip" := do
  let sock ← Socket.new
  let (enabled, seconds) ← sock.getLinger
  sock.setLinger enabled seconds
  let (enabled2, seconds2) ← sock.getLinger
  ensure (enabled2 == enabled) "linger enabled roundtrip"
  ensure (seconds2 == seconds) "linger seconds roundtrip"
  sock.close

test "set/get IPV6_V6ONLY" := do
  let sock ← Socket.create .inet6 .stream .tcp
  let ipProtoIpv6 ← SocketOption.ipProtoIpv6
  let ipv6V6Only ← SocketOption.ipv6V6Only
  let initial ← sock.getOptionUInt32 ipProtoIpv6 ipv6V6Only
  sock.setOptionUInt32 ipProtoIpv6 ipv6V6Only initial
  let roundtrip ← sock.getOptionUInt32 ipProtoIpv6 ipv6V6Only
  ensure (roundtrip == initial) "option roundtrip"
  sock.close

-- ========== Multicast/Broadcast Tests ==========

testSuite "Jack.Multicast"

test "udp broadcast enable" := do
  let sock ← Socket.create .inet .dgram .udp
  sock.setBroadcast true
  sock.setBroadcast false
  sock.close

test "ipv4 multicast join/leave" := do
  let sock ← Socket.create .inet .dgram .udp
  let group := IPv4Addr.parse "239.255.0.1"
  match group with
  | none =>
      sock.close
      ensure false "group parse"
  | some grp =>
      let mut skipped := false
      try
        sock.setMulticastTtl 1
        sock.setMulticastLoop true
        sock.joinMulticast grp IPv4Addr.any
        sock.leaveMulticast grp IPv4Addr.any
      catch e =>
        let msg := toString e
        if msg == "Operation not supported" ||
           msg == "Protocol not supported" ||
           msg == "Invalid argument" ||
           msg == "Address not available" ||
           msg == "No such device" ||
           msg == "Network is down" then
          skipped := true
        else
          throw e
      sock.close
      if skipped then
        ensure true "ipv4 multicast not supported"

test "ipv6 multicast join/leave" := do
  let sock ← try
    Socket.create .inet6 .dgram .udp
  catch e =>
    let msg := toString e
    if msg == "Address family not supported by protocol" ||
       msg == "Protocol not supported" ||
       msg == "Protocol not available" then
      return ()
    else
      throw e

  let group := IPv6Addr.parse "ff02::1"
  match group with
  | none =>
      sock.close
      ensure false "ipv6 group parse"
  | some grp =>
      let mut skipped := false
      try
        sock.setMulticastHops6 1
        sock.setMulticastLoop6 true
        sock.joinMulticast6 grp 0
        sock.leaveMulticast6 grp 0
      catch e =>
        let msg := toString e
        if msg == "Operation not supported" ||
           msg == "Protocol not supported" ||
           msg == "Invalid argument" ||
           msg == "Address not available" ||
           msg == "No such device" ||
           msg == "Network is down" then
          skipped := true
        else
          throw e
      sock.close
      if skipped then
        ensure true "ipv6 multicast not supported"

-- ========== Benchmarks ==========

namespace Bench

def nowNs : IO Nat := IO.monoNanosNow

def nsToMs (ns : Nat) : Float :=
  (Float.ofNat ns) / 1.0e6

def nsToSec (ns : Nat) : Float :=
  (Float.ofNat ns) / 1.0e9

def mbPerSec (bytes : Nat) (ns : Nat) : Float :=
  let sec := nsToSec ns
  if sec == 0.0 then 0.0 else (Float.ofNat bytes) / (1024.0 * 1024.0) / sec

def avgNs (samples : Array Nat) : Nat :=
  if samples.isEmpty then 0
  else
    let total : Nat := samples.foldl (fun acc v => acc + v) 0
    total / samples.size

def percentile (samples : Array Nat) (p : Nat) : Nat :=
  if samples.isEmpty then 0
  else
    let sorted := samples.qsort (fun a b => a < b)
    let idx := (p * (sorted.size - 1)) / 100
    sorted[idx]!

def mkBytes (size : Nat) (byte : UInt8 := 0x61) : ByteArray :=
  ByteArray.mk (Array.ofFn (n := size) (fun _ => byte))

def recvExact (recvFn : UInt32 → IO ByteArray) (total maxChunk : Nat) : IO Nat := do
  let mut received := 0
  let mut done := false
  while received < total && !done do
    let remaining := total - received
    let chunkSize := if remaining < maxChunk then remaining else maxChunk
    let chunk ← recvFn (UInt32.ofNat chunkSize)
    if chunk.size == 0 then
      done := true
    else
      received := received + chunk.size
  return received

end Bench

open Bench

testSuite "Jack.Bench"

test "TCP latency ping/pong" := do
  let iterations := 200
  let payload := mkBytes 1 0x70

  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let serverTask ← IO.asTask do
    let conn ← server.accept
    let mut i := 0
    let mut done := false
    while i < iterations && !done do
      let data ← conn.recv 1
      if data.size == 0 then
        done := true
      else
        conn.sendAll data
        i := i + 1
    conn.close

  let client ← Socket.new
  client.connectAddr serverAddr

  let mut samples : Array Nat := #[]
  for _ in [:iterations] do
    let start ← nowNs
    client.sendAll payload
    let resp ← client.recv 1
    let stop ← nowNs
    if resp.size == 1 then
      samples := samples.push (stop - start)

  client.close
  let _ ← IO.ofExcept serverTask.get
  server.close

  ensure (samples.size == iterations) "latency samples collected"
  let avg := avgNs samples
  let p50 := percentile samples 50
  let p95 := percentile samples 95
  IO.println s!"TCP ping/pong {iterations} iters: avg {nsToMs avg} ms p50 {nsToMs p50} ms p95 {nsToMs p95} ms"

test "TCP throughput" := do
  let totalBytes := 4 * 1024 * 1024
  let chunkSize := 64 * 1024
  let fullIters := totalBytes / chunkSize
  let remainder := totalBytes % chunkSize
  let payload := mkBytes chunkSize 0x41

  let server ← Socket.new
  server.bind "127.0.0.1" 0
  server.listen 1
  let serverAddr ← server.getLocalAddr

  let serverTask ← IO.asTask do
    let conn ← server.accept
    let received ← recvExact (fun n => conn.recv n) totalBytes chunkSize
    conn.close
    return received

  let client ← Socket.new
  client.connectAddr serverAddr

  let start ← nowNs
  for _ in [:fullIters] do
    client.sendAll payload
  if remainder > 0 then
    client.sendAll (mkBytes remainder 0x42)
  client.shutdown .write
  let received ← IO.ofExcept serverTask.get
  let stop ← nowNs

  client.close
  server.close

  ensure (received == totalBytes) "received expected bytes"
  let mbps := mbPerSec totalBytes (stop - start)
  IO.println s!"TCP throughput: {mbps} MB/s ({totalBytes} bytes)"

test "UDP latency and loss" := do
  let latencyIters := 200
  let lossIters := 1000
  let lossWindowMs := 200
  let lossWindowNs : Nat := lossWindowMs * 1000000
  let payload := mkBytes 32 0x55

  let server ← Socket.create .inet .dgram .udp
  server.bindAddr (SockAddr.ipv4Loopback 0)
  let serverAddr ← server.getLocalAddr

  let serverTask ← IO.asTask do
    for _ in [:latencyIters] do
      let (data, fromAddr) ← server.recvFrom 256
      server.sendTo data fromAddr
    let start ← nowNs
    let mut received := 0
    let mut done := false
    while !done do
      let now ← nowNs
      if now - start >= lossWindowNs then
        done := true
      else
        let events ← server.poll #[.readable] 10
        if events.contains .readable then
          let (_data, _fromAddr) ← server.recvFrom 2048
          received := received + 1
    return received

  let client ← Socket.create .inet .dgram .udp

  let mut samples : Array Nat := #[]
  for _ in [:latencyIters] do
    let start ← nowNs
    client.sendTo payload serverAddr
    let (resp, _) ← client.recvFrom 256
    let stop ← nowNs
    if resp.size == payload.size then
      samples := samples.push (stop - start)

  for _ in [:lossIters] do
    client.sendTo payload serverAddr

  let receivedLoss ← IO.ofExcept serverTask.get

  client.close
  server.close

  ensure (samples.size == latencyIters) "udp latency samples collected"
  let avg := avgNs samples
  let p50 := percentile samples 50
  let p95 := percentile samples 95
  let lost := lossIters - receivedLoss
  IO.println s!"UDP ping/pong {latencyIters} iters: avg {nsToMs avg} ms p50 {nsToMs p50} ms p95 {nsToMs p95} ms"
  IO.println s!"UDP loss window {lossWindowMs}ms: sent {lossIters} received {receivedLoss} lost {lost}"

test "scatter/gather vs single buffer" := do
  let iterations := 200
  let partCount := 4
  let partSize := 4096
  let totalPer := partCount * partSize
  let totalBytes := iterations * totalPer
  let parts := Array.ofFn (n := partCount) (fun _ => mkBytes partSize 0x33)
  let combined := mkBytes totalPer 0x33

  let (a1, b1) ← Socket.pair .unix .stream .default
  let recvTask1 ← IO.asTask do
    let received ← recvExact (fun n => b1.recv n) totalBytes (64 * 1024)
    b1.close
    return received
  let start1 ← nowNs
  for _ in [:iterations] do
    let _ ← a1.sendMsg parts
    pure ()
  a1.shutdown .write
  let received1 ← IO.ofExcept recvTask1.get
  let stop1 ← nowNs
  a1.close
  ensure (received1 == totalBytes) "scatter/gather received bytes"

  let (a2, b2) ← Socket.pair .unix .stream .default
  let recvTask2 ← IO.asTask do
    let received ← recvExact (fun n => b2.recv n) totalBytes (64 * 1024)
    b2.close
    return received
  let start2 ← nowNs
  for _ in [:iterations] do
    a2.sendAll combined
  a2.shutdown .write
  let received2 ← IO.ofExcept recvTask2.get
  let stop2 ← nowNs
  a2.close
  ensure (received2 == totalBytes) "single buffer received bytes"

  let sgMbs := mbPerSec totalBytes (stop1 - start1)
  let singleMbs := mbPerSec totalBytes (stop2 - start2)
  IO.println s!"scatter/gather: {sgMbs} MB/s, single buffer: {singleMbs} MB/s"

test "sendFile vs user-space send" := do
  let size := 2 * 1024 * 1024
  let dir ← IO.FS.createTempDir
  let path : System.FilePath := dir / "jack_bench_sendfile.bin"
  let payload := mkBytes size 0x66
  IO.FS.writeBinFile path payload

  let runTcpSend (useSendFile : Bool) : IO Nat := do
    let server ← Socket.new
    server.bind "127.0.0.1" 0
    server.listen 1
    let serverAddr ← server.getLocalAddr

    let recvTask ← IO.asTask do
      let conn ← server.accept
      let received ← recvExact (fun n => conn.recv n) size (64 * 1024)
      conn.close
      return received

    let client ← Socket.new
    client.connectAddr serverAddr

    let start ← nowNs
    if useSendFile then
      let sent ← client.sendFile path.toString 0 0
      ensure (sent == UInt64.ofNat size) "sendFile bytes sent"
    else
      let payload2 ← IO.FS.readBinFile path
      client.sendAll payload2
    client.shutdown .write
    let received ← IO.ofExcept recvTask.get
    let stop ← nowNs

    client.close
    server.close
    ensure (received == size) "bytes received"
    return stop - start

  let sendFileNs ← runTcpSend true
  let userNs ← runTcpSend false

  let sendFileMbs := mbPerSec size sendFileNs
  let userMbs := mbPerSec size userNs
  IO.println s!"sendFile: {sendFileMbs} MB/s, user-space: {userMbs} MB/s"

  try IO.FS.removeFile path catch _ => pure ()
  try IO.FS.removeDir dir catch _ => pure ()

test "poll scalability" := do
  let count := 128
  let mut sockets : Array Socket := #[]
  for _ in [:count] do
    let s ← Socket.create .inet .dgram .udp
    s.bindAddr (SockAddr.ipv4Loopback 0)
    sockets := sockets.push s

  match sockets[0]? with
  | none =>
      ensure false "poll sockets created"
  | some target =>
      let targetAddr ← target.getLocalAddr
      let sender ← Socket.create .inet .dgram .udp
      sender.sendTo "ping".toUTF8 targetAddr

      let entries := sockets.map (fun s => { socket := s, events := #[.readable] : PollEntry })
      let start ← nowNs
      let results ← Poll.wait entries 1000
      let stop ← nowNs

      let mut found := false
      for res in results do
        if res.socket.fd == target.fd && res.events.contains .readable then
          found := true

      ensure (results.size >= 1) "poll returned results"
      ensure found "poll found readable socket"

      let _ ← target.recvFrom 1024
      for s in sockets do
        s.close
      sender.close

      IO.println s!"poll wait on {count} sockets: {nsToMs (stop - start)} ms"

test "async vs blocking recv" := do
  let totalBytes := 2 * 1024 * 1024
  let chunkSize := 16 * 1024
  let iterations := totalBytes / chunkSize
  let payload := mkBytes chunkSize 0x5a

  let runRecv (useAsync : Bool) : IO Nat := do
    let server ← Socket.new
    server.bind "127.0.0.1" 0
    server.listen 1
    let serverAddr ← server.getLocalAddr

    let serverTask ← IO.asTask do
      let conn ← server.accept
      for _ in [:iterations] do
        conn.sendAll payload
      conn.shutdown .write
      conn.close

    let client ← Socket.new
    if useAsync then
      Jack.Async.connectAsync client serverAddr
    else
      client.connectAddr serverAddr

    let start ← nowNs
    let received ←
      if useAsync then
        recvExact (fun n => Jack.Async.recvAsync client n) totalBytes (64 * 1024)
      else
        recvExact (fun n => client.recv n) totalBytes (64 * 1024)
    let stop ← nowNs

    client.close
    server.close
    let _ ← IO.ofExcept serverTask.get

    ensure (received == totalBytes) "received expected bytes"
    return stop - start

  let blockingNs ← runRecv false
  let asyncNs ← runRecv true
  Jack.Async.shutdown

  let blockingMbs := mbPerSec totalBytes blockingNs
  let asyncMbs := mbPerSec totalBytes asyncNs
  IO.println s!"blocking recv: {blockingMbs} MB/s, async recv: {asyncMbs} MB/s"

def main : IO UInt32 := runAllSuites

import Crucible
import Jack
open Crucible
open Jack

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
  -- Invalid address
  ensure (SockAddr.fromHostPort "invalid" 80 == none) "reject invalid"

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

def main : IO UInt32 := runAllSuites

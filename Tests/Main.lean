import Crucible
import Jack
open Crucible
open Jack

-- ========== Error Tests ==========

testSuite "Jack.Error"

test "SocketError toString" := do
  ensure (SocketError.connectionRefused.toString == "Connection refused") "connection refused"
  ensure (SocketError.timedOut.toString == "Operation timed out") "timed out"
  ensure (SocketError.wouldBlock.isRetryable) "would block is retryable"

test "SocketError isConnectionLost" := do
  ensure SocketError.connectionReset.isConnectionLost "reset is connection lost"
  ensure SocketError.networkUnreachable.isConnectionLost "network unreachable is connection lost"
  ensure (!SocketError.wouldBlock.isConnectionLost) "would block is not connection lost"

-- ========== Types Tests ==========

testSuite "Jack.Types"

test "AddressFamily toUInt32" := do
  ensure (AddressFamily.inet.toUInt32 == 2) "AF_INET = 2"
  ensure (AddressFamily.inet6.toUInt32 == 30) "AF_INET6 = 30"
  ensure (AddressFamily.unix.toUInt32 == 1) "AF_UNIX = 1"

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

test "IPv4Addr toString" := do
  ensure (IPv4Addr.loopback.toString == "127.0.0.1") "loopback to string"
  ensure (IPv4Addr.any.toString == "0.0.0.0") "any to string"

test "IPv4Addr constants" := do
  ensure (IPv4Addr.any == ⟨0, 0, 0, 0⟩) "any is 0.0.0.0"
  ensure (IPv4Addr.loopback == ⟨127, 0, 0, 1⟩) "loopback is 127.0.0.1"
  ensure (IPv4Addr.broadcast == ⟨255, 255, 255, 255⟩) "broadcast is 255.255.255.255"

test "IPv4Addr toUInt32/fromUInt32" := do
  let addr := IPv4Addr.loopback
  let n := addr.toUInt32
  let addr2 := IPv4Addr.fromUInt32 n
  ensure (addr == addr2) "roundtrip"

test "SockAddr construction" := do
  let addr := SockAddr.ipv4Loopback 8080
  ensure (addr.port == some 8080) "port accessor"
  ensure (addr.toString == "127.0.0.1:8080") "toString"

test "SockAddr fromHostPort" := do
  let addr := SockAddr.fromHostPort "192.168.1.1" 443
  match addr with
  | some (.ipv4 ip port) =>
    ensure (ip == ⟨192, 168, 1, 1⟩) "correct ip"
    ensure (port == 443) "correct port"
  | _ => ensure false "should parse"

-- ========== Socket Tests ==========

testSuite "Jack.Socket"

test "create and close socket" := do
  let sock ← Socket.new
  sock.close

test "create TCP socket with Socket.create" := do
  let sock ← Socket.create .inet .stream .tcp
  let fd := sock.fd
  ensure (fd > 0) "valid fd"
  sock.close

test "create UDP socket" := do
  let sock ← Socket.create .inet .dgram .udp
  let fd := sock.fd
  ensure (fd > 0) "valid fd"
  sock.close

test "bind to port" := do
  let sock ← Socket.new
  sock.bind "127.0.0.1" 0  -- Port 0 = OS assigns
  sock.close

test "bind with structured address" := do
  let sock ← Socket.new
  sock.bindAddr (SockAddr.ipv4Loopback 0)
  sock.close

test "get file descriptor" := do
  let sock ← Socket.new
  let fd := sock.fd
  ensure (fd != 0) "file descriptor should be non-zero"
  sock.close

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

test "PollEvent conversion" := do
  let events := #[PollEvent.readable, PollEvent.writable]
  let mask := PollEvent.arrayToMask events
  ensure (mask == 0x0005) "correct mask"  -- POLLIN | POLLOUT

  let back := PollEvent.maskToArray mask
  ensure (back.contains .readable) "has readable"
  ensure (back.contains .writable) "has writable"

test "set non-blocking" := do
  let sock ← Socket.new
  sock.setNonBlocking true
  sock.setNonBlocking false
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

test "Poll.wait multiple sockets" := do
  let sock1 ← Socket.create .inet .dgram .udp
  sock1.bindAddr (SockAddr.ipv4Loopback 0)
  let addr1 ← sock1.getLocalAddr

  let sock2 ← Socket.create .inet .dgram .udp
  sock2.bindAddr (SockAddr.ipv4Loopback 0)
  let _addr2 ← sock2.getLocalAddr

  -- Send to sock1 only
  let sender ← Socket.create .inet .dgram .udp
  sender.sendTo "hello".toUTF8 addr1

  let entries := #[
    { socket := sock1, events := #[.readable] : PollEntry },
    { socket := sock2, events := #[.readable] : PollEntry }
  ]

  let results ← Poll.wait entries 1000

  -- sock1 should be readable, sock2 should not
  ensure (results.size == 1) "only one socket ready"

  sock1.close
  sock2.close
  sender.close
  -- Verify the ready socket received data
  match results[0]? with
  | some result =>
    ensure (result.events.contains .readable) "sock1 is readable"
  | none => ensure false "expected result"

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
    client.send "hello".toUTF8
    let response ← client.recv 1024
    client.close
    return response

  -- Server accepts
  let conn ← server.accept
  let data ← conn.recv 1024
  conn.send data
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

def main : IO UInt32 := runAllSuites

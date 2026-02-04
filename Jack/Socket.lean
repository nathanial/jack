/-
  Jack Socket FFI
  BSD socket bindings using POSIX sockets.
-/
import Jack.Types
import Jack.Address
import Jack.Error
import Jack.Options

namespace Jack

/-- Unix socket credentials (Linux SCM_CREDENTIALS). -/
structure MsgCred where
  pid : UInt32
  uid : UInt32
  gid : UInt32
  deriving Repr, BEq

/-- Control data for sendmsg/recvmsg (SCM_RIGHTS, SCM_CREDENTIALS). -/
structure MsgControl where
  fds : Array UInt32
  cred : Option MsgCred
  deriving Repr

namespace MsgControl

def empty : MsgControl := { fds := #[], cred := none }

end MsgControl

/-- Opaque TCP socket handle -/
opaque SocketPointed : NonemptyType
def Socket : Type := SocketPointed.type
instance : Nonempty Socket := SocketPointed.property

namespace Socket

/-- Create a new TCP socket (convenience wrapper) -/
@[extern "jack_socket_new"]
opaque new : IO Socket

/-- Create a socket with specified family, type, and protocol -/
@[extern "jack_socket_create"]
opaque create (family : AddressFamily) (sockType : SocketType) (protocol : Protocol) : IO Socket

/-- Create a connected socket pair. -/
@[extern "jack_socket_pair"]
opaque pair (family : AddressFamily) (sockType : SocketType) (protocol : Protocol) : IO (Socket × Socket)

/-- Connect socket to a remote host and port (string address) -/
@[extern "jack_socket_connect"]
opaque connect (sock : @& Socket) (host : @& String) (port : UInt16) : IO Unit

/-- Connect socket to a remote host and port (non-blocking try). -/
@[extern "jack_socket_connect_try"]
opaque connectTry (sock : @& Socket) (host : @& String) (port : UInt16) : IO (SocketResult Unit)

/-- Connect socket using structured address -/
@[extern "jack_socket_connect_addr"]
opaque connectAddr (sock : @& Socket) (addr : @& SockAddr) : IO Unit

/-- Connect socket using structured address (non-blocking try). -/
@[extern "jack_socket_connect_addr_try"]
opaque connectAddrTry (sock : @& Socket) (addr : @& SockAddr) : IO (SocketResult Unit)

/-- Bind socket to an address and port (string address) -/
@[extern "jack_socket_bind"]
opaque bind (sock : @& Socket) (host : @& String) (port : UInt16) : IO Unit

/-- Bind socket using structured address -/
@[extern "jack_socket_bind_addr"]
opaque bindAddr (sock : @& Socket) (addr : @& SockAddr) : IO Unit

/-- Start listening for connections -/
@[extern "jack_socket_listen"]
opaque listen (sock : @& Socket) (backlog : UInt32) : IO Unit

/-- Accept a new connection, returns the client socket -/
@[extern "jack_socket_accept"]
opaque accept (sock : @& Socket) : IO Socket

/-- Accept a new connection (non-blocking try). -/
@[extern "jack_socket_accept_try"]
opaque acceptTry (sock : @& Socket) : IO (SocketResult Socket)

/-- Receive data from socket, up to maxBytes -/
@[extern "jack_socket_recv"]
opaque recv (sock : @& Socket) (maxBytes : UInt32) : IO ByteArray

/-- Receive data from socket (non-blocking try). -/
@[extern "jack_socket_recv_try"]
opaque recvTry (sock : @& Socket) (maxBytes : UInt32) : IO (SocketResult ByteArray)

/-- Receive data from socket with flags (MSG_PEEK, MSG_DONTWAIT, etc.). -/
@[extern "jack_socket_recv_flags"]
opaque recvWithFlags (sock : @& Socket) (maxBytes : UInt32) (flags : UInt32) : IO ByteArray

/-- Send data to socket -/
@[extern "jack_socket_send"]
opaque send (sock : @& Socket) (data : @& ByteArray) : IO Unit

/-- Send data to socket with flags (MSG_NOSIGNAL, MSG_DONTWAIT, etc.). -/
@[extern "jack_socket_send_flags"]
opaque sendWithFlags (sock : @& Socket) (data : @& ByteArray) (flags : UInt32) : IO Unit

/-- Send data to socket (non-blocking try). Returns bytes sent. -/
@[extern "jack_socket_send_try"]
opaque sendTry (sock : @& Socket) (data : @& ByteArray) : IO (SocketResult UInt32)

/-- Send all data to socket, retrying until the full buffer is transmitted -/
@[extern "jack_socket_send_all"]
opaque sendAll (sock : @& Socket) (data : @& ByteArray) : IO Unit

/-- Send file contents to socket using sendfile(). If count=0, sends to EOF. -/
@[extern "jack_socket_send_file"]
opaque sendFile (sock : @& Socket) (path : @& String) (offset : UInt64) (count : UInt64) : IO UInt64

/-- Send data from multiple buffers using sendmsg(). Returns bytes sent. -/
@[extern "jack_socket_send_msg"]
opaque sendMsg (sock : @& Socket) (chunks : @& Array ByteArray) : IO UInt32

/-- Send data with control messages (SCM_RIGHTS, SCM_CREDENTIALS). -/
@[extern "jack_socket_send_msg_control"]
opaque sendMsgControl (sock : @& Socket) (chunks : @& Array ByteArray) (control : @& MsgControl) : IO UInt32

/-- Send data from multiple buffers using sendmsg() with flags. -/
@[extern "jack_socket_send_msg_flags"]
opaque sendMsgWithFlags (sock : @& Socket) (chunks : @& Array ByteArray) (flags : UInt32) : IO UInt32

/-- Receive data into multiple buffers using recvmsg(). -/
@[extern "jack_socket_recv_msg"]
opaque recvMsg (sock : @& Socket) (sizes : @& Array UInt32) : IO (Array ByteArray)

/-- Receive data and control messages (SCM_RIGHTS, SCM_CREDENTIALS). -/
@[extern "jack_socket_recv_msg_control"]
opaque recvMsgControl (sock : @& Socket) (sizes : @& Array UInt32) (maxFds : UInt32) (wantCreds : Bool) : IO (Array ByteArray × MsgControl)

/-- Receive data into multiple buffers using recvmsg() with flags. -/
@[extern "jack_socket_recv_msg_flags"]
opaque recvMsgWithFlags (sock : @& Socket) (sizes : @& Array UInt32) (flags : UInt32) : IO (Array ByteArray)

/-- Send out-of-band data (TCP urgent data). -/
@[extern "jack_socket_send_oob"]
opaque sendOob (sock : @& Socket) (data : @& ByteArray) : IO Unit

/-- Receive out-of-band data (TCP urgent data). -/
@[extern "jack_socket_recv_oob"]
opaque recvOob (sock : @& Socket) (maxBytes : UInt32) : IO ByteArray

/-- Shutdown socket: half-close read/write sides. -/
@[extern "jack_socket_shutdown"]
opaque shutdown (sock : @& Socket) (mode : ShutdownMode) : IO Unit

/-- Close the socket -/
@[extern "jack_socket_close"]
opaque close (sock : Socket) : IO Unit

/-- Connect to a host and port by resolving IPv4/IPv6 addresses.
    Returns a connected socket (TCP). -/
def connectHostPort (host : String) (port : UInt16) : IO Socket := do
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
        let ok ← try
          sock.connectAddr addr
          pure true
        catch e =>
          lastErr := some (toString e)
          Socket.close sock
          pure false
        if ok then
          return sock
  let msg := match lastErr with
    | some m => m
    | none => "No usable addresses"
  throw (IO.userError s!"Failed to connect to {host}:{port}: {msg}")

/-- Get the underlying file descriptor (for debugging) -/
@[extern "jack_socket_fd"]
opaque fd (sock : @& Socket) : UInt32

/-- Set recv/send timeouts in seconds -/
@[extern "jack_socket_set_timeout"]
opaque setTimeout (sock : @& Socket) (timeoutSecs : UInt32) : IO Unit

/-- Set recv/send timeouts in milliseconds -/
@[extern "jack_socket_set_timeout_ms"]
opaque setTimeoutMs (sock : @& Socket) (timeoutMs : UInt32) : IO Unit

/-- Set receive timeout in milliseconds -/
@[extern "jack_socket_set_recv_timeout_ms"]
opaque setRecvTimeoutMs (sock : @& Socket) (timeoutMs : UInt32) : IO Unit

/-- Set send timeout in milliseconds -/
@[extern "jack_socket_set_send_timeout_ms"]
opaque setSendTimeoutMs (sock : @& Socket) (timeoutMs : UInt32) : IO Unit

/-- Set TCP keepalive idle time (seconds). -/
@[extern "jack_socket_set_tcp_keepidle"]
opaque setTcpKeepIdle (sock : @& Socket) (seconds : UInt32) : IO Unit

/-- Set TCP keepalive interval (seconds). -/
@[extern "jack_socket_set_tcp_keepintvl"]
opaque setTcpKeepInterval (sock : @& Socket) (seconds : UInt32) : IO Unit

/-- Set TCP keepalive retry count. -/
@[extern "jack_socket_set_tcp_keepcnt"]
opaque setTcpKeepCount (sock : @& Socket) (count : UInt32) : IO Unit

/-- Set a raw socket option value. The ByteArray is passed as-is to setsockopt. -/
@[extern "jack_socket_set_option"]
opaque setOption (sock : @& Socket) (level : UInt32) (optName : UInt32) (value : @& ByteArray) : IO Unit

/-- Get a raw socket option value. Returns up to maxBytes from getsockopt. -/
@[extern "jack_socket_get_option"]
opaque getOption (sock : @& Socket) (level : UInt32) (optName : UInt32) (maxBytes : UInt32) : IO ByteArray

/-- Set a socket option using a UInt32 value. -/
@[extern "jack_socket_set_option_uint32"]
opaque setOptionUInt32 (sock : @& Socket) (level : UInt32) (optName : UInt32) (value : UInt32) : IO Unit

/-- Get a socket option as a UInt32 value. -/
@[extern "jack_socket_get_option_uint32"]
opaque getOptionUInt32 (sock : @& Socket) (level : UInt32) (optName : UInt32) : IO UInt32

/-- Enable or disable SO_REUSEPORT on a socket. -/
def setReusePort (sock : @& Socket) (enabled : Bool) : IO Unit := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soReusePort
  let value : UInt32 := if enabled then 1 else 0
  sock.setOptionUInt32 level opt value

/-- Check whether SO_REUSEPORT is enabled on a socket. -/
def getReusePort (sock : @& Socket) : IO Bool := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soReusePort
  let value ← sock.getOptionUInt32 level opt
  return value != 0

/-- Enable or disable SO_KEEPALIVE on a socket. -/
def setKeepAlive (sock : @& Socket) (enabled : Bool) : IO Unit := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soKeepAlive
  let value : UInt32 := if enabled then 1 else 0
  sock.setOptionUInt32 level opt value

/-- Check whether SO_KEEPALIVE is enabled on a socket. -/
def getKeepAlive (sock : @& Socket) : IO Bool := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soKeepAlive
  let value ← sock.getOptionUInt32 level opt
  return value != 0

/-- Set the receive buffer size (SO_RCVBUF). -/
def setRecvBuf (sock : @& Socket) (bytes : UInt32) : IO Unit := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soRcvBuf
  sock.setOptionUInt32 level opt bytes

/-- Get the receive buffer size (SO_RCVBUF). -/
def getRecvBuf (sock : @& Socket) : IO UInt32 := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soRcvBuf
  sock.getOptionUInt32 level opt

/-- Set the send buffer size (SO_SNDBUF). -/
def setSendBuf (sock : @& Socket) (bytes : UInt32) : IO Unit := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soSndBuf
  sock.setOptionUInt32 level opt bytes

/-- Get the send buffer size (SO_SNDBUF). -/
def getSendBuf (sock : @& Socket) : IO UInt32 := do
  let level ← SocketOption.solSocket
  let opt ← SocketOption.soSndBuf
  sock.getOptionUInt32 level opt

/-- Enable or disable TCP_NODELAY (disable Nagle's algorithm). -/
def setTcpNoDelay (sock : @& Socket) (enabled : Bool) : IO Unit := do
  let level ← SocketOption.ipProtoTcp
  let opt ← SocketOption.tcpNoDelay
  let value : UInt32 := if enabled then 1 else 0
  sock.setOptionUInt32 level opt value

/-- Check whether TCP_NODELAY is enabled. -/
def getTcpNoDelay (sock : @& Socket) : IO Bool := do
  let level ← SocketOption.ipProtoTcp
  let opt ← SocketOption.tcpNoDelay
  let value ← sock.getOptionUInt32 level opt
  return value != 0

/-- Configure SO_LINGER with enabled flag and linger time in seconds. -/
@[extern "jack_socket_set_linger"]
opaque setLinger (sock : @& Socket) (enabled : Bool) (seconds : UInt32) : IO Unit

/-- Get SO_LINGER settings: (enabled, linger seconds). -/
@[extern "jack_socket_get_linger"]
opaque getLinger (sock : @& Socket) : IO (Bool × UInt32)

/-- Enable or disable IPV6_V6ONLY on an IPv6 socket. -/
def setIPv6Only (sock : @& Socket) (enabled : Bool) : IO Unit := do
  let level ← SocketOption.ipProtoIpv6
  let opt ← SocketOption.ipv6V6Only
  let value : UInt32 := if enabled then 1 else 0
  sock.setOptionUInt32 level opt value

/-- Check whether IPV6_V6ONLY is enabled on an IPv6 socket. -/
def getIPv6Only (sock : @& Socket) : IO Bool := do
  let level ← SocketOption.ipProtoIpv6
  let opt ← SocketOption.ipv6V6Only
  let value ← sock.getOptionUInt32 level opt
  return value != 0

/-- Enable or disable SO_BROADCAST on a socket. -/
@[extern "jack_socket_set_broadcast"]
opaque setBroadcast (sock : @& Socket) (enabled : Bool) : IO Unit

/-- Set IPv4 multicast TTL (IP_MULTICAST_TTL). -/
@[extern "jack_socket_set_multicast_ttl"]
opaque setMulticastTtl (sock : @& Socket) (ttl : UInt8) : IO Unit

/-- Enable or disable IPv4 multicast loopback (IP_MULTICAST_LOOP). -/
@[extern "jack_socket_set_multicast_loop"]
opaque setMulticastLoop (sock : @& Socket) (enabled : Bool) : IO Unit

/-- Join an IPv4 multicast group (IP_ADD_MEMBERSHIP). -/
@[extern "jack_socket_join_multicast"]
opaque joinMulticastRaw (sock : @& Socket) (group : @& IPv4Addr) (iface : @& IPv4Addr) : IO Unit

/-- Leave an IPv4 multicast group (IP_DROP_MEMBERSHIP). -/
@[extern "jack_socket_leave_multicast"]
opaque leaveMulticastRaw (sock : @& Socket) (group : @& IPv4Addr) (iface : @& IPv4Addr) : IO Unit

/-- Join IPv4 multicast group using interface (default 0.0.0.0). -/
def joinMulticast (sock : @& Socket) (group : IPv4Addr) (iface : IPv4Addr := IPv4Addr.any) : IO Unit :=
  joinMulticastRaw sock group iface

/-- Leave IPv4 multicast group using interface (default 0.0.0.0). -/
def leaveMulticast (sock : @& Socket) (group : IPv4Addr) (iface : IPv4Addr := IPv4Addr.any) : IO Unit :=
  leaveMulticastRaw sock group iface

/-- Join an IPv6 multicast group (IPV6_JOIN_GROUP). -/
@[extern "jack_socket_join_multicast6"]
opaque joinMulticast6 (sock : @& Socket) (group : @& ByteArray) (ifIndex : UInt32) : IO Unit

/-- Leave an IPv6 multicast group (IPV6_LEAVE_GROUP). -/
@[extern "jack_socket_leave_multicast6"]
opaque leaveMulticast6 (sock : @& Socket) (group : @& ByteArray) (ifIndex : UInt32) : IO Unit

/-- Set IPv6 multicast hop limit (IPV6_MULTICAST_HOPS). -/
@[extern "jack_socket_set_multicast_hops6"]
opaque setMulticastHops6 (sock : @& Socket) (hops : UInt8) : IO Unit

/-- Enable or disable IPv6 multicast loopback (IPV6_MULTICAST_LOOP). -/
@[extern "jack_socket_set_multicast_loop6"]
opaque setMulticastLoop6 (sock : @& Socket) (enabled : Bool) : IO Unit

/-- Get the local address the socket is bound to -/
@[extern "jack_socket_get_local_addr"]
opaque getLocalAddr (sock : @& Socket) : IO SockAddr

/-- Get the remote peer address (for connected sockets) -/
@[extern "jack_socket_get_peer_addr"]
opaque getPeerAddr (sock : @& Socket) : IO SockAddr

/-- Get pending socket error (SO_ERROR). None if no error. -/
@[extern "jack_socket_get_error"]
opaque getError (sock : @& Socket) : IO (Option SocketError)

/-- Send data to a specific address (UDP) -/
@[extern "jack_socket_send_to"]
opaque sendTo (sock : @& Socket) (data : @& ByteArray) (addr : @& SockAddr) : IO Unit

/-- Send data to a specific address (UDP) with flags. -/
@[extern "jack_socket_send_to_flags"]
opaque sendToWithFlags (sock : @& Socket) (data : @& ByteArray) (addr : @& SockAddr) (flags : UInt32) : IO Unit

/-- Send data to a specific address (UDP, non-blocking try). Returns bytes sent. -/
@[extern "jack_socket_send_to_try"]
opaque sendToTry (sock : @& Socket) (data : @& ByteArray) (addr : @& SockAddr) : IO (SocketResult UInt32)

/-- Receive data and sender address (UDP) -/
@[extern "jack_socket_recv_from"]
opaque recvFrom (sock : @& Socket) (maxBytes : UInt32) : IO (ByteArray × SockAddr)

/-- Receive data and sender address (UDP) with flags. -/
@[extern "jack_socket_recv_from_flags"]
opaque recvFromWithFlags (sock : @& Socket) (maxBytes : UInt32) (flags : UInt32) : IO (ByteArray × SockAddr)

/-- Receive data and sender address (UDP, non-blocking try). -/
@[extern "jack_socket_recv_from_try"]
opaque recvFromTry (sock : @& Socket) (maxBytes : UInt32) : IO (SocketResult (ByteArray × SockAddr))

end Socket

end Jack

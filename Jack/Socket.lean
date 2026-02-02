/-
  Jack Socket FFI
  BSD socket bindings using POSIX sockets.
-/
import Jack.Types
import Jack.Address
import Jack.Error

namespace Jack

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

/-- Connect socket to a remote host and port (string address) -/
@[extern "jack_socket_connect"]
opaque connect (sock : @& Socket) (host : @& String) (port : UInt16) : IO Unit

/-- Connect socket using structured address -/
@[extern "jack_socket_connect_addr"]
opaque connectAddr (sock : @& Socket) (addr : @& SockAddr) : IO Unit

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

/-- Receive data from socket, up to maxBytes -/
@[extern "jack_socket_recv"]
opaque recv (sock : @& Socket) (maxBytes : UInt32) : IO ByteArray

/-- Send data to socket -/
@[extern "jack_socket_send"]
opaque send (sock : @& Socket) (data : @& ByteArray) : IO Unit

/-- Send all data to socket, retrying until the full buffer is transmitted -/
@[extern "jack_socket_send_all"]
opaque sendAll (sock : @& Socket) (data : @& ByteArray) : IO Unit

/-- Close the socket -/
@[extern "jack_socket_close"]
opaque close (sock : Socket) : IO Unit

/-- Get the underlying file descriptor (for debugging) -/
@[extern "jack_socket_fd"]
opaque fd (sock : @& Socket) : UInt32

/-- Set recv/send timeouts in seconds -/
@[extern "jack_socket_set_timeout"]
opaque setTimeout (sock : @& Socket) (timeoutSecs : UInt32) : IO Unit

/-- Set a raw socket option value. The ByteArray is passed as-is to setsockopt. -/
@[extern "jack_socket_set_option"]
opaque setOption (sock : @& Socket) (level : UInt32) (optName : UInt32) (value : @& ByteArray) : IO Unit

/-- Get a raw socket option value. Returns up to maxBytes from getsockopt. -/
@[extern "jack_socket_get_option"]
opaque getOption (sock : @& Socket) (level : UInt32) (optName : UInt32) (maxBytes : UInt32) : IO ByteArray

/-- Get the local address the socket is bound to -/
@[extern "jack_socket_get_local_addr"]
opaque getLocalAddr (sock : @& Socket) : IO SockAddr

/-- Get the remote peer address (for connected sockets) -/
@[extern "jack_socket_get_peer_addr"]
opaque getPeerAddr (sock : @& Socket) : IO SockAddr

/-- Send data to a specific address (UDP) -/
@[extern "jack_socket_send_to"]
opaque sendTo (sock : @& Socket) (data : @& ByteArray) (addr : @& SockAddr) : IO Unit

/-- Receive data and sender address (UDP) -/
@[extern "jack_socket_recv_from"]
opaque recvFrom (sock : @& Socket) (maxBytes : UInt32) : IO (ByteArray × SockAddr)

end Socket

end Jack

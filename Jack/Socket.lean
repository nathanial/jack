/-
  Jack Socket FFI
  BSD socket bindings using POSIX sockets.
-/

namespace Jack

/-- Opaque TCP socket handle -/
opaque SocketPointed : NonemptyType
def Socket : Type := SocketPointed.type
instance : Nonempty Socket := SocketPointed.property

namespace Socket

/-- Create a new TCP socket -/
@[extern "jack_socket_new"]
opaque new : IO Socket

/-- Connect socket to a remote host and port -/
@[extern "jack_socket_connect"]
opaque connect (sock : @& Socket) (host : @& String) (port : UInt16) : IO Unit

/-- Bind socket to an address and port -/
@[extern "jack_socket_bind"]
opaque bind (sock : @& Socket) (host : @& String) (port : UInt16) : IO Unit

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

/-- Close the socket -/
@[extern "jack_socket_close"]
opaque close (sock : Socket) : IO Unit

/-- Get the underlying file descriptor (for debugging) -/
@[extern "jack_socket_fd"]
opaque fd (sock : @& Socket) : UInt32

/-- Set recv/send timeouts in seconds -/
@[extern "jack_socket_set_timeout"]
opaque setTimeout (sock : @& Socket) (timeoutSecs : UInt32) : IO Unit

end Socket

end Jack

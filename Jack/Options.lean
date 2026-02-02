/-
  Jack Socket Option Constants
  Platform-provided socket option identifiers.
-/

namespace Jack

namespace SocketOption

/-- SOL_SOCKET level constant. -/
@[extern "jack_const_sol_socket"]
opaque solSocket : IO UInt32

/-- SO_REUSEADDR socket option. -/
@[extern "jack_const_so_reuseaddr"]
opaque soReuseAddr : IO UInt32

/-- IPPROTO_TCP level constant. -/
@[extern "jack_const_ipproto_tcp"]
opaque ipProtoTcp : IO UInt32

/-- TCP_NODELAY socket option. -/
@[extern "jack_const_tcp_nodelay"]
opaque tcpNoDelay : IO UInt32

end SocketOption

end Jack

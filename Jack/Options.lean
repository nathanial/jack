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

/-- SO_REUSEPORT socket option. -/
@[extern "jack_const_so_reuseport"]
opaque soReusePort : IO UInt32

/-- SO_KEEPALIVE socket option. -/
@[extern "jack_const_so_keepalive"]
opaque soKeepAlive : IO UInt32

/-- IPPROTO_TCP level constant. -/
@[extern "jack_const_ipproto_tcp"]
opaque ipProtoTcp : IO UInt32

/-- TCP_NODELAY socket option. -/
@[extern "jack_const_tcp_nodelay"]
opaque tcpNoDelay : IO UInt32

/-- IPPROTO_IPV6 level constant. -/
@[extern "jack_const_ipproto_ipv6"]
opaque ipProtoIpv6 : IO UInt32

/-- IPV6_V6ONLY socket option. -/
@[extern "jack_const_ipv6_v6only"]
opaque ipv6V6Only : IO UInt32

end SocketOption

end Jack

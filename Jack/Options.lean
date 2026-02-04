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

/-- SO_RCVBUF socket option. -/
@[extern "jack_const_so_rcvbuf"]
opaque soRcvBuf : IO UInt32

/-- SO_SNDBUF socket option. -/
@[extern "jack_const_so_sndbuf"]
opaque soSndBuf : IO UInt32

/-- SO_BROADCAST socket option. -/
@[extern "jack_const_so_broadcast"]
opaque soBroadcast : IO UInt32

/-- IPPROTO_IP level constant. -/
@[extern "jack_const_ipproto_ip"]
opaque ipProtoIp : IO UInt32

/-- IP_MULTICAST_TTL option. -/
@[extern "jack_const_ip_multicast_ttl"]
opaque ipMulticastTtl : IO UInt32

/-- IP_MULTICAST_LOOP option. -/
@[extern "jack_const_ip_multicast_loop"]
opaque ipMulticastLoop : IO UInt32

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

/-- IPV6_MULTICAST_HOPS option. -/
@[extern "jack_const_ipv6_multicast_hops"]
opaque ipv6MulticastHops : IO UInt32

/-- IPV6_MULTICAST_LOOP option. -/
@[extern "jack_const_ipv6_multicast_loop"]
opaque ipv6MulticastLoop : IO UInt32

end SocketOption

namespace SocketMsgFlag

/-- MSG_PEEK flag. -/
@[extern "jack_const_msg_peek"]
opaque peek : IO UInt32

/-- MSG_DONTWAIT flag. -/
@[extern "jack_const_msg_dontwait"]
opaque dontWait : IO UInt32

/-- MSG_WAITALL flag. -/
@[extern "jack_const_msg_waitall"]
opaque waitAll : IO UInt32

/-- MSG_OOB flag. -/
@[extern "jack_const_msg_oob"]
opaque oob : IO UInt32

/-- MSG_NOSIGNAL flag (0 if unsupported). -/
@[extern "jack_const_msg_nosignal"]
opaque noSignal : IO UInt32

end SocketMsgFlag

end Jack

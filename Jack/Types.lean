/-
  Jack Socket Types
  Enums for socket family, type, and protocol.
-/

namespace Jack

/-- Address family for socket creation -/
inductive AddressFamily where
  | inet    -- AF_INET (IPv4)
  | inet6   -- AF_INET6 (IPv6)
  | unix    -- AF_UNIX (local)
  deriving Repr, BEq, Inhabited

namespace AddressFamily

/-- Convert to integer value for FFI -/
def toUInt32 : AddressFamily → UInt32
  | .inet => 2    -- AF_INET
  | .inet6 => 30  -- AF_INET6 (macOS)
  | .unix => 1    -- AF_UNIX

end AddressFamily

/-- Socket type -/
inductive SocketType where
  | stream  -- SOCK_STREAM (TCP)
  | dgram   -- SOCK_DGRAM (UDP)
  deriving Repr, BEq, Inhabited

namespace SocketType

/-- Convert to integer value for FFI -/
def toUInt32 : SocketType → UInt32
  | .stream => 1  -- SOCK_STREAM
  | .dgram => 2   -- SOCK_DGRAM

end SocketType

/-- Protocol for socket creation -/
inductive Protocol where
  | default -- 0 (system default)
  | tcp     -- IPPROTO_TCP
  | udp     -- IPPROTO_UDP
  deriving Repr, BEq, Inhabited

namespace Protocol

/-- Convert to integer value for FFI -/
def toUInt32 : Protocol → UInt32
  | .default => 0
  | .tcp => 6   -- IPPROTO_TCP
  | .udp => 17  -- IPPROTO_UDP

end Protocol

/-- Shutdown mode for half-closing TCP sockets. -/
inductive ShutdownMode where
  | read   -- SHUT_RD
  | write  -- SHUT_WR
  | both   -- SHUT_RDWR
  deriving Repr, BEq, Inhabited

namespace ShutdownMode

/-- Convert to integer value for FFI. -/
def toUInt32 : ShutdownMode → UInt32
  | .read => 0
  | .write => 1
  | .both => 2

end ShutdownMode

end Jack

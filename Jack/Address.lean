/-
  Jack Socket Address Types
  IPv4, IPv6, and Unix domain socket addresses.
-/

namespace Jack

/-- IPv4 address as four octets -/
structure IPv4Addr where
  a : UInt8
  b : UInt8
  c : UInt8
  d : UInt8
  deriving Repr, BEq, Inhabited

namespace IPv4Addr

/-- Parse an IPv4 address string like "192.168.1.1" -/
def parse (s : String) : Option IPv4Addr := do
  let parts := s.splitOn "."
  if parts.length != 4 then none
  else
    let a ← parts[0]?.bind (·.toNat?)
    let b ← parts[1]?.bind (·.toNat?)
    let c ← parts[2]?.bind (·.toNat?)
    let d ← parts[3]?.bind (·.toNat?)
    if a > 255 || b > 255 || c > 255 || d > 255 then none
    else some ⟨a.toUInt8, b.toUInt8, c.toUInt8, d.toUInt8⟩

/-- Convert to dotted-decimal string -/
def toString (addr : IPv4Addr) : String :=
  s!"{addr.a}.{addr.b}.{addr.c}.{addr.d}"

instance : ToString IPv4Addr := ⟨toString⟩

/-- The "any" address 0.0.0.0 (binds to all interfaces) -/
def any : IPv4Addr := ⟨0, 0, 0, 0⟩

/-- The loopback address 127.0.0.1 -/
def loopback : IPv4Addr := ⟨127, 0, 0, 1⟩

/-- The broadcast address 255.255.255.255 -/
def broadcast : IPv4Addr := ⟨255, 255, 255, 255⟩

/-- Convert to 32-bit integer (network byte order) -/
def toUInt32 (addr : IPv4Addr) : UInt32 :=
  addr.a.toUInt32 <<< 24 |||
  addr.b.toUInt32 <<< 16 |||
  addr.c.toUInt32 <<< 8 |||
  addr.d.toUInt32

/-- Create from 32-bit integer (network byte order) -/
def fromUInt32 (n : UInt32) : IPv4Addr :=
  ⟨(n >>> 24).toUInt8,
   (n >>> 16 &&& 0xFF).toUInt8,
   (n >>> 8 &&& 0xFF).toUInt8,
   (n &&& 0xFF).toUInt8⟩

end IPv4Addr

/-- IPv6 address as 16 bytes (network order) -/
abbrev IPv6Addr := ByteArray

namespace IPv6Addr

@[extern "jack_ipv6_parse"]
opaque parseBytes (s : @& String) : ByteArray

private def stripBrackets (s : String) : String :=
  match s.toList with
  | '[' :: rest =>
    match rest.reverse with
    | ']' :: innerRev => String.ofList innerRev.reverse
    | _ => s
  | _ => s

/-- Parse an IPv6 address string like "::1" or "2001:db8::1". -/
def parse (s : String) : Option IPv6Addr :=
  let trimmed := stripBrackets s
  let bytes := parseBytes trimmed
  if bytes.size == 16 then some bytes else none

/-- The "any" address :: (all interfaces). -/
def any : IPv6Addr := ⟨#[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]⟩

/-- The loopback address ::1. -/
def loopback : IPv6Addr := ⟨#[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]⟩

end IPv6Addr

/-- Socket address (IPv4, IPv6, or Unix domain) -/
inductive SockAddr where
  | ipv4 (addr : IPv4Addr) (port : UInt16)
  | ipv6 (bytes : ByteArray) (port : UInt16)  -- 16-byte address
  | unix (path : String)
  | unixAbstract (name : String)

namespace SockAddr

/-- Create IPv4 address bound to any interface -/
def ipv4Any (port : UInt16) : SockAddr := .ipv4 .any port

/-- Create IPv4 loopback address -/
def ipv4Loopback (port : UInt16) : SockAddr := .ipv4 .loopback port

/-- Create IPv6 address bound to any interface -/
def ipv6Any (port : UInt16) : SockAddr := .ipv6 IPv6Addr.any port

/-- Create IPv6 loopback address -/
def ipv6Loopback (port : UInt16) : SockAddr := .ipv6 IPv6Addr.loopback port

/-- Resolve a host and port into concrete socket addresses (IPv4/IPv6). -/
@[extern "jack_resolve_host_port"]
opaque resolveHostPort (host : @& String) (port : UInt16) : IO (Array SockAddr)

/-- Resolve a host into concrete socket addresses with port 0. -/
def resolveHost (host : String) : IO (Array SockAddr) :=
  resolveHostPort host 0

/-- Parse address string and port into SockAddr -/
def fromHostPort (host : String) (port : UInt16) : Option SockAddr :=
  match IPv4Addr.parse host with
  | some addr => some (.ipv4 addr port)
  | none => (IPv6Addr.parse host).map fun bytes => .ipv6 bytes port

/-- Get the port number (if applicable) -/
def port : SockAddr → Option UInt16
  | .ipv4 _ p => some p
  | .ipv6 _ p => some p
  | .unix _ => none
  | .unixAbstract _ => none

/-- Convert to string representation -/
def toString : SockAddr → String
  | .ipv4 addr port => s!"{addr}:{port}"
  | .ipv6 _ port => s!"[ipv6]:{port}"
  | .unix path => s!"unix:{path}"
  | .unixAbstract name => s!"unix:@{name}"

instance : ToString SockAddr := ⟨toString⟩

instance : BEq SockAddr where
  beq a b := match a, b with
    | .ipv4 a1 p1, .ipv4 a2 p2 => a1 == a2 && p1 == p2
    | .ipv6 b1 p1, .ipv6 b2 p2 => b1 == b2 && p1 == p2
    | .unix p1, .unix p2 => p1 == p2
    | .unixAbstract n1, .unixAbstract n2 => n1 == n2
    | _, _ => false

end SockAddr

end Jack

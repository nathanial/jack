/-
  Jack Socket Error Types
  Structured error types mapping errno values.
-/

namespace Jack

/-- Socket error types mapping common errno values -/
inductive SocketError where
  | accessDenied           -- EACCES
  | addressInUse           -- EADDRINUSE
  | addressNotAvailable    -- EADDRNOTAVAIL
  | connectionRefused      -- ECONNREFUSED
  | connectionReset        -- ECONNRESET
  | connectionAborted      -- ECONNABORTED
  | networkUnreachable     -- ENETUNREACH
  | hostUnreachable        -- EHOSTUNREACH
  | timedOut               -- ETIMEDOUT
  | wouldBlock             -- EAGAIN/EWOULDBLOCK
  | interrupted            -- EINTR
  | invalidArgument        -- EINVAL
  | notConnected           -- ENOTCONN
  | alreadyConnected       -- EISCONN
  | badDescriptor          -- EBADF
  | permissionDenied       -- EPERM
  | unknown (errno : Int) (message : String)
  deriving Repr, BEq, Inhabited

/-- Result for non-blocking socket operations. -/
inductive SocketResult (α : Type) where
  | ok (value : α)
  | wouldBlock
  | error (err : SocketError)
  deriving Repr

namespace SocketResult

/-- True if the operation would block (EAGAIN/EWOULDBLOCK/EINPROGRESS). -/
def isWouldBlock : SocketResult α → Bool
  | .wouldBlock => true
  | _ => false

/-- Convert to Except, mapping wouldBlock to SocketError.wouldBlock. -/
def toExcept : SocketResult α → Except SocketError α
  | .ok value => .ok value
  | .wouldBlock => .error .wouldBlock
  | .error err => .error err

end SocketResult

namespace SocketError

/-- Convert SocketError to human-readable string -/
def toString : SocketError → String
  | .accessDenied => "Access denied"
  | .addressInUse => "Address already in use"
  | .addressNotAvailable => "Address not available"
  | .connectionRefused => "Connection refused"
  | .connectionReset => "Connection reset by peer"
  | .connectionAborted => "Connection aborted"
  | .networkUnreachable => "Network unreachable"
  | .hostUnreachable => "Host unreachable"
  | .timedOut => "Operation timed out"
  | .wouldBlock => "Operation would block"
  | .interrupted => "Operation interrupted"
  | .invalidArgument => "Invalid argument"
  | .notConnected => "Socket not connected"
  | .alreadyConnected => "Socket already connected"
  | .badDescriptor => "Bad file descriptor"
  | .permissionDenied => "Permission denied"
  | .unknown errno msg => s!"Unknown error ({errno}): {msg}"

instance : ToString SocketError := ⟨toString⟩

/-- Check if error indicates the operation should be retried -/
def isRetryable : SocketError → Bool
  | .wouldBlock => true
  | .interrupted => true
  | _ => false

/-- Check if error indicates connection was lost -/
def isConnectionLost : SocketError → Bool
  | .connectionRefused => true
  | .connectionReset => true
  | .connectionAborted => true
  | .networkUnreachable => true
  | .hostUnreachable => true
  | .notConnected => true
  | _ => false

end SocketError

end Jack

import Crucible
import Jack
open Crucible

testSuite "Jack.Socket"

test "create and close socket" := do
  let sock ← Jack.Socket.new
  sock.close

test "bind to port" := do
  let sock ← Jack.Socket.new
  sock.bind "127.0.0.1" 0  -- Port 0 = OS assigns
  sock.close

test "get file descriptor" := do
  let sock ← Jack.Socket.new
  let fd := sock.fd
  ensure (fd != 0) "file descriptor should be non-zero"
  sock.close

def main : IO UInt32 := runAllSuites

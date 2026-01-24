# Jack

BSD socket bindings for Lean 4.

## Features

- TCP client/server sockets
- UDP datagram sockets
- IPv4 and IPv6 support
- Non-blocking I/O
- Socket options (SO_REUSEADDR, etc.)

## Quick Start

```lean
import Jack

-- Aspirational API example
def main : IO Unit := do
  let socket ← Socket.create .inet .stream
  socket.connect "127.0.0.1" 8080
  socket.send "Hello, World!".toUTF8
  let response ← socket.recv 1024
  socket.close
```

## Build / Test

```bash
lake build && lake test
```

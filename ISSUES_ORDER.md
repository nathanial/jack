# Jack Issue Order

Current open issues and proposed execution order.

Open issues:
- 657 SO_RCVBUF / SO_SNDBUF socket options
- 658 TCP_NODELAY socket option
- 659 SO_LINGER socket option
- 660 Async-friendly API design
- 661 Unix socket abstract namespace (Linux)
- 662 Unix socket tests
- 663 Socket.shutdown - half-close connections
- 664 Socket.sendFile - zero-copy file transfer
- 665 Scatter/gather I/O (sendmsg/recvmsg)
- 666 Socket pair creation
- 667 Out-of-band data support
- 668 API documentation for all public functions
- 669 Tutorial: building a chat server
- 670 Tutorial: HTTP client basics
- 671 Performance benchmarks
- 672 Platform compatibility notes (macOS, Linux)

Recently completed:
- 651 IPv6 dual-stack socket option (IPV6_V6ONLY)
- 652 IPv6 address parsing
- 653 IPv6 connectivity tests
- 655 SO_REUSEPORT socket option
- 656 SO_KEEPALIVE socket option

Recommended order:
1) 658 TCP_NODELAY
2) 657 SO_RCVBUF / SO_SNDBUF
3) 659 SO_LINGER
4) 663 Socket.shutdown
5) 666 Socket pair creation
6) 665 Scatter/gather I/O
7) 664 Socket.sendFile
8) 667 Out-of-band data
9) 661 Unix abstract namespace
10) 662 Unix socket tests
11) 660 Async-friendly API design
12) 671 Performance benchmarks
13) 668 API documentation
14) 672 Platform compatibility notes
15) 669/670 Tutorials

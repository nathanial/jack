# Jack Issue Order

Current open issues and proposed execution order.

Open issues:
- 656 SO_KEEPALIVE socket option
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

Recommended order:
1) 658 TCP_NODELAY
2) 656 SO_KEEPALIVE
3) 657 SO_RCVBUF / SO_SNDBUF
4) 659 SO_LINGER
5) 663 Socket.shutdown
6) 666 Socket pair creation
7) 665 Scatter/gather I/O
8) 664 Socket.sendFile
9) 667 Out-of-band data
10) 661 Unix abstract namespace
11) 662 Unix socket tests
12) 660 Async-friendly API design
13) 671 Performance benchmarks
14) 668 API documentation
15) 672 Platform compatibility notes
16) 669/670 Tutorials

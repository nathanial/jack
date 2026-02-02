/*
 * Jack Socket FFI
 * BSD socket bindings using POSIX sockets
 */

#include <lean/lean.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <netinet/ip6.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>

/* ========== Socket Option Constants ========== */

LEAN_EXPORT lean_obj_res jack_const_sol_socket(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SOL_SOCKET));
}

LEAN_EXPORT lean_obj_res jack_const_so_reuseaddr(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SO_REUSEADDR));
}

LEAN_EXPORT lean_obj_res jack_const_so_reuseport(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SO_REUSEPORT));
}

LEAN_EXPORT lean_obj_res jack_const_so_keepalive(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SO_KEEPALIVE));
}

LEAN_EXPORT lean_obj_res jack_const_so_rcvbuf(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SO_RCVBUF));
}

LEAN_EXPORT lean_obj_res jack_const_so_sndbuf(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)SO_SNDBUF));
}

LEAN_EXPORT lean_obj_res jack_const_ipproto_tcp(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)IPPROTO_TCP));
}

LEAN_EXPORT lean_obj_res jack_const_tcp_nodelay(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)TCP_NODELAY));
}

LEAN_EXPORT lean_obj_res jack_const_ipproto_ipv6(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)IPPROTO_IPV6));
}

LEAN_EXPORT lean_obj_res jack_const_ipv6_v6only(lean_obj_arg world) {
    (void)world;
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)IPV6_V6ONLY));
}

/* Socket handle - just wraps a file descriptor */
typedef struct {
    int fd;
} jack_socket_t;

static lean_external_class *g_socket_class = NULL;

static void jack_socket_finalizer(void *ptr) {
    jack_socket_t *sock = (jack_socket_t *)ptr;
    if (sock->fd >= 0) {
        close(sock->fd);
    }
    free(sock);
}

static void jack_socket_foreach(void *ptr, b_lean_obj_arg f) {
    /* No nested Lean objects */
}

static inline lean_obj_res jack_socket_box(jack_socket_t *sock) {
    if (g_socket_class == NULL) {
        g_socket_class = lean_register_external_class(
            jack_socket_finalizer,
            jack_socket_foreach
        );
    }
    return lean_alloc_external(g_socket_class, sock);
}

static inline jack_socket_t *jack_socket_unbox(lean_obj_arg obj) {
    return (jack_socket_t *)lean_get_external_data(obj);
}

/* ========== Error Handling ========== */

/* Map errno to SocketError constructor tag */
static int errno_to_socket_error_tag(int err) {
    switch (err) {
        case EACCES:        return 0;   /* accessDenied */
        case EADDRINUSE:    return 1;   /* addressInUse */
        case EADDRNOTAVAIL: return 2;   /* addressNotAvailable */
        case ECONNREFUSED:  return 3;   /* connectionRefused */
        case ECONNRESET:    return 4;   /* connectionReset */
        case ECONNABORTED:  return 5;   /* connectionAborted */
        case ENETUNREACH:   return 6;   /* networkUnreachable */
        case EHOSTUNREACH:  return 7;   /* hostUnreachable */
        case ETIMEDOUT:     return 8;   /* timedOut */
        case EAGAIN:        return 9;   /* wouldBlock */
#if EAGAIN != EWOULDBLOCK
        case EWOULDBLOCK:   return 9;   /* wouldBlock */
#endif
        case EINTR:         return 10;  /* interrupted */
        case EINVAL:        return 11;  /* invalidArgument */
        case ENOTCONN:      return 12;  /* notConnected */
        case EISCONN:       return 13;  /* alreadyConnected */
        case EBADF:         return 14;  /* badDescriptor */
        case EPERM:         return 15;  /* permissionDenied */
        default:            return 16;  /* unknown */
    }
}

/* Create a SocketError from errno */
static lean_obj_res jack_make_socket_error(int err) {
    int tag = errno_to_socket_error_tag(err);
    if (tag == 16) {
        /* unknown(errno, message) */
        lean_obj_res obj = lean_alloc_ctor(16, 2, 0);
        lean_ctor_set(obj, 0, lean_int_to_int(err));
        lean_ctor_set(obj, 1, lean_mk_string(strerror(err)));
        return obj;
    } else {
        /* Simple constructor with no fields */
        return lean_box(tag);
    }
}

/* Create an IO error from errno - wraps in IO.Error.userError with SocketError string */
static lean_obj_res jack_io_error_from_errno(int err) {
    (void)jack_make_socket_error; /* Keep for future use */
    return lean_io_result_mk_error(lean_mk_io_user_error(
        lean_mk_string(strerror(err))));
}

/* ========== Address Conversion ========== */

/* Parse IPv6 address string. Returns empty ByteArray on failure. */
LEAN_EXPORT lean_obj_res jack_ipv6_parse(b_lean_obj_arg addr_str) {
    const char *addr_cstr = lean_string_cstr(addr_str);
    struct in6_addr addr;

    if (inet_pton(AF_INET6, addr_cstr, &addr) != 1) {
        return lean_alloc_sarray(1, 0, 0);
    }

    lean_obj_res bytes = lean_alloc_sarray(1, 16, 16);
    memcpy(lean_sarray_cptr(bytes), &addr, 16);
    return bytes;
}

/* Convert Lean SockAddr to C sockaddr_storage
 * Returns 0 on success, -1 on error
 * SockAddr is:
 *   | ipv4 (addr : IPv4Addr) (port : UInt16)  -- tag 0
 *   | ipv6 (bytes : ByteArray) (port : UInt16) -- tag 1
 *   | unix (path : String)                     -- tag 2
 *
 * IPv4Addr is: { a : UInt8, b : UInt8, c : UInt8, d : UInt8 }
 */
static int lean_to_sockaddr(b_lean_obj_arg addr, struct sockaddr_storage *out, socklen_t *len) {
    memset(out, 0, sizeof(*out));

    unsigned tag = lean_ptr_tag(addr);

    if (tag == 0) {
        /* ipv4 (addr : IPv4Addr) (port : UInt16)
         * Layout: 1 object field (IPv4Addr), 2 scalar bytes (UInt16 port)
         * Scalar offset = sizeof(void*) * num_obj_fields = 8 on 64-bit
         */
        lean_obj_arg ipv4 = lean_ctor_get(addr, 0);
        uint16_t port = lean_ctor_get_uint16(addr, sizeof(void*));

        /* IPv4Addr is a structure with 4 UInt8 fields stored as scalars */
        uint8_t a = lean_ctor_get_uint8(ipv4, 0);
        uint8_t b = lean_ctor_get_uint8(ipv4, 1);
        uint8_t c = lean_ctor_get_uint8(ipv4, 2);
        uint8_t d = lean_ctor_get_uint8(ipv4, 3);

        struct sockaddr_in *sin = (struct sockaddr_in *)out;
        sin->sin_family = AF_INET;
        sin->sin_port = htons(port);
        sin->sin_addr.s_addr = htonl((a << 24) | (b << 16) | (c << 8) | d);
        *len = sizeof(struct sockaddr_in);
        return 0;
    }
    else if (tag == 1) {
        /* ipv6 (bytes : ByteArray) (port : UInt16)
         * Layout: 1 object field (ByteArray), 2 scalar bytes (UInt16 port)
         * Scalar offset = sizeof(void*) * num_obj_fields = 8 on 64-bit
         */
        lean_obj_arg bytes = lean_ctor_get(addr, 0);
        uint16_t port = lean_ctor_get_uint16(addr, sizeof(void*));

        if (lean_sarray_size(bytes) != 16) {
            return -1;
        }

        struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)out;
        sin6->sin6_family = AF_INET6;
        sin6->sin6_port = htons(port);
        memcpy(&sin6->sin6_addr, lean_sarray_cptr(bytes), 16);
        *len = sizeof(struct sockaddr_in6);
        return 0;
    }
    else if (tag == 2) {
        /* unix (path : String)
         * Layout: 1 object field (String), no scalars
         */
        lean_obj_arg path = lean_ctor_get(addr, 0);
        const char *path_str = lean_string_cstr(path);

        struct sockaddr_un *sun = (struct sockaddr_un *)out;
        sun->sun_family = AF_UNIX;
        size_t path_len = strlen(path_str);
        if (path_len >= sizeof(sun->sun_path)) {
            return -1;
        }
        strncpy(sun->sun_path, path_str, sizeof(sun->sun_path) - 1);
        *len = sizeof(struct sockaddr_un);
        return 0;
    }

    return -1;
}

/* Convert C sockaddr to Lean SockAddr
 * SockAddr.ipv4: tag 0, 1 object field (IPv4Addr), 2 scalar bytes (UInt16 port)
 * SockAddr.ipv6: tag 1, 1 object field (ByteArray), 2 scalar bytes (UInt16 port)
 * SockAddr.unix: tag 2, 1 object field (String), 0 scalar bytes
 */
static lean_obj_res sockaddr_to_lean(struct sockaddr *addr, socklen_t len) {
    if (addr->sa_family == AF_INET && len >= sizeof(struct sockaddr_in)) {
        struct sockaddr_in *sin = (struct sockaddr_in *)addr;
        uint32_t ip = ntohl(sin->sin_addr.s_addr);
        uint16_t port = ntohs(sin->sin_port);

        /* Create IPv4Addr structure with 4 UInt8 scalar fields */
        lean_obj_res ipv4 = lean_alloc_ctor(0, 0, 4);
        lean_ctor_set_uint8(ipv4, 0, (ip >> 24) & 0xFF);
        lean_ctor_set_uint8(ipv4, 1, (ip >> 16) & 0xFF);
        lean_ctor_set_uint8(ipv4, 2, (ip >> 8) & 0xFF);
        lean_ctor_set_uint8(ipv4, 3, ip & 0xFF);

        /* Create SockAddr.ipv4: 1 object field, 2 scalar bytes
         * Scalar offset = sizeof(void*) * num_obj_fields = 8 on 64-bit
         */
        lean_obj_res result = lean_alloc_ctor(0, 1, 2);
        lean_ctor_set(result, 0, ipv4);
        lean_ctor_set_uint16(result, sizeof(void*), port);
        return result;
    }
    else if (addr->sa_family == AF_INET6 && len >= sizeof(struct sockaddr_in6)) {
        struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)addr;
        uint16_t port = ntohs(sin6->sin6_port);

        /* Create ByteArray with 16 bytes */
        lean_obj_res bytes = lean_alloc_sarray(1, 16, 16);
        memcpy(lean_sarray_cptr(bytes), &sin6->sin6_addr, 16);

        /* Create SockAddr.ipv6: 1 object field, 2 scalar bytes
         * Scalar offset = sizeof(void*) * num_obj_fields = 8 on 64-bit
         */
        lean_obj_res result = lean_alloc_ctor(1, 1, 2);
        lean_ctor_set(result, 0, bytes);
        lean_ctor_set_uint16(result, sizeof(void*), port);
        return result;
    }
    else if (addr->sa_family == AF_UNIX) {
        struct sockaddr_un *sun = (struct sockaddr_un *)addr;

        /* Create SockAddr.unix: 1 object field, 0 scalar bytes */
        lean_obj_res result = lean_alloc_ctor(2, 1, 0);
        lean_ctor_set(result, 0, lean_mk_string(sun->sun_path));
        return result;
    }

    /* Fallback: return ipv4 0.0.0.0:0 */
    lean_obj_res ipv4 = lean_alloc_ctor(0, 0, 4);
    lean_ctor_set_uint8(ipv4, 0, 0);
    lean_ctor_set_uint8(ipv4, 1, 0);
    lean_ctor_set_uint8(ipv4, 2, 0);
    lean_ctor_set_uint8(ipv4, 3, 0);

    lean_obj_res result = lean_alloc_ctor(0, 1, 2);
    lean_ctor_set(result, 0, ipv4);
    lean_ctor_set_uint16(result, sizeof(void*), 0);
    return result;
}

/* ========== Socket Creation ========== */

/* Create a new TCP socket */
LEAN_EXPORT lean_obj_res jack_socket_new(lean_obj_arg world) {
    jack_socket_t *sock = malloc(sizeof(jack_socket_t));
    if (!sock) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Failed to allocate socket")));
    }

    sock->fd = socket(AF_INET, SOCK_STREAM, 0);
    if (sock->fd < 0) {
        int err = errno;
        free(sock);
        return jack_io_error_from_errno(err);
    }

    /* Set SO_REUSEADDR */
    int opt = 1;
    setsockopt(sock->fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    /* Set recv/send timeouts to 5 seconds */
    struct timeval timeout;
    timeout.tv_sec = 5;
    timeout.tv_usec = 0;
    setsockopt(sock->fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(sock->fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    return lean_io_result_mk_ok(jack_socket_box(sock));
}

/* Create a socket with specified family, type, and protocol
 * AddressFamily: inet=0, inet6=1, unix=2
 * SocketType: stream=0, dgram=1
 * Protocol: default=0, tcp=1, udp=2
 */
LEAN_EXPORT lean_obj_res jack_socket_create(
    uint8_t family_tag,
    uint8_t sock_type_tag,
    uint8_t protocol_tag,
    lean_obj_arg world
) {
    int af, st, proto;

    switch (family_tag) {
        case 0: af = AF_INET; break;
        case 1: af = AF_INET6; break;
        case 2: af = AF_UNIX; break;
        default: af = AF_INET; break;
    }

    switch (sock_type_tag) {
        case 0: st = SOCK_STREAM; break;
        case 1: st = SOCK_DGRAM; break;
        default: st = SOCK_STREAM; break;
    }

    switch (protocol_tag) {
        case 0: proto = 0; break;
        case 1: proto = IPPROTO_TCP; break;
        case 2: proto = IPPROTO_UDP; break;
        default: proto = 0; break;
    }

    jack_socket_t *sock = malloc(sizeof(jack_socket_t));
    if (!sock) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Failed to allocate socket")));
    }

    sock->fd = socket(af, st, proto);
    if (sock->fd < 0) {
        int err = errno;
        free(sock);
        return jack_io_error_from_errno(err);
    }

    /* Set SO_REUSEADDR for stream sockets */
    if (st == SOCK_STREAM) {
        int opt = 1;
        setsockopt(sock->fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        /* Set recv/send timeouts to 5 seconds */
        struct timeval timeout;
        timeout.tv_sec = 5;
        timeout.tv_usec = 0;
        setsockopt(sock->fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(sock->fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
    }

    return lean_io_result_mk_ok(jack_socket_box(sock));
}

/* ========== Connection ========== */

/* Connect socket to remote host:port */
LEAN_EXPORT lean_obj_res jack_socket_connect(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg host,
    uint16_t port,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);
    const char *host_str = lean_string_cstr(host);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);

    if (inet_pton(AF_INET, host_str, &addr.sin_addr) <= 0) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Invalid address")));
    }

    if (connect(sock->fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Connect socket using structured address */
LEAN_EXPORT lean_obj_res jack_socket_connect_addr(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg addr,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct sockaddr_storage sa;
    socklen_t sa_len;

    if (lean_to_sockaddr(addr, &sa, &sa_len) < 0) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Invalid address")));
    }

    if (connect(sock->fd, (struct sockaddr *)&sa, sa_len) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* ========== Binding ========== */

/* Bind socket to address */
LEAN_EXPORT lean_obj_res jack_socket_bind(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg host,
    uint16_t port,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);
    const char *host_str = lean_string_cstr(host);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);

    if (inet_pton(AF_INET, host_str, &addr.sin_addr) <= 0) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Invalid address")));
    }

    if (bind(sock->fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Bind socket using structured address */
LEAN_EXPORT lean_obj_res jack_socket_bind_addr(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg addr,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct sockaddr_storage sa;
    socklen_t sa_len;

    if (lean_to_sockaddr(addr, &sa, &sa_len) < 0) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Invalid address")));
    }

    if (bind(sock->fd, (struct sockaddr *)&sa, sa_len) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* ========== Listen/Accept ========== */

/* Listen for connections */
LEAN_EXPORT lean_obj_res jack_socket_listen(
    b_lean_obj_arg sock_obj,
    uint32_t backlog,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    if (listen(sock->fd, backlog) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Accept a connection */
LEAN_EXPORT lean_obj_res jack_socket_accept(
    b_lean_obj_arg sock_obj,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct sockaddr_in client_addr;
    socklen_t addr_len = sizeof(client_addr);

    int client_fd = accept(sock->fd, (struct sockaddr *)&client_addr, &addr_len);
    if (client_fd < 0) {
        return jack_io_error_from_errno(errno);
    }

    jack_socket_t *client = malloc(sizeof(jack_socket_t));
    if (!client) {
        close(client_fd);
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Failed to allocate client socket")));
    }
    client->fd = client_fd;

    /* Set recv/send timeouts to 5 seconds on client socket */
    struct timeval timeout;
    timeout.tv_sec = 5;
    timeout.tv_usec = 0;
    setsockopt(client_fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(client_fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    return lean_io_result_mk_ok(jack_socket_box(client));
}

/* ========== Send/Recv ========== */

static lean_obj_res jack_socket_send_loop(jack_socket_t *sock, const uint8_t *ptr, size_t len) {
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = send(sock->fd, ptr + sent, len - sent, 0);
        if (n < 0) {
            return jack_io_error_from_errno(errno);
        }
        if (n == 0) {
            return lean_io_result_mk_error(lean_mk_io_user_error(
                lean_mk_string("Socket send returned 0 bytes")));
        }
        sent += (size_t)n;
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Receive data */
LEAN_EXPORT lean_obj_res jack_socket_recv(
    b_lean_obj_arg sock_obj,
    uint32_t max_bytes,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    uint8_t *buffer = malloc(max_bytes);
    if (!buffer) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Failed to allocate buffer")));
    }

    ssize_t n = recv(sock->fd, buffer, max_bytes, 0);
    if (n < 0) {
        int err = errno;
        free(buffer);
        return jack_io_error_from_errno(err);
    }

    lean_obj_res arr = lean_alloc_sarray(1, n, n);
    memcpy(lean_sarray_cptr(arr), buffer, n);
    free(buffer);

    return lean_io_result_mk_ok(arr);
}

/* Send data */
LEAN_EXPORT lean_obj_res jack_socket_send(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg data,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    size_t len = lean_sarray_size(data);
    const uint8_t *ptr = lean_sarray_cptr(data);

    return jack_socket_send_loop(sock, ptr, len);
}

/* Send all data (retry loop) */
LEAN_EXPORT lean_obj_res jack_socket_send_all(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg data,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    size_t len = lean_sarray_size(data);
    const uint8_t *ptr = lean_sarray_cptr(data);

    return jack_socket_send_loop(sock, ptr, len);
}

/* ========== UDP Operations ========== */

/* Send data to specific address (UDP) */
LEAN_EXPORT lean_obj_res jack_socket_send_to(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg data,
    b_lean_obj_arg addr,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct sockaddr_storage sa;
    socklen_t sa_len;

    if (lean_to_sockaddr(addr, &sa, &sa_len) < 0) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Invalid address")));
    }

    size_t len = lean_sarray_size(data);
    const uint8_t *ptr = lean_sarray_cptr(data);

    ssize_t n = sendto(sock->fd, ptr, len, 0, (struct sockaddr *)&sa, sa_len);
    if (n < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Receive data with sender address (UDP) */
LEAN_EXPORT lean_obj_res jack_socket_recv_from(
    b_lean_obj_arg sock_obj,
    uint32_t max_bytes,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    uint8_t *buffer = malloc(max_bytes);
    if (!buffer) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Failed to allocate buffer")));
    }

    struct sockaddr_storage from_addr;
    socklen_t from_len = sizeof(from_addr);

    ssize_t n = recvfrom(sock->fd, buffer, max_bytes, 0,
                         (struct sockaddr *)&from_addr, &from_len);
    if (n < 0) {
        int err = errno;
        free(buffer);
        return jack_io_error_from_errno(err);
    }

    /* Create ByteArray */
    lean_obj_res arr = lean_alloc_sarray(1, n, n);
    memcpy(lean_sarray_cptr(arr), buffer, n);
    free(buffer);

    /* Create SockAddr */
    lean_obj_res lean_addr = sockaddr_to_lean((struct sockaddr *)&from_addr, from_len);

    /* Create tuple (ByteArray × SockAddr) */
    lean_obj_res pair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(pair, 0, arr);
    lean_ctor_set(pair, 1, lean_addr);

    return lean_io_result_mk_ok(pair);
}

/* ========== Address Operations ========== */

/* Get local address */
LEAN_EXPORT lean_obj_res jack_socket_get_local_addr(
    b_lean_obj_arg sock_obj,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct sockaddr_storage addr;
    socklen_t addr_len = sizeof(addr);

    if (getsockname(sock->fd, (struct sockaddr *)&addr, &addr_len) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(sockaddr_to_lean((struct sockaddr *)&addr, addr_len));
}

/* Get peer address */
LEAN_EXPORT lean_obj_res jack_socket_get_peer_addr(
    b_lean_obj_arg sock_obj,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct sockaddr_storage addr;
    socklen_t addr_len = sizeof(addr);

    if (getpeername(sock->fd, (struct sockaddr *)&addr, &addr_len) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(sockaddr_to_lean((struct sockaddr *)&addr, addr_len));
}

/* ========== Socket Options ========== */

/* Close socket */
LEAN_EXPORT lean_obj_res jack_socket_close(
    lean_obj_arg sock_obj,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    if (sock->fd >= 0) {
        close(sock->fd);
        sock->fd = -1;
    }

    lean_dec_ref(sock_obj);
    return lean_io_result_mk_ok(lean_box(0));
}

/* Get socket file descriptor (for debugging) */
LEAN_EXPORT uint32_t jack_socket_fd(b_lean_obj_arg sock_obj) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);
    return (uint32_t)sock->fd;
}

/* Set socket recv/send timeouts in seconds */
LEAN_EXPORT lean_obj_res jack_socket_set_timeout(
    b_lean_obj_arg sock_obj,
    uint32_t timeout_secs,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct timeval timeout;
    timeout.tv_sec = timeout_secs;
    timeout.tv_usec = 0;
    setsockopt(sock->fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(sock->fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    return lean_io_result_mk_ok(lean_box(0));
}

/* Set raw socket option */
LEAN_EXPORT lean_obj_res jack_socket_set_option(
    b_lean_obj_arg sock_obj,
    uint32_t level,
    uint32_t opt_name,
    b_lean_obj_arg value,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    size_t len = lean_sarray_size(value);
    const uint8_t *ptr = lean_sarray_cptr(value);

    if (setsockopt(sock->fd, (int)level, (int)opt_name, ptr, (socklen_t)len) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Get raw socket option */
LEAN_EXPORT lean_obj_res jack_socket_get_option(
    b_lean_obj_arg sock_obj,
    uint32_t level,
    uint32_t opt_name,
    uint32_t max_bytes,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    size_t len = (size_t)max_bytes;
    uint8_t *buffer = malloc(len);
    if (!buffer && len > 0) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Failed to allocate buffer")));
    }

    socklen_t opt_len = (socklen_t)len;
    if (getsockopt(sock->fd, (int)level, (int)opt_name, buffer, &opt_len) < 0) {
        int err = errno;
        free(buffer);
        return jack_io_error_from_errno(err);
    }

    lean_obj_res arr = lean_alloc_sarray(1, opt_len, opt_len);
    if (opt_len > 0) {
        memcpy(lean_sarray_cptr(arr), buffer, opt_len);
    }
    free(buffer);

    return lean_io_result_mk_ok(arr);
}

/* Set socket option as UInt32 */
LEAN_EXPORT lean_obj_res jack_socket_set_option_uint32(
    b_lean_obj_arg sock_obj,
    uint32_t level,
    uint32_t opt_name,
    uint32_t value,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);
    uint32_t opt_value = value;

    if (setsockopt(sock->fd, (int)level, (int)opt_name, &opt_value, sizeof(opt_value)) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Get socket option as UInt32 */
LEAN_EXPORT lean_obj_res jack_socket_get_option_uint32(
    b_lean_obj_arg sock_obj,
    uint32_t level,
    uint32_t opt_name,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);
    uint32_t opt_value = 0;
    socklen_t opt_len = (socklen_t)sizeof(opt_value);

    if (getsockopt(sock->fd, (int)level, (int)opt_name, &opt_value, &opt_len) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box_uint32(opt_value));
}

/* Set SO_LINGER option */
LEAN_EXPORT lean_obj_res jack_socket_set_linger(
    b_lean_obj_arg sock_obj,
    uint8_t enabled,
    uint32_t seconds,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);
    struct linger opt;
    opt.l_onoff = enabled ? 1 : 0;
    opt.l_linger = (int)seconds;

    if (setsockopt(sock->fd, SOL_SOCKET, SO_LINGER, &opt, sizeof(opt)) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Get SO_LINGER option */
LEAN_EXPORT lean_obj_res jack_socket_get_linger(
    b_lean_obj_arg sock_obj,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);
    struct linger opt;
    socklen_t opt_len = (socklen_t)sizeof(opt);

    if (getsockopt(sock->fd, SOL_SOCKET, SO_LINGER, &opt, &opt_len) < 0) {
        return jack_io_error_from_errno(errno);
    }

    lean_obj_res pair = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(pair, 0, lean_box(opt.l_onoff ? 1 : 0));
    lean_ctor_set(pair, 1, lean_box_uint32((uint32_t)opt.l_linger));
    return lean_io_result_mk_ok(pair);
}

/* ========== Non-blocking I/O ========== */

/* Set socket to non-blocking mode */
LEAN_EXPORT lean_obj_res jack_socket_set_nonblocking(
    b_lean_obj_arg sock_obj,
    uint8_t nonblocking,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    int flags = fcntl(sock->fd, F_GETFL, 0);
    if (flags < 0) {
        return jack_io_error_from_errno(errno);
    }

    if (nonblocking) {
        flags |= O_NONBLOCK;
    } else {
        flags &= ~O_NONBLOCK;
    }

    if (fcntl(sock->fd, F_SETFL, flags) < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

/* Convert Lean PollEvent array to poll events bitmask
 * PollEvent: readable=0, writable=1, error=2, hangup=3
 */
static short lean_events_to_poll(b_lean_obj_arg events) {
    short result = 0;
    size_t len = lean_array_size(events);

    for (size_t i = 0; i < len; i++) {
        lean_obj_arg ev = lean_array_get_core(events, i);
        unsigned tag = lean_unbox(ev);
        switch (tag) {
            case 0: result |= POLLIN; break;   /* readable */
            case 1: result |= POLLOUT; break;  /* writable */
            case 2: result |= POLLERR; break;  /* error */
            case 3: result |= POLLHUP; break;  /* hangup */
        }
    }

    return result;
}

/* Convert poll revents to Lean PollEvent array */
static lean_obj_res poll_to_lean_events(short revents) {
    size_t count = 0;
    if (revents & POLLIN) count++;
    if (revents & POLLOUT) count++;
    if (revents & POLLERR) count++;
    if (revents & POLLHUP) count++;

    lean_obj_res arr = lean_alloc_array(count, count);
    size_t idx = 0;

    if (revents & POLLIN) {
        lean_array_set_core(arr, idx++, lean_box(0));  /* readable */
    }
    if (revents & POLLOUT) {
        lean_array_set_core(arr, idx++, lean_box(1));  /* writable */
    }
    if (revents & POLLERR) {
        lean_array_set_core(arr, idx++, lean_box(2));  /* error */
    }
    if (revents & POLLHUP) {
        lean_array_set_core(arr, idx++, lean_box(3));  /* hangup */
    }

    return arr;
}

/* Poll single socket for events */
LEAN_EXPORT lean_obj_res jack_socket_poll(
    b_lean_obj_arg sock_obj,
    b_lean_obj_arg events,
    int32_t timeout_ms,
    lean_obj_arg world
) {
    jack_socket_t *sock = jack_socket_unbox(sock_obj);

    struct pollfd pfd;
    pfd.fd = sock->fd;
    pfd.events = lean_events_to_poll(events);
    pfd.revents = 0;

    int ret = poll(&pfd, 1, timeout_ms);
    if (ret < 0) {
        return jack_io_error_from_errno(errno);
    }

    return lean_io_result_mk_ok(poll_to_lean_events(pfd.revents));
}

/* Poll multiple sockets for events
 * PollEntry: { socket : Socket, events : Array PollEvent }
 * PollResult: { socket : Socket, events : Array PollEvent }
 */
LEAN_EXPORT lean_obj_res jack_poll_wait(
    b_lean_obj_arg entries,
    int32_t timeout_ms,
    lean_obj_arg world
) {
    size_t count = lean_array_size(entries);

    if (count == 0) {
        return lean_io_result_mk_ok(lean_alloc_array(0, 0));
    }

    struct pollfd *pfds = malloc(count * sizeof(struct pollfd));
    if (!pfds) {
        return lean_io_result_mk_error(lean_mk_io_user_error(
            lean_mk_string("Failed to allocate poll array")));
    }

    /* Build pollfd array */
    for (size_t i = 0; i < count; i++) {
        lean_obj_arg entry = lean_array_get_core(entries, i);
        lean_obj_arg sock_obj_i = lean_ctor_get(entry, 0);
        lean_obj_arg events_i = lean_ctor_get(entry, 1);

        jack_socket_t *sock = jack_socket_unbox(sock_obj_i);
        pfds[i].fd = sock->fd;
        pfds[i].events = lean_events_to_poll(events_i);
        pfds[i].revents = 0;
    }

    int ret = poll(pfds, count, timeout_ms);
    if (ret < 0) {
        int err = errno;
        free(pfds);
        return jack_io_error_from_errno(err);
    }

    /* Count results with events */
    size_t result_count = 0;
    for (size_t i = 0; i < count; i++) {
        if (pfds[i].revents != 0) {
            result_count++;
        }
    }

    /* Build result array */
    lean_obj_res results = lean_alloc_array(result_count, result_count);
    size_t result_idx = 0;

    for (size_t i = 0; i < count; i++) {
        if (pfds[i].revents != 0) {
            lean_obj_arg entry = lean_array_get_core(entries, i);
            lean_obj_arg sock_obj_i = lean_ctor_get(entry, 0);
            lean_inc_ref(sock_obj_i);

            /* Create PollResult structure */
            lean_obj_res result = lean_alloc_ctor(0, 2, 0);
            lean_ctor_set(result, 0, sock_obj_i);
            lean_ctor_set(result, 1, poll_to_lean_events(pfds[i].revents));

            lean_array_set_core(results, result_idx++, result);
        }
    }

    free(pfds);
    return lean_io_result_mk_ok(results);
}

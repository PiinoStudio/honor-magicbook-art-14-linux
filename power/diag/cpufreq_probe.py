# Measure effective CPU clock per core via perf_event_open(PERF_COUNT_HW_CPU_CYCLES) on a busy loop.
import ctypes, os, struct, time, sys
libc = ctypes.CDLL(None, use_errno=True)
NR = 241  # aarch64 perf_event_open
def attr():
    # struct perf_event_attr (size 136): type=0 HW, config=0 CPU_CYCLES, flags: disabled=1, exclude_kernel=0
    a = bytearray(136)
    struct.pack_into("IIQ", a, 0, 0, 136, 0)
    struct.pack_into("Q", a, 40, 1)  # flags: disabled
    return (ctypes.c_char * 136).from_buffer(a)
cpus = [int(c) for c in sys.argv[1:]] or [0, 4, 8]
for cpu in cpus:
    os.sched_setaffinity(0, {cpu})
    a = attr()
    fd = libc.syscall(NR, ctypes.byref(a), 0, -1, -1, 0)
    if fd < 0:
        print(f"cpu{cpu}: perf_event_open failed errno={ctypes.get_errno()}"); continue
    import fcntl
    fcntl.ioctl(fd, 0x2403, 0)  # RESET
    fcntl.ioctl(fd, 0x2400, 0)  # ENABLE
    t0 = time.perf_counter(); c0 = time.process_time()
    x = 0
    while time.perf_counter() - t0 < 1.0:
        for _ in range(20000): x += 1
    fcntl.ioctl(fd, 0x2401, 0)  # DISABLE
    cyc = struct.unpack("Q", os.read(fd, 8))[0]
    cput = time.process_time() - c0
    print(f"cpu{cpu}: {cyc/cput/1e6:.0f} MHz (cycles={cyc}, cputime={cput:.3f}s)")
    os.close(fd)

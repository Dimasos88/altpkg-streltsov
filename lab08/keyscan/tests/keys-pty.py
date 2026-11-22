import errno
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios
import time

program, mode = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
    os.environ["TERM"] = "xterm"
    os.execv(program, [program])
data = bytearray()
sent = quit_sent = False
deadline = time.monotonic() + 6
try:
    while time.monotonic() < deadline:
        if not select.select([fd], [], [], .15)[0]:
            continue
        try:
            chunk = os.read(fd, 4096)
        except OSError as exc:
            if exc.errno == errno.EIO:
                break
            raise
        data.extend(chunk)
        if not sent and b"Press a key" in data:
            os.write(fd, b"\x1bOP")
            sent = True
        if mode == "on" and b"KEY_F(1)" in data and not quit_sent:
            os.write(fd, b"q")
            quit_sent = True
    else:
        raise RuntimeError("PTY timeout")
    _, status = os.waitpid(pid, 0)
    sys.stdout.buffer.write(data)
    assert os.waitstatus_to_exitcode(status) == 0
    assert (b"KEY_F(1)" in data) == (mode == "on")
    assert (b"Exit: Escape" in data) == (mode == "off")
except BaseException:
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    raise
finally:
    os.close(fd)

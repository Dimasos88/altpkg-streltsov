#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

static volatile sig_atomic_t info, stops;
static void on_info(int sig) { (void)sig; ++info; }
static void on_stop(int sig) { (void)sig; ++stops; }

int main(int argc, char **argv)
{
    if (argc != 2)
        return 2;
    setvbuf(stdout, NULL, _IOLBF, 0);
    struct sigaction a = {.sa_handler = on_info, .sa_flags = SA_RESTART};
    struct sigaction b = {.sa_handler = on_stop, .sa_flags = SA_RESTART};
    if (sigemptyset(&a.sa_mask) || sigemptyset(&b.sa_mask))
        return 4;
    if (sigaction(SIGUSR1, &a, NULL) < 0)
        puts("SIGUSR1 handler unavailable");
    if (sigaction(SIGUSR2, &b, NULL) < 0)
        return 4;
    for (int i = 1; i <= 4; ++i) {
        int fd = open(argv[1], O_RDWR | O_CREAT | O_TRUNC, 0600);
        if (fd < 0)
            return 5;
        if (write(fd, "ALT", 3) != 3 || lseek(fd, 0, SEEK_SET) < 0)
            return 6;
        char data[4];
        ssize_t count = read(fd, data, 3);
        int saved = errno;
        if (close(fd) < 0)
            return 7;
        if (count < 0) {
            errno = saved;
            perror("read");
            printf("round %d read error\n", i);
            return 8;
        }
        printf("round %d bytes=%zd info=%d stop=%d\n", i, count, (int)info, (int)stops);
        if (stops >= 2)
            break;
    }
    return 0;
}

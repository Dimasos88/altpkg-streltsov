#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int error(const char *operation, int status)
{
    perror(operation);
    return status;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "Usage: %s SOURCE TARGET\n", argv[0]);
        return 2;
    }
    int input = open(argv[1], O_RDONLY);
    if (input < 0)
        return error("open source", errno == ENOENT ? 3 : 4);
    int output = -1, status = 0;
    struct stat src, dst;
    char *temporary = NULL;
    if (fstat(input, &src) < 0) {
        status = error("fstat source", 4);
        goto cleanup;
    }
    if (stat(argv[2], &dst) == 0) {
        if (src.st_dev == dst.st_dev && src.st_ino == dst.st_ino) {
            errno = EINVAL;
            status = error("same file", 5);
            goto cleanup;
        }
    } else if (errno != ENOENT) {
        status = error("stat target", 6);
        goto cleanup;
    }
    size_t length = strlen(argv[2]) + sizeof ".lab07.XXXXXX";
    temporary = malloc(length);
    if (!temporary) {
        status = error("malloc", 6);
        goto cleanup;
    }
    snprintf(temporary, length, "%s.lab07.XXXXXX", argv[2]);
    output = mkstemp(temporary);
    if (output < 0) {
        status = error("create target", 6);
        goto cleanup;
    }
    char buffer[16384];
    for (;;) {
        ssize_t count = read(input, buffer, sizeof buffer);
        if (count == 0)
            break;
        if (count < 0) {
            if (errno == EINTR)
                continue;
            status = error("read", 7);
            break;
        }
        for (ssize_t offset = 0; offset < count;) {
            ssize_t written = write(output, buffer + offset, (size_t)(count - offset));
            if (written < 0 && errno == EINTR)
                continue;
            if (written <= 0) {
                if (written == 0)
                    errno = EIO;
                status = error("write", 8);
                break;
            }
            offset += written;
        }
        if (status)
            break;
    }
    if (close(output) < 0 && !status)
        status = error("close target", 9);
    if (!status && rename(temporary, argv[2]) < 0)
        status = error("rename target", 10);
    if (status && unlink(temporary) < 0)
        perror("unlink temporary");
cleanup:
    if (close(input) < 0 && !status)
        status = error("close source", 9);
    if (!status && unlink(argv[1]) < 0)
        status = error("unlink source", 11);
    free(temporary);
    return status;
}

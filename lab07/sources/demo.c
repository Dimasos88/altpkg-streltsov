#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
int main(int argc, char **argv)
{
    if (argc != 2)
        return 2;
    volatile int length = (int)strlen(argv[1]);
    volatile int comparison = strcmp(argv[1], "alpha");
    srand((unsigned)time(NULL));
    const char *path = getenv("LAB07_DEMO_FILE");
    if (path) {
        int fd = open(path, O_RDONLY);
        if (fd < 0)
            return 3;
        char byte;
        if (read(fd, &byte, 1) != 1 || close(fd) < 0)
            return 4;
    }
    for (int i = 0; i < 3; ++i)
        printf("%s %d\n", argv[1], rand());
    return length == 0 && comparison == 0;
}

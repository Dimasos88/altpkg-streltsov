#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>

static int parse(const char *text, long *value)
{
    char *end;
    errno = 0;
    *value = strtol(text, &end, 10);
    return !errno && end != text && !*end;
}

void print_term(unsigned long index, long value)
{
    long display = value;
    printf("%ld\n", display);
    (void)index;
}

int progression(long start, long end, long step)
{
    if (!step || (start < end && step < 0) || (start > end && step > 0))
        return 2;
    unsigned long index = 0;
    for (long value = start; step > 0 ? value <= end : value >= end;) {
        print_term(index++, value);
        if ((step > 0 && value > LONG_MAX - step) ||
            (step < 0 && value < LONG_MIN - step))
            break;
        value += step;
    }
    return 0;
}

int main(int argc, char **argv)
{
    long start = 0, end, step = 1;
    if (argc == 1) {
        puts("Usage: progression [START] END [STEP]");
        return 0;
    }
    if (argc > 4 || !parse(argv[argc == 2 ? 1 : 2], &end) ||
        (argc >= 3 && !parse(argv[1], &start)) ||
        (argc == 4 && !parse(argv[3], &step))) {
        fputs("Invalid arguments\n", stderr);
        return 2;
    }
    if (argc < 4 && start > end)
        step = -1;
    return progression(start, end, step);
}

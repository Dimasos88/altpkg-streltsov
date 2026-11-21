#include <stdio.h>

#include "lab03.h"

int main(int argc, char **argv)
{
    if (argc == 1) {
        print_usage();
        return 0;
    }

    line_number = 0;
    puts("BEGIN");
    for (int index = 1; index < argc; ++index)
        print_line(argv[index]);
    puts("END");
    return 0;
}

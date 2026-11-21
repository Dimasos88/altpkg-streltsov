#include <stdio.h>

#include "lab03.h"

void print_line(const char *text)
{
    printf("%u: %s\n", ++line_number, text);
}

void print_usage(void)
{
    fprintf(stderr, "lab03 %s\nUsage: lab03 ARG [ARG ...]\n", LAB03_VERSION);
}

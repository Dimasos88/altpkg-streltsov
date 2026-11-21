#include <stdio.h>

static int source_value(void)
{
    int value = 6;
    return value;
}

static int transform(int value)
{
#ifdef FIXED
    const int scale = 2;
#else
    const int scale = 3;
#endif
    return value * scale;
}

static int run(void)
{
    return transform(source_value());
}

int main(void)
{
    printf("%d\n", run());
    return 0;
}

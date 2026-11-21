#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
int unlink(const char *path)
{
    if (strstr(path, "lab07-protected")) {
        errno = EPERM;
        return -1;
    }
    int (*next)(const char *) = dlsym(RTLD_NEXT, "unlink");
    if (!next) {
        errno = ENOSYS;
        return -1;
    }
    return next(path);
}

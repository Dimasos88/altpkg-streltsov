#define _POSIX_C_SOURCE 200809L
#include "config.h"
#include <ctype.h>
#include <rhash.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#ifdef USE_READLINE
#include <readline/readline.h>
#endif

static unsigned algorithm(const char *name)
{
    if (!strcasecmp(name, "md5")) return RHASH_MD5;
    if (!strcasecmp(name, "sha1")) return RHASH_SHA1;
    if (!strcasecmp(name, "sha256")) return RHASH_SHA256;
    return 0;
}

static void execute(char *line)
{
    line += strspn(line, " \t");
    if (!*line) return;
    char *arg = line + strcspn(line, " \t");
    if (!*arg) { fputs("argument required\n", stderr); return; }
    *arg++ = 0;
    arg += strspn(arg, " \t");
    unsigned id = algorithm(line);
    if (!id) { fprintf(stderr, "unknown algorithm: %s\n", line); return; }
    if (!*arg) { fputs("argument required\n", stderr); return; }
    unsigned char digest[64];
    int rc;
    if (*arg == '"') {
        arg++;
        size_t len = strlen(arg);
        if (!len || arg[len-1] != '"') { fputs("unterminated string\n", stderr); return; }
        rc = rhash_msg(id, arg, len-1, digest);
    } else {
        rc = rhash_file(id, arg, digest);
    }
    if (rc < 0) { perror(arg); return; }
    char output[129];
    rhash_print_bytes(output, digest, rhash_get_digest_size(id),
                      isupper((unsigned char)line[0]) ? RHPR_BASE64 : RHPR_HEX);
    puts(output);
}
int main(void)
{
    rhash_library_init();
#ifdef USE_READLINE
    if (isatty(STDIN_FILENO)) {
        char *input;
        while ((input = readline("hash> "))) {
            execute(input);
            free(input);
        }
        return 0;
    }
#endif
    char *line = NULL;
    size_t size = 0;
    ssize_t length;
    while ((length = getline(&line, &size, stdin)) >= 0) {
        if (length && line[length-1] == '\n') line[length-1] = 0;
        execute(line);
    }
    free(line);
    return ferror(stdin) ? 1 : 0;
}

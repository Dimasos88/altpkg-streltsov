#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <limits.h>
#include <regex.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int diagnostic(int error, const regex_t *pattern)
{
    char message[256];
    regerror(error, pattern, message, sizeof message);
    fprintf(stderr, "%s\n", message);
    return 2;
}

#ifdef REPLACE
static int replace(const regex_t *pattern, const char *replacement, const char *line)
{
    regmatch_t matches[10];
    for (size_t i = 0; replacement[i]; ++i) {
        if (replacement[i] != '\\' || !replacement[i + 1])
            continue;
        char next = replacement[++i];
        if (next >= '1' && next <= '9' && (size_t)(next - '0') > pattern->re_nsub) {
            fprintf(stderr, "No group %c\n", next);
            return 2;
        }
    }
    int error = regexec(pattern, line, 10, matches, 0);
    if (error == REG_NOMATCH) {
        puts(line);
        return 0;
    }
    if (error)
        return diagnostic(error, pattern);
    fwrite(line, 1, (size_t)matches[0].rm_so, stdout);
    for (size_t i = 0; replacement[i]; ++i) {
        char ch = replacement[i];
        int group = ch == '&' ? 0 : -1;
        if (ch == '\\' && replacement[i + 1]) {
            ch = replacement[++i];
            if (ch >= '1' && ch <= '9')
                group = ch - '0';
        }
        if (group < 0)
            putchar((unsigned char)ch);
        else if (matches[group].rm_so >= 0)
            fwrite(line + matches[group].rm_so, 1, (size_t)(matches[group].rm_eo - matches[group].rm_so), stdout);
    }
    puts(line + matches[0].rm_eo);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 4) {
        fprintf(stderr, "Usage: %s PATTERN REPLACEMENT TEXT\n", argv[0]);
        return 2;
    }
    regex_t pattern;
    int error = regcomp(&pattern, argv[1], REG_EXTENDED);
    if (error)
        return diagnostic(error, &pattern);
    int status = replace(&pattern, argv[2], argv[3]);
    regfree(&pattern);
    return status;
}
#else
int main(int argc, char **argv)
{
    int groups = argc == 3 && strcmp(argv[1], "--groups") == 0;
    if (argc != 2 && !groups) {
        fprintf(stderr, "Usage: %s [--groups] PATTERN\n", argv[0]);
        return 2;
    }
    regex_t pattern;
    int error = regcomp(&pattern, argv[groups ? 2 : 1], REG_EXTENDED);
    if (error)
        return diagnostic(error, &pattern);
    size_t count = groups ? pattern.re_nsub + 1 : 0;
    regmatch_t *matches = count ? calloc(count, sizeof *matches) : NULL;
    if (count && !matches) {
        perror("calloc");
        regfree(&pattern);
        return 2;
    }
    char *line = NULL;
    size_t capacity = 0;
    ssize_t length;
    int status = 1;
    while ((length = getline(&line, &capacity, stdin)) >= 0) {
        if (length && line[length - 1] == '\n')
            line[--length] = '\0';
        error = regexec(&pattern, line, count, matches, 0);
        if (!error) {
            puts(line);
            status = 0;
            for (size_t i = 1; i < count; ++i) {
                regmatch_t match = matches[i];
                if (match.rm_so < 0) {
                    printf("%zu [-1,-1)\n", i);
                } else {
                    printf("%zu [%jd,%jd) ", i, (intmax_t)match.rm_so, (intmax_t)match.rm_eo);
                    fwrite(line + match.rm_so, 1, (size_t)(match.rm_eo - match.rm_so), stdout);
                    putchar('\n');
                }
            }
        } else if (error != REG_NOMATCH) {
            status = diagnostic(error, &pattern);
            break;
        }
#ifdef MEASURE_LEAK
        line = NULL;
        capacity = 0;
#endif
    }
    if (ferror(stdin) || !feof(stdin)) {
        if (status != 2)
            perror("getline");
        status = 2;
    }
    free(line);
    free(matches);
    regfree(&pattern);
    return status;
}
#endif

#ifdef HAVE_CONFIG_H
#include "config.h"
#else
#define PACKAGE_STRING "lab08-autotools 1.0"
#define PACKAGE_BUGREPORT "https://github.com/Dimasos88/lab08-autotools/issues"
#ifndef WINDOW_MARGIN
#define WINDOW_MARGIN 2
#endif
#endif
#ifdef HAVE_NCURSESW_NCURSES_H
#include <ncursesw/ncurses.h>
#else
#include <ncurses.h>
#endif
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc == 2 && strcmp(argv[1], "--version") == 0) {
        printf("%s\nBugs: %s\n", PACKAGE_STRING, PACKAGE_BUGREPORT);
        return 0;
    }
    if (!isatty(STDIN_FILENO)) {
        fputs("stdin is not a terminal\n", stderr);
        return 2;
    }
    initscr();
    cbreak();
    noecho();
    int m = WINDOW_MARGIN;
    if (LINES < 2*m+4 || COLS < 2*m+30) {
        endwin();
        fputs("terminal too small\n", stderr);
        return 2;
    }
    WINDOW *w = newwin(LINES-2*m, COLS-2*m, m, m);
    if (!w) {
        endwin();
        return 2;
    }
#ifdef USE_KEYPAD
    keypad(w, TRUE);
#else
    keypad(w, FALSE);
#endif
    box(w, 0, 0);
    mvwprintw(w, 1, 2, "Press a key, q or Escape exits");
    wrefresh(w);
    int k;
    while ((k = wgetch(w)) != ERR && k != 'q' && k != 27) {
        werase(w);
        box(w, 0, 0);
        const char *name = keyname(k);
        mvwprintw(w, 1, 2, "Key %d: %s", k, name ? name : "?");
        wrefresh(w);
    }
    delwin(w);
    endwin();
    if (k == 27) puts("Exit: Escape");
    return k == ERR ? 1 : 0;
}

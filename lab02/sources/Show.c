#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curses.h>

#define MAX_LINES 10000
#define BUFFER_SIZE 4096

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Использование: %s <имя_файла>\n", argv[0]);
        return 1;
    }

    FILE *fp = fopen(argv[1], "r");
    if (!fp) {
        perror("Ошибка открытия файла");
        return 2;
    }

    char **lines = malloc(MAX_LINES * sizeof(char *));
    if (!lines) {
        fprintf(stderr, "Ошибка выделения памяти\n");
        fclose(fp);
        return 3;
    }

    int total_lines = 0;
    char buffer[BUFFER_SIZE];
    while (fgets(buffer, sizeof(buffer), fp) && total_lines < MAX_LINES) {
        size_t len = strlen(buffer);
        if (len > 0 && buffer[len - 1] == '\n') {
            buffer[len - 1] = '\0';
        }
        lines[total_lines] = strdup(buffer);
        total_lines++;
    }
    fclose(fp);

    /* Инициализация ncurses только после успешного чтения файла */
    initscr();
    cbreak();
    noecho();

    int screen_h, screen_w;
    getmaxyx(stdscr, screen_h, screen_w);

    /* Первая строка экрана: имя файла */
    move(0, 0);
    attron(A_REVERSE);
    mvprintw(0, 0, " Файл: %s [Строк: %d] (Пробел - дальше, 'q' - выход)", argv[1], total_lines);
    for (int col = getcurx(stdscr); col < screen_w; col++) {
        addch(' ');
    }
    attroff(A_REVERSE);
    refresh();

    /* Отдельное окно для содержимого файла */
    int win_h = screen_h - 1;
    int win_w = screen_w;
    WINDOW *content_win = newwin(win_h, win_w, 1, 0);
    keypad(content_win, TRUE);

    int current_line = 0;
    int ch = 0;

    while (ch != 'q' && ch != 'Q' && ch != 27) {
        werase(content_win);
        for (int i = 0; i < win_h; i++) {
            int line_idx = current_line + i;
            if (line_idx < total_lines) {
                char line_buf[BUFFER_SIZE];
                strncpy(line_buf, lines[line_idx], win_w - 1);
                line_buf[win_w - 1] = '\0';
                mvwaddstr(content_win, i, 0, line_buf);
            }
        }
        wrefresh(content_win);

        ch = wgetch(content_win);
        if (ch == ' ' || ch == KEY_NPAGE) {
            if (current_line + win_h < total_lines) {
                current_line += win_h;
            }
        } else if (ch == KEY_PPAGE) {
            current_line -= win_h;
            if (current_line < 0) current_line = 0;
        } else if (ch == KEY_DOWN) {
            if (current_line + 1 < total_lines) {
                current_line++;
            }
        } else if (ch == KEY_UP) {
            if (current_line > 0) {
                current_line--;
            }
        }
    }

    delwin(content_win);
    endwin();

    for (int i = 0; i < total_lines; i++) {
        free(lines[i]);
    }
    free(lines);

    return 0;
}

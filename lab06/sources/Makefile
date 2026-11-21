CFLAGS ?= -O2 -g -Wall -Wextra

.PHONY: all test clean
all: lab06-match lab06-replace
lab06-match: regex.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $<
lab06-replace: regex.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -DREPLACE -o $@ $<
lab06-measure-leak: regex.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -DMEASURE_LEAK -o $@ $<
test: all
	bash ../check/check-lab06.sh
clean:
	rm -f lab06-match lab06-replace lab06-measure-leak

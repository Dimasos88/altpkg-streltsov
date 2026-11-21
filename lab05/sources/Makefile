CC ?= gcc
.PHONY: all test clean
all: progression progression-debug progression-opt progression.o libprogression.so diagnostic diagnostic-fixed
progression: progression.c
	$(CC) -o $@ $<
progression-debug: progression.c
	$(CC) -g -O0 -Wall -Wextra -Wpedantic -o $@ $<
progression-opt: progression.c
	$(CC) -g -O2 -Wall -Wextra -Wpedantic -o $@ $<
progression.o: progression.c
	$(CC) -g -O0 -c -o $@ $<
libprogression.so: progression.c
	$(CC) -g -fPIC -shared -o $@ $<
diagnostic: diagnostic.c
	$(CC) -g -O0 -Wall -Wextra -Wpedantic -o $@ $<
diagnostic-fixed: diagnostic.c
	$(CC) -g -O0 -Wall -Wextra -Wpedantic -DFIXED -o $@ $<
test: all
	bash ../check/check-lab05.sh
clean:
	rm -f progression progression-debug progression-opt progression.o libprogression.so diagnostic diagnostic-fixed

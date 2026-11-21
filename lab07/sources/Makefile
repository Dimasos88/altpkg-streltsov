CFLAGS ?= -O2 -g -Wall -Wextra
CC ?= cc
programs = lab07-move lab07-signals
.PHONY: all test clean
all: $(programs)
lab07-move: move.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $<
lab07-signals: signals.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $<
lab07-demo: demo.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -fno-builtin -o $@ $<
libconstant.so: constant.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -shared -o $@ $<
libguard.so: guard.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -shared -o $@ $< -ldl
test: all
	bash tests/check-package.sh
clean:
	rm -f $(programs) lab07-demo libconstant.so libguard.so

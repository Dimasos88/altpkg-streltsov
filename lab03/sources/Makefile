.DEFAULT_GOAL := all

CFLAGS ?= -O2 -g -Wall -Wextra
ARFLAGS = rvU
objects := main.o output.o counter.o
library_objects := output.o counter.o
pic_objects := output.pic.o counter.pic.o
programs := lab03-objects lab03-static lab03-shared
static_library := static/liblab03.a
shared_library := liblab03.so.1

.PHONY: all test clean distclean full-static run-shared
.SECONDARY: $(library_objects)

all: $(programs)

$(objects) $(pic_objects): lab03.h

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

%.pic.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -c $< -o $@

lab03-objects: $(objects)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

static:
	mkdir -p $@

$(static_library): $(static_library)(output.o) $(static_library)(counter.o)

$(static_library)(output.o): output.o | static
$(static_library)(counter.o): counter.o | static $(static_library)(output.o)

lab03-static: main.o $(static_library)
	$(CC) $(LDFLAGS) -o $@ $< -Lstatic -llab03 $(LDLIBS)

$(shared_library): $(pic_objects)
	$(CC) $(LDFLAGS) -shared -Wl,-soname,$@ -o $@ $^ $(LDLIBS)

lab03-shared: main.o $(shared_library)
	$(CC) $(LDFLAGS) -o $@ $< -L. -l:$(shared_library) $(LDLIBS)

full-static: lab03-full-static

lab03-full-static: main.o $(static_library)
	$(CC) $(LDFLAGS) $(STATIC_LDFLAGS) -static -o $@ $< -Lstatic -llab03 $(LDLIBS)

run-shared: lab03-shared
	LD_LIBRARY_PATH="$(CURDIR)" ./lab03-shared alpha beta gamma

test: all
	@set -eu; mkdir -p test-output; \
	for program in $(programs); do \
		for count in 0 1 3; do \
			case $$count in \
				0) set -- ;; \
				1) set -- alpha ;; \
				3) set -- alpha beta gamma ;; \
			esac; \
			LD_LIBRARY_PATH="$(CURDIR)" ./$$program "$$@" \
				>test-output/$$program-$$count.stdout \
				2>test-output/$$program-$$count.stderr; \
		done; \
	done; \
	for count in 0 1 3; do \
		for stream in stdout stderr; do \
			for pair in 'objects static' 'objects shared' 'static shared'; do \
				set -- $$pair; \
				cmp test-output/lab03-$$1-$$count.$$stream \
					test-output/lab03-$$2-$$count.$$stream; \
			done; \
		done; \
	done

clean:
	rm -f $(objects) $(pic_objects)

distclean: clean
	rm -f $(programs) $(static_library) $(shared_library) lab03-full-static
	rm -rf test-output
	@if test -d static; then rmdir static; fi

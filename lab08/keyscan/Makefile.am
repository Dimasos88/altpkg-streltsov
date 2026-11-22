AM_CFLAGS = -Wall -Wextra
bin_PROGRAMS = lab08-keys
lab08_keys_SOURCES = keys.c
lab08_keys_LDADD = $(CURSES_LIBS)
TESTS = tests/notty.sh
TEST_EXTENSIONS = .sh
SH_LOG_COMPILER = $(SHELL)
EXTRA_DIST = $(TESTS) tests/keys-pty.py
.PHONY: git-clean-preview
git-clean-preview:
	cd $(srcdir) && git clean -ndX -- .

.PHONY: git-clean-generated
git-clean-generated:
	cd $(srcdir) && git clean -fdX -- .

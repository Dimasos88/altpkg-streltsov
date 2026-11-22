AM_CFLAGS = -Wall -Wextra
bin_PROGRAMS = lab08-hash
lab08_hash_SOURCES = hash.c
lab08_hash_LDADD = $(RHASH_LIBS) $(READLINE_LIBS)
TESTS = tests/hash.sh
TEST_EXTENSIONS = .sh
SH_LOG_COMPILER = $(SHELL)
EXTRA_DIST = $(TESTS)

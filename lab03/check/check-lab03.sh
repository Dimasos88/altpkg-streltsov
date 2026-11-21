#!/usr/bin/env bash
set -u
export LC_ALL=C

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd) || exit 1
work=$(mktemp -d) || exit 1
trap 'rm -r -- "$work"' EXIT
mkdir -p "$root/logs" || exit 1
logs=$root/logs
cp "$root/sources/"{Makefile,main.c,output.c,counter.c,lab03.h} "$work/" || exit 1
cd "$work" || exit 1

passed=0
failed=0
skipped=0
check() {
    local name=$1
    shift
    if "$@" >"$logs/$name.log" 2>&1; then
        printf 'PASS %s\n' "$name"
        ((passed += 1))
    else
        printf 'FAIL %s\n' "$name"
        ((failed += 1))
    fi
}

stages() {
    cc -Wall main.c output.c counter.c -o one-step &&
    cc -E main.c -o main.i &&
    grep -F 'void print_line(const char *text);' main.i &&
    make lab03-objects &&
    file main.o output.o counter.o &&
    ./one-step > no-args.stdout 2> no-args.stderr &&
    test ! -s no-args.stdout &&
    grep -F 'Usage:' no-args.stderr &&
    ./one-step alpha beta gamma > actual.stdout &&
    test "$(wc -l < actual.stdout)" -eq 5 &&
    cmp actual.stdout "$root/check/three.stdout"
}

trace_compiler() {
    strace -f -e trace=execve -o "$logs/compiler-execve.log" \
        cc main.c output.c counter.c -o traced &&
    grep -E 'execve\(".*(cc1|as|collect2|ld)"' "$logs/compiler-execve.log"
}

duplicate_definition() {
    printf '\nvoid duplicate_example(void) {}\n' >> lab03.h
    cc main.c output.c counter.c -o bad > duplicate.log 2>&1
    local status=$?
    cp "$root/sources/lab03.h" lab03.h || return 1
    cat duplicate.log
    test "$status" -ne 0 && grep -F 'multiple definition' duplicate.log
}

symbols() {
    nm -g main.o output.o counter.o &&
    test "$(nm -g --defined-only main.o output.o counter.o | grep -c ' B line_number$')" -eq 1 &&
    nm -u main.o output.o counter.o | awk 'NF == 2 && $1 == "U" {print $2}' | sort -u > undefined &&
    nm -g --defined-only main.o output.o counter.o | awk 'NF == 3 {print $3}' | sort -u > defined &&
    comm -23 undefined defined &&
    readelf --syms lab03-objects &&
    ldd lab03-objects > direct.ldd && cat direct.ldd &&
    grep -F 'libc.so' direct.ldd && ! grep -F 'not found' direct.ldd
}

incremental() {
    make lab03-objects || return 1
    sleep 1
    touch output.c && make lab03-objects > rebuild.log && cat rebuild.log &&
    test "$(wc -l < rebuild.log)" -eq 2 &&
    grep -F 'output.c' rebuild.log &&
    ! grep -E '(-c main.c|-c counter.c)' rebuild.log || return 1
    touch lab03.h && make -n CFLAGS=-O0 lab03-objects > header.log && cat header.log &&
    test "$(grep -c -- '-O0 -c' header.log)" -eq 3
}

make_rules() (
    set -e
    mkdir variants
    cp main.c output.c counter.c lab03.h variants/
    cd variants
    {
        printf '%s\n' 'CFLAGS = -Wall' 'all: app' 'app: main.o output.o counter.o'
        printf '\t%s\n' '$(CC) -o $@ $^'
    } > base.mk
    cp base.mk explicit.mk
    for module in main output counter; do
        printf '%s.o: %s.c\n\t$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@\n' \
            "$module" "$module" >> explicit.mk
    done
    cp base.mk pattern.mk
    printf '%%.o: %%.c\n\t%s\n' '$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@' >> pattern.mk
    make -nf explicit.mk > explicit.commands
    make -nf pattern.mk > pattern.commands
    cmp explicit.commands pattern.commands
    cat explicit.commands
    make -f base.mk
    sleep 1
    touch lab03.h
    make -nf base.mk | tee default-header.log
    ! grep -F ' -c ' default-header.log
    printf '%s\n' 'main.o output.o counter.o: lab03.h' >> base.mk
    make -nf base.mk CFLAGS=-O0 | tee explicit-header.log
    test "$(grep -c -- '-O0' explicit-header.log)" -eq 3
    printf 'clean:\n\t%s\n' 'rm -f main.o' >> base.mk
    touch clean
    make -f base.mk clean
    test -f main.o
    printf '%s\n' '.PHONY: clean' >> base.mk
    make -f base.mk clean
    test ! -e main.o
)

archives() {
    make all &&
    ar -t static/liblab03.a > members && cat members &&
    grep -Fx output.o members && grep -Fx counter.o members &&
    ./lab03-static alpha beta gamma > with-archive.stdout &&
    cmp with-archive.stdout "$root/check/three.stdout"
}

fully_static() {
    make full-static &&
    stat -c '%n %s bytes' lab03-objects lab03-full-static &&
    for executable in lab03-objects lab03-full-static; do
        printf '%s ' "$executable"
        nm "$executable" | wc -l
    done &&
    ! readelf -l lab03-full-static | grep -F INTERP
}

non_pic() {
    cc -fno-pic -fno-pie -c output.c -o output.nonpic.o &&
    cc -fno-pic -fno-pie -c counter.c -o counter.nonpic.o || return 1
    ! cc -shared -o nonpic.so output.nonpic.o counter.nonpic.o > nonpic.log 2>&1 &&
    cat nonpic.log && grep -Ei 'relocation|recompile with -fPIC' nonpic.log
}

loader() {
    nm -D liblab03.so.1 > exports && cat exports &&
    grep -F ' T print_usage' exports && grep -F ' T print_line' exports &&
    grep -F ' B line_number' exports &&
    ! env -u LD_LIBRARY_PATH ./lab03-shared alpha 2> loader.err &&
    cat loader.err && grep -F 'liblab03.so.1' loader.err &&
    env -u LD_LIBRARY_PATH ldd ./lab03-shared > missing.ldd &&
    cat missing.ldd && grep -F 'not found' missing.ldd &&
    LD_LIBRARY_PATH="$PWD" ldd ./lab03-shared > resolved.ldd &&
    cat resolved.ldd && ! grep -F 'not found' resolved.ldd &&
    LD_LIBRARY_PATH="$PWD" ./lab03-shared alpha beta gamma > shared.stdout &&
    cmp shared.stdout "$root/check/three.stdout"
}

make_test() {
    make test &&
    test "$(find test-output -type f -name '*.stdout' | wc -l)" -eq 9 &&
    test "$(find test-output -type f -name '*.stderr' | wc -l)" -eq 9
}

make_negative_test() {
    printf '#!/bin/sh\nprintf "changed\\n"\n' > lab03-objects || return 1
    ! make test || return 1
    make -B lab03-objects && make test
}

cleanup_test() (
    set -e
    mkdir cleanup
    cp Makefile main.c output.c counter.c lab03.h cleanup/
    cd cleanup
    make test
    make clean
    test ! -e main.o && test ! -e output.pic.o
    test -f lab03-shared && test -f static/liblab03.a
    make distclean
    diff <(printf '%s\n' Makefile counter.c lab03.h main.c output.c) <(ls -A)
)

check shell-syntax bash -n "$root/check/check-lab03.sh"
check compile-stages stages
check compiler-trace trace_compiler
check duplicate-definition duplicate_definition
check symbol-table symbols
check incremental-build incremental
check make-rule-variants make_rules
check static-library archives
check fully-static fully_static
check non-pic-rejected non_pic
check dynamic-loader loader
check make-test make_test
check make-negative-test make_negative_test
check cleanup-targets cleanup_test

if [[ -n ${LAB03_HASHER_DIR:-} ]]; then
    check rpm-package bash "$root/check/check-rpm.sh" "$LAB03_HASHER_DIR"
else
    printf 'SKIP rpm-package (LAB03_HASHER_DIR is unset)\n'
    ((skipped += 1))
fi

printf 'PASS=%d FAIL=%d SKIP=%d\n' "$passed" "$failed" "$skipped"
((failed == 0))

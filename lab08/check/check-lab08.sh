#!/bin/bash
set -uo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")/.." && pwd) || exit 1
logs=${LAB08_LOGS:-"$root/logs"}
work=$(mktemp -d) || exit 1
mkdir -p "$logs" || exit 1
trap 'rm -rf -- "$work"' EXIT
passed=0 failed=0 skipped=0
check() {
    local label=$1
    shift
    "$@" >"$logs/$label.log" 2>&1 &
    if wait "$!"; then echo "PASS $label"; ((passed+=1)); else echo "FAIL $label"; ((failed+=1)); fi
}
stage() {
    local src=$1 target=$2
    mkdir -p "$target"
    cp "$root/$src"/{configure.ac,Makefile.am,*.c,.gitignore} "$target/"
    cp -r "$root/$src/tests" "$target/"
}
check_pty() {
    local mode=$1 file=$2
    python3 "$root/keyscan/tests/keys-pty.py" "$file" "$mode" >"$logs/$3.pty"
    grep -aoE 'Key [0-9]+: KEY_F\(1\)|Exit: Escape' "$logs/$3.pty"
}
scan_manual() (
    set -e
    stage keyscan "$work/scan"
    cd "$work/scan"
    local -a cflags ldflags
    read -ra cflags <<<"${CPPFLAGS:-}"
    read -ra ldflags <<<"${LDFLAGS:-}"
    cc "${cflags[@]}" -DUSE_KEYPAD -DWINDOW_MARGIN=2 keys.c "${ldflags[@]}" -lncursesw -o manual-on
    cc "${cflags[@]}" -DWINDOW_MARGIN=4 keys.c "${ldflags[@]}" -lncursesw -o manual-off
    check_pty on "$PWD/manual-on" manual-on
    check_pty off "$PWD/manual-off" manual-off
    rc=0
    ./manual-on </dev/null 2>"$work/notty" || rc=$?
    test "$rc" -eq 2
    grep -Fx 'stdin is not a terminal' "$work/notty"
    autoscan
    grep -E 'AC_PROG_CC|AC_CHECK_HEADERS' configure.scan
    cp configure.scan "$logs/autoscan-profile.txt"
    aclocal
    autoconf
    read -r ac < <(wc -l < configure.ac)
    read -r generated < <(wc -l < configure)
    printf 'configure.ac=%s configure=%s\n' "$ac" "$generated"
    test "$generated" -ge "$((ac*100))"
)
dependencies() (
    set -e
    stage keyscan "$work/key"
    cd "$work/key"
    grep -q '^AC_CHECK_LIB(\[ncursesw\]' configure.ac
    autoreconf -fisv |& tee "$logs/autoreconf.log"
    mkdir absent
    if (cd absent; ac_cv_lib_ncursesw_initscr=no ../configure) >"$work/missing" 2>&1; then exit 1; fi
    grep -F 'ncursesw development library is required' "$work/missing"
    mkdir present
    cd present
    ../configure | tee "$logs/configure-present.log"
    grep -E 'missing_symbol.*no|initscr.*yes' "$logs/configure-present.log"
    grep -nE 'initscr|lncursesw' config.log | sed -n '1,12p'
    cp config.log "$logs/keyscan-config.txt"
    make V=1 | tee "$logs/keyscan-link.log"
    grep -E 'lab08-keys.*-lncursesw' "$logs/keyscan-link.log"
)
options() (
    set -e
    cd "$work/key"
    ./configure --help | grep -E -- '--disable-keypad|--with-margin'
    grep -E 'USE_KEYPAD|WINDOW_MARGIN' config.h.in
    for pair in on:2 off:4; do
        IFS=: read -r mode margin <<<"$pair"
        mkdir "$mode"
        (
          cd "$mode"
          if [[ $mode == on ]]; then flag=--enable-keypad; else flag=--disable-keypad; fi
          ../configure "$flag" "--with-margin=$margin" >/dev/null
          grep -Fx "#define WINDOW_MARGIN $margin" config.h
          if [[ $mode == on ]]; then grep -Fx '#define USE_KEYPAD 1' config.h; else grep -Fx '/* #undef USE_KEYPAD */' config.h; fi
          cp config.h "$logs/config-$mode.txt"
          make -s
          ./lab08-keys --version
          check_pty "$mode" "$PWD/lab08-keys" "config-$mode"
        )
    done
)
automake_tests() (
    set -e
    stage keyscan "$work/no-tests"
    cd "$work/no-tests"
    sed -i '/^TESTS =/d; s/EXTRA_DIST = $(TESTS)/EXTRA_DIST = tests\/notty.sh/' Makefile.am
    autoreconf -fi
    ./configure >/dev/null
    make -s
    make check | tee "$logs/check-before-tests.log"
    ! grep -E '^PASS:|^# TOTAL:' "$logs/check-before-tests.log"
    cd "$work/key/present"
    make check | tee "$logs/automake-pass.log"
    cp test-suite.log "$logs/test-suite-pass.txt"
    grep -E '^# (TOTAL|PASS|FAIL):' "$logs/automake-pass.log"
    if LAB08_EXPECT_NOTTY='wrong expected message' make check >"$logs/automake-negative.log" 2>&1; then exit 1; fi
    grep -F 'FAIL: tests/notty.sh' "$logs/automake-negative.log"
    make check | tee "$logs/automake-restored.log"
    grep -E '^# FAIL: *0' "$logs/automake-restored.log"
)
out_tree() (
    set -e
    stage keyscan "$work/tree-src"
    cd "$work/tree-src"
    git init -q
    git add .
    autoreconf -fi
    find . -path './.git' -prune -o -type f -print | sort >"$work/before"
    cp "$work/before" "$logs/source-file-list.txt"
    if git status --porcelain --untracked-files=all | grep -q '^??'; then exit 1; fi
    mkdir "$work/out" "$work/out-again"
    (cd "$work/out"; "$work/tree-src/configure" >/dev/null; make V=1; make check) | tee "$logs/vpath-build.log"
    find . -path './.git' -prune -o -type f -print | sort >"$work/after"
    diff -u "$work/before" "$work/after"
    echo 'Source tree: identical before and after'
    grep -F -- "-I$work/tree-src" "$logs/vpath-build.log"
    rm -r "$work/out"
    (cd "$work/out-again"; "$work/tree-src/configure" >/dev/null; make -s)
    echo 'Configuration after removal: PASS'
    ./configure >/dev/null
    make V=1 | tee "$logs/in-tree-build.log"
    make git-clean-preview
)
hash_builds() (
    set -e
    stage rhasher "$work/hash"
    cd "$work/hash"
    grep -q '^AC_CHECK_LIB(\[rhash\]' configure.ac
    autoreconf -fi
    mkdir absent fallback forced normal
    if (cd absent; ac_cv_lib_rhash_rhash_init=no ../configure) >"$work/hash-missing" 2>&1; then exit 1; fi
    grep -F 'librhash development library is required' "$work/hash-missing"
    for type in fallback forced normal; do
        (
         cd "$type"
         case "$type" in
          fallback) ac_cv_header_readline_readline_h=no ../configure ;;
          forced) ../configure --without-readline ;;
          normal) ../configure ;;
         esac
         make V=1
         make check
         cat tests/hash.log
         ldd ./lab08-hash
         if [[ $type == normal && ${LAB08_READLINE_EXPECTED:-0} == 1 ]]; then
             ldd ./lab08-hash | grep -F libreadline
         elif [[ $type != normal ]]; then
             if ldd ./lab08-hash | grep -q libreadline; then exit 1; fi
         fi
        ) |& tee "$logs/hash-$type.log"
    done
    PKG_CONFIG_PATH="$root/env/pkgconfig:${PKG_CONFIG_PATH:-}" pkg-config --cflags --libs librhash
    if pkg-config --exists readline; then pkg-config --cflags --libs readline; fi
)
rpm_variants() (
    set -e
    grep -E -- './configure .*--enable-keypad' "$LAB08_RPM_EVIDENCE/rpm-on.log"
    grep -E -- './configure .*--disable-keypad' "$LAB08_RPM_EVIDENCE/rpm-off.log"
    grep -E '^# FAIL: *0' "$LAB08_RPM_EVIDENCE"/rpm-{on,off}.log
    grep -aoF 'KEY_F(1)' "$LAB08_RPM_EVIDENCE/rpm-on.pty"
    grep -aoF 'Exit: Escape' "$LAB08_RPM_EVIDENCE/rpm-off.pty"
)
check manual-and-autoscan scan_manual
check mandatory-and-optional dependencies
check config-header options
check automake-test-sensitivity automake_tests
check separate-build-tree out_tree
check hash-and-readline hash_builds
if [[ -n ${LAB08_RPM_EVIDENCE:-} ]]; then check rpm-keypad-switch rpm_variants; else echo 'SKIP rpm-keypad-switch'; ((skipped+=1)); fi
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$passed" "$failed" "$skipped"
((failed == 0))

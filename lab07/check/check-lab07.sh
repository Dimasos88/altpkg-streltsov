#!/bin/bash
set -uo pipefail
export LC_ALL=C
base=$(cd "$(dirname "$0")/.." && pwd) || exit 1
src=$base/sources
logs=${LAB07_LOGS:-"$base/logs"}
work=$(mktemp -d) || exit 1
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$logs" || exit 1
passed=0 failed=0 skipped=0
check() {
    local name=$1
    shift
    "$@" >"$logs/$name.log" 2>&1 &
    if wait "$!"; then printf 'PASS %s\n' "$name"; ((passed+=1)); else printf 'FAIL %s\n' "$name"; ((failed+=1)); fi
}
skip() { printf 'SKIP %s\n' "$1"; ((skipped+=1)); }

trace_filters() (
    set -e
    mkdir "$work/files"
    printf 'ALT\n' > "$work/files/present"
    strace /bin/true >"$work/stdout" 2>"$work/stderr"
    test ! -s "$work/stdout"
    grep -F 'execve(' "$work/stderr"
    strace -o "$logs/ls.trace" ls -l "$work/files" >/dev/null
    printf 'true=%s ls=%s\n' "$(wc -l <"$work/stderr")" "$(wc -l <"$logs/ls.trace")"
    strace -c -o "$logs/ls.stats" ls -l "$work/files" >/dev/null
    cat "$logs/ls.stats"
    path=$work/files/present
    missing=$work/files/absent
    cmd=(/bin/sh -c 'read -r line < "$1"; read -r other < "$2"; :' _ "$path" "$missing")
    strace -o "$work/all" "${cmd[@]}" 2>/dev/null
    strace -e trace=%file -o "$work/files-only" "${cmd[@]}" 2>/dev/null
    strace -e trace=openat -o "$work/open-only" "${cmd[@]}" 2>/dev/null
    strace -e trace=openat -P "$path" -P "$missing" -o "$work/path-only" "${cmd[@]}" 2>/dev/null
    strace -z -e trace=openat -P "$path" -P "$missing" -o "$work/success-only" "${cmd[@]}" 2>/dev/null
    prior=999999
    for type in all files-only open-only path-only success-only; do
        count=$(wc -l <"$work/$type")
        printf '%s %d\n' "$type" "$count"
        test "$count" -lt "$prior"
        prior=$count
    done
    LAB07_DEMO_FILE=$path strace -y -s 100 -e trace=read -o "$logs/fd-paths.trace" "$src/lab07-demo" alpha >/dev/null
    LAB07_DEMO_FILE=$path strace -s 4 -e trace=read -o "$logs/fd-short.trace" "$src/lab07-demo" alpha >/dev/null
    grep -F "<$path>" "$logs/fd-paths.trace"
    env -i LAB07_TRACE=example PATH=/bin:/usr/bin strace -v -s 120 -e trace=execve -o "$logs/environment.trace" /bin/true
    grep -F LAB07_TRACE=example "$logs/environment.trace"
)

children() (
    set -e
    command=(/bin/sh -c '/bin/true & /bin/true & /bin/true & /bin/true & /bin/true & wait; :')
    strace -o "$work/parent" "${command[@]}"
    strace -fo "$logs/children.trace" "${command[@]}"
    strace -f -e trace=execve -o "$logs/children-exec.trace" "${command[@]}"
    a=$(wc -l <"$work/parent")
    b=$(wc -l <"$logs/children.trace")
    printf 'parent=%s followed=%s\n' "$a" "$b"
    test "$b" -gt "$((2*a))"
    test "$(grep -c 'execve(' "$logs/children-exec.trace")" -eq 6
    test "$(grep -cE '^[0-9]+[[:space:]]' "$logs/children.trace")" -eq "$b"
    grep -m2 -- '--- SIGCHLD' "$logs/children.trace"
    cp "$src/lab07-demo" "$work/demo-stripped"
    strip --strip-all "$work/demo-stripped"
    printf 'ALT\n' >"$work/stack-input"
    LAB07_DEMO_FILE="$work/stack-input" strace -k -e trace=read -o "$logs/stack-debug.trace" "$src/lab07-demo" alpha >/dev/null
    LAB07_DEMO_FILE="$work/stack-input" strace -k -e trace=read -o "$logs/stack-stripped.trace" "$work/demo-stripped" alpha >/dev/null
    grep -E 'lab07-demo\(main\+' "$logs/stack-debug.trace"
    grep 'demo-stripped' "$logs/stack-stripped.trace"
)

levels() (
    set -e
    data=$work/levels-input
    printf 'ALT\n' >"$data"
    LAB07_DEMO_FILE=$data ltrace -o "$logs/library.trace" "$src/lab07-demo" alpha >/dev/null
    LAB07_DEMO_FILE=$data strace -o "$logs/syscalls.trace" "$src/lab07-demo" alpha >/dev/null
    grep -E 'strlen\(|strcmp\(|open\(|read\(' "$logs/library.trace"
    grep -E 'openat\(|read\(' "$logs/syscalls.trace" | tail -4
    cc -static "${LAB07_STATIC_LDFLAGS:-}" -o "$work/demo-static" "$src/demo.c"
    file "$work/demo-static"
    ltrace -o "$logs/static-ltrace.trace" "$work/demo-static" alpha >/dev/null 2>"$logs/static-ltrace.err" || :
    if grep -Eq 'rand\(|printf\(' "$logs/static-ltrace.trace"; then exit 1; fi
)

kernel_trace() (
    set -e
    printf 'ptrace_scope='; cat /proc/sys/kernel/yama/ptrace_scope
    sleep 15 &
    child=$!
    trap 'kill "$child" 2>/dev/null || true' EXIT
    timeout 3 strace -p "$child" >"$work/attach" 2>&1 || :
    cat "$work/attach"
    grep -F 'Operation not permitted' "$work/attach"
    if command -v gdb >/dev/null; then
        gdb -nx -batch -ex 'info threads' -p "$child" >"$work/gdb-attach" 2>&1 || :
        cat "$work/gdb-attach"
        grep -F 'Operation not permitted' "$work/gdb-attach"
    fi
)

preload() (
    set -e
    nm -D "$src/lab07-demo" | grep -E ' U rand(@|$)'
    nm -D "$src/libconstant.so" | grep ' T rand$'
    for run in 1 2 3; do
        LD_PRELOAD="$src/libconstant.so" "$src/lab07-demo" alpha > "$work/preloaded"
        diff -u <(printf 'alpha 42\n%.0s' {1..3}) "$work/preloaded"
    done
    "$src/lab07-demo" alpha >"$work/ordinary"
    if cmp -s "$work/ordinary" "$work/preloaded"; then exit 1; fi
    sleep 1
    "$src/lab07-demo" alpha >"$work/ordinary-next"
    if cmp -s "$work/ordinary" "$work/ordinary-next"; then exit 1; fi
    ldd "$src/lab07-demo" >"$logs/ldd-normal.txt"
    LD_PRELOAD="$src/libconstant.so" ldd "$src/lab07-demo" >"$logs/ldd-preloaded.txt"
    awk '/libconstant.so/{a=NR} /libc.so/{b=NR} END{exit !(a && b && a<b)}' "$logs/ldd-preloaded.txt"
    cat "$work/ordinary" "$work/preloaded" "$logs/ldd-preloaded.txt"
)

move_checks() (
    set -e
    move=$src/lab07-move
    case_run() {
        local expected=$1 rc=0
        shift
        "$move" "$@" >"$work/move.stdout" 2>"$work/move.stderr" || rc=$?
        test "$rc" -eq "$expected"
        printf 'exit=%s: ' "$rc"; cat "$work/move.stderr"
    }
    source=$work/move-source
    dest=$work/move-target
    printf 'ALT\0sample\n' >"$source"
    cp "$source" "$work/expected"
    case_run 2
    case_run 3 "$work/not-present" "$dest"
    test ! -e "$dest"
    chmod 000 "$source"
    case_run 4 "$source" "$dest"
    test -f "$source" && test ! -e "$dest"
    chmod 600 "$source"
    case_run 5 "$source" "$source"
    cmp "$source" "$work/expected"
    mkdir "$work/readonly"
    chmod 500 "$work/readonly"
    case_run 6 "$source" "$work/readonly/target"
    chmod 700 "$work/readonly"
    test -f "$source" && test ! -e "$work/readonly/target"
    printf 'previous\n' >"$dest"
    case_run 0 "$source" "$dest"
    test ! -e "$source"
    cmp "$dest" "$work/expected"
    echo 'overwrite: content verified, source removed'
)

injection() (
    set -e
    move=$src/lab07-move
    source=$work/injected-source
    dest=$work/injected-target
    printf 'ALT\n' >"$source"
    cp "$source" "$work/injected-copy"
    strace -y -e trace=read -o "$logs/move-baseline.trace" "$move" "$source" "$dest"
    first=$(awk -v f="$source" '/^read\(/ {n++; if(index($0,f)){print n; exit}}' "$logs/move-baseline.trace")
    printf 'application read=%d loader read=%d\n' "$first" "$((first-1))"
    for pair in "read:error=EIO:when=$first|7|read: Input/output error" 'write:error=ENOSPC:when=1|8|write: No space left on device' 'rename:error=EACCES:when=1|10|rename target: Permission denied'; do
        IFS='|' read -r rule expected diagnostic <<<"$pair"
        cp "$work/injected-copy" "$source"
        rm -f "$dest"
        rc=0
        strace --inject="$rule" -o "$work/$expected.trace" "$move" "$source" "$dest" 2>"$work/injected.err" || rc=$?
        test "$rc" -eq "$expected"
        grep -Fx "$diagnostic" "$work/injected.err"
        cmp "$source" "$work/injected-copy"
        test ! -e "$dest"
        printf 'injection %s: code=%s, source retained\n' "$rule" "$rc"
    done
    protected=$work/lab07-protected-source
    cp "$work/injected-copy" "$protected"
    rc=0
    LD_PRELOAD="$src/libguard.so" "$move" "$protected" "$dest" || rc=$?
    test "$rc" -eq 11 && test -f "$protected"
    cmp "$dest" "$work/injected-copy"
    LD_PRELOAD="$src/libguard.so" "$move" "$source" "$dest"
    test ! -e "$source"
    printf 'protected source preserved; ordinary source removed\n'
)

rpm_installed() (
    set -e
    rpm -qpl "$LAB07_RPM" | sort | diff -u <(printf '/usr/bin/lab07-move\n/usr/bin/lab07-signals\n') -
    grep -F 'PASS missing-handler' "$LAB07_GEAR_LOG"
)

check build make -C "$src" all lab07-demo libconstant.so libguard.so
check trace-filters trace_filters
check descendant-tracing children
if command -v ltrace >/dev/null && [[ -n ${LAB07_STATIC_LDFLAGS:-} ]]; then check tracing-levels levels; else skip tracing-levels; fi
check ptrace-restriction kernel_trace
if [[ -r /sys/kernel/tracing/available_tracers ]]; then check kernel-tracers cat /sys/kernel/tracing/available_tracers; else skip kernel-tracers; fi
check preload preload
check move-files move_checks
check failure-injection injection
check package-tests make -C "$src" test
if [[ -n ${LAB07_RPM:-} && -n ${LAB07_GEAR_LOG:-} ]]; then check rpm-build rpm_installed; else skip rpm-build; fi
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$passed" "$failed" "$skipped"
((failed == 0))

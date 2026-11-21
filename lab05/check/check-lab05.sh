#!/bin/bash
set -uo pipefail
export LC_ALL=C DEBUGINFOD_URLS=
root=$(cd "$(dirname "$0")/.." && pwd) || exit 1
src=$root/sources
logs=${LAB05_LOGS:-"$root/logs"}
work=$(mktemp -d) || exit 1
mkdir -p "$logs" || exit 1
trap 'rm -rf -- "$work"' EXIT
passed=0 failed=0 skipped=0
check() {
    local name=$1
    shift
    "$@" >"$logs/$name.log" 2>&1 &
    if wait "$!"; then printf 'PASS %s\n' "$name"; ((passed+=1)); else printf 'FAIL %s\n' "$name"; ((failed+=1)); fi
}
skip() { printf 'SKIP %s\n' "$1"; ((skipped+=1)); }

elf() (
    set -e
    cd "$src"
    file progression.o libprogression.so progression-debug
    readelf -h progression.o | grep -E 'Type:.*REL'
    readelf -h libprogression.so | grep -E 'Type:.*DYN'
    readelf -h progression-debug | tee "$work/header"
    readelf -n progression-debug | tee "$work/notes"
    a=$(file progression-debug | sed -n 's/.*BuildID\[sha1\]=\([0-9a-f]*\).*/\1/p')
    b=$(sed -n 's/.*Build ID: \([0-9a-f]*\).*/\1/p' "$work/notes")
    test -n "$a" && test "$a" = "$b"
    printf 'Build ID matches: %s\n' "$a"
    ph=$(awk -F': *' '/Number of program headers:/ {print $2}' "$work/header")
    sh=$(awk -F': *' '/Number of section headers:/ {print $2}' "$work/header")
    test "$(readelf -lW progression-debug | awk '/^[[:space:]]+[A-Z_]+[[:space:]]+0x/ {n++} END {print n+0}')" -eq "$ph"
    test "$(readelf -SW progression-debug | grep -cE '^  \[[[:space:]]*[0-9]+\]')" -eq "$sh"
    printf 'Header entries: program=%s section=%s\n' "$ph" "$sh"
    address=$(awk '/Entry point address:/ {print $NF}' "$work/header")
    objdump -d progression-debug > "$work/disasm"
    grep -E "^0*${address#0x} <" "$work/disasm"
    readelf -SW progression-debug | grep '\.debug_'
    diff -u <(printf '0\n2\n4\n6\n') <(./progression 0 6 2)
    diff -u <(printf '0\n1\n2\n') <(./progression 2)
    diff -u <(printf '2\n1\n0\n') <(./progression 2 0)
    ./progression | grep -F Usage
)

variants() (
    set -e
    cd "$src"
    stat -c '%n %s bytes' progression progression-debug progression-opt
    gdb -nx -batch -ex 'info line main' progression > "$work/plain" 2>&1 || true
    cat "$work/plain"
    grep -Ei 'no line number information|no symbol table|no debugging symbols' "$work/plain"
    gdb -nx -batch -ex 'list main' progression-debug | grep -F 'int main'
    gdb -nx -batch -ex 'list main' progression-opt | grep -F 'int main'
    gdb -nx -batch -ex 'break progression' -ex 'run 0 4 2' -ex 'info args' -ex 'info locals' -ex 'step' -ex 'info args' progression-opt | tee "$work/optimized"
    grep -F '<optimized out>' "$work/optimized"
    mkdir "$work/source" "$work/relocated"
    cp progression.c "$work/source/"
    (cd "$work/source"; cc -g -O0 -Wall -Wextra -Wpedantic -o demo progression.c)
    mv "$work/source/demo" "$work/relocated/"
    mv "$work/source/progression.c" "$work/relocated/saved.c"
    (cd "$work/relocated"; gdb -nx -batch -ex 'list main' ./demo) > "$work/no-source" 2>&1 || true
    cat "$work/no-source"
    grep -Ei 'No such file|Source file' "$work/no-source"
    mv "$work/relocated/saved.c" "$work/source/progression.c"
    (cd "$work/relocated"; gdb -nx -batch -ex 'list main' ./demo) | grep -F 'int main'
)

logic_error() (
    set -e
    cd "$src"
    gdb -nx -batch -ex 'break source_value' -ex 'break transform' -ex run -ex next -ex 'print value' -ex continue -ex 'bt 3' -ex 'info args' -ex 'print scale' -ex 'up' -ex 'info args' -ex down diagnostic | tee "$work/logic"
    grep -E '^#2 +.*main' "$work/logic"
    printf 'Before: '; ./diagnostic
    printf 'After: '; ./diagnostic-fixed
    diff -u <(printf '18\n') <(./diagnostic)
    diff -u <(printf '12\n') <(./diagnostic-fixed)
)

symbols() (
    set -e
    cp "$src/progression-debug" "$work/stripped"
    mkdir "$work/symbols"
    objcopy --only-keep-debug "$work/stripped" "$work/symbols/stripped.debug"
    strip --strip-all "$work/stripped"
    stat -c '%n %s bytes' "$src/progression-debug" "$work/stripped"
    file "$src/progression-debug" "$work/stripped"
    gdb -nx -batch -ex 'list main' "$work/stripped" > "$work/no-symbols" 2>&1 || true
    cat "$work/no-symbols"
    grep -Ei 'no symbol table|no debugging symbols' "$work/no-symbols"
    objcopy --add-gnu-debuglink="$work/symbols/stripped.debug" "$work/stripped"
    mv "$work/symbols/stripped.debug" "$work/stripped.debug"
    gdb -nx -batch -ex 'list main' "$work/stripped" | grep -F 'int main'
)

batch() (
    set -e
    for round in 1 2 3; do
        for scenario in conditional range; do
            gdb -nx -batch -x "$root/check/$scenario.gdb" "$src/progression-debug" >"$work/$scenario-$round.txt" 2>&1
            cat "$work/$scenario-$round.txt"
        done
        grep -h '^CHECK ' "$work/conditional-$round.txt" "$work/range-$round.txt" > "$work/result"
        diff -u "$root/check/debug.expected" "$work/result"
        printf 'Round %d: %s tagged lines\n' "$round" "$(wc -l < "$work/result")"
    done
)

gdb_init() (
    set -e
    cd "$work"
    printf 'define lab05-marker\n  echo LAB05_LOCAL_INIT\\n\nend\n' > .gdbinit
    gdb -nh -batch -iex 'set auto-load safe-path /nonexistent' -ex lab05-marker >no-init 2>&1 || true
    cat no-init
    grep -qi 'undefined command' no-init
    gdb -nh -batch -iex "add-auto-load-safe-path $work/.gdbinit" -ex lab05-marker | grep -Fx LAB05_LOCAL_INIT
)

remote() (
    set -e
    cd "$src"
    gdbserver --once 127.0.0.1:0 ./progression-debug 0 6 2 > "$work/server" 2>&1 &
    server=$!
    trap 'kill "$server" 2>/dev/null || true' EXIT
    for i in {1..30}; do
        port=$(awk '/Listening on port/ {print $NF; exit}' "$work/server")
        [[ -n $port ]] && break
        sleep 0.1
    done
    test -n "$port"
    gdb -nx -batch -ex "target remote 127.0.0.1:$port" -ex 'break print_term' -ex continue -ex 'list print_term' -ex 'info args' -ex detach progression-debug > "$work/client" 2>&1
    cat "$work/server" "$work/client"
    grep -Ei 'Remote debugging from host' "$work/server"
    grep -E 'Breakpoint [0-9]+, print_term' "$work/client"
)

attach_observation() (
    set -e
    printf 'ptrace_scope='; cat /proc/sys/kernel/yama/ptrace_scope
    sleep 20 &
    target=$!
    trap 'kill "$target" 2>/dev/null || true; wait "$target" 2>/dev/null || true' EXIT
    gdb -nx -batch -ex 'info threads' -p "$target" > "$work/attach" 2>&1 || true
    cat "$work/attach"
    grep -Ei 'ptrace: Operation not permitted|Thread [0-9]' "$work/attach"
)

hasher_check() (
    set -e
    hsh-run "$LAB05_HASHER" -- rpm -q gdb gdbserver
    hsh-run --mountpoints=/proc "$LAB05_HASHER" -- /bin/sh -c 'test -r /proc/self/status && gdb -nx -batch -ex "break main" -ex run --args /.in/progression-debug 2'
)

distro_debug() (
    set -e
    id=$(readelf -n /lib64/libc.so.6 | sed -n 's/.*Build ID: \([0-9a-f]*\).*/\1/p')
    test -s "$LAB05_DEBUG_ROOT/cache/$id/debuginfo"
    gdb -nx -batch -ex "set debug-file-directory $LAB05_DEBUG_ROOT/files/usr/lib/debug" \
        -ex start -ex 'info address __libc_start_call_main' --args "$src/progression-debug" 2 |
        grep -F '__libc_start_call_main'
)

check build make -C "$src" all
check elf-format elf
if command -v gdb >/dev/null; then
    check debug-builds variants
    check logic-error logic_error
    check separate-debug symbols
    check batch-gdb batch
    check local-init gdb_init
    check attach-observation attach_observation
else
    skip debug-builds; skip logic-error; skip separate-debug; skip batch-gdb; skip local-init; skip attach-observation
fi
if command -v gdbserver >/dev/null; then check gdbserver-loopback remote; else skip gdbserver-loopback; fi
if [[ -n ${LAB05_HASHER:-} ]]; then check hasher-gdb hasher_check; else skip hasher-gdb; fi
if [[ -n ${LAB05_DEBUG_ROOT:-} ]]; then check distro-debug-server distro_debug; else skip distro-debug-server; fi
skip second-hasher-session
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$passed" "$failed" "$skipped"
((failed == 0))

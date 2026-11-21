#!/bin/bash
set -euo pipefail
export LC_ALL=C
ulimit -c 0
ulimit -f 100000
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
data=$work/fixture
strace -y -e trace=read -o "$work/baseline" ./lab07-signals "$data" >"$work/normal"
diff -u tests/normal.txt "$work/normal"
echo 'PASS normal'
first=$(awk '/^read\(/ {++n; if ($0 ~ /, "ALT", 3\) += 3$/) {print n; exit}}' "$work/baseline")
test "$first" -ge 1
printf 'First application read: %s; loader reads: %s\n' "$first" "$((first-1))"
rc=0
strace --inject="read:error=EIO:when=$first" -o "$work/eio.trace" ./lab07-signals "$data" >"$work/eio" 2>"$work/eio.err" || rc=$?
test "$rc" -eq 8
grep -Fx 'read: Input/output error' "$work/eio.err"
diff -u tests/eio.txt "$work/eio"
echo 'PASS read-error'
strace --inject="read:retval=1:signal=SIGUSR2:when=$first+" -o "$work/signal.trace" ./lab07-signals "$data" >"$work/signal"
diff -u tests/signal.txt "$work/signal"
echo 'PASS return-value-and-repeated-signal'
rc=0
strace --inject=rt_sigaction:error=EINVAL:when=1 --inject="read:signal=SIGUSR1:when=$first" -o "$work/unhandled.trace" ./lab07-signals "$data" >"$work/unhandled" 2>"$work/unhandled.err" || rc=$?
test "$rc" -eq 138
grep -q 'killed by SIGUSR1' "$work/unhandled.trace"
printf '%s\n' 'killed by SIGUSR1' >>"$work/unhandled"
diff -u tests/unhandled.txt "$work/unhandled"
echo 'PASS missing-handler'

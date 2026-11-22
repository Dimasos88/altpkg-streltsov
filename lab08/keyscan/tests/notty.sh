#!/bin/sh
set -eu
message=$(mktemp)
trap 'rm -f "$message"' EXIT
rc=0
./lab08-keys </dev/null >/dev/null 2>"$message" || rc=$?
test "$rc" -eq 2
grep -Fx "${LAB08_EXPECT_NOTTY:-stdin is not a terminal}" "$message"

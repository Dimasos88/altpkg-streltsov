#!/bin/bash
set -uo pipefail
export LC_ALL=C
base=$(cd "$(dirname "$0")/.." && pwd) || exit 1
work=$(mktemp -d) || exit 1
trap 'rm -rf -- "$work"' EXIT
logs=${LAB06_LOGS:-"$base/logs"}
mkdir -p "$logs" || exit 1
input=$base/check/sample.txt
match=$base/sources/lab06-match
replace=$base/sources/lab06-replace
passed=0 failed=0 skipped=0
check() {
  local label=$1
  shift
  "$@" >"$logs/$label.log" 2>&1 &
  if wait "$!"; then echo "PASS $label"; ((passed+=1)); else echo "FAIL $label"; ((failed+=1)); fi
}

globs() (
  set -e
  cd "$work"
  touch a1.txt a2.log b1.txt z3.txt
  printf '%s\n' *.txt | diff -u <(printf '%s\n' a1.txt b1.txt z3.txt) -
  printf '%s\n' ?1.txt | diff -u <(printf '%s\n' a1.txt b1.txt) -
  printf '%s\n' [ab]1.txt | diff -u <(printf '%s\n' a1.txt b1.txt) -
  printf '%s\n' [a-c]1.txt | diff -u <(printf '%s\n' a1.txt b1.txt) -
  printf '%s\n' [!a]*.txt | diff -u <(printf '%s\n' b1.txt z3.txt) -
  case b1.txt in [ab]1.txt) echo 'case: match';; *) exit 1;; esac
  printf '%s\n' no*.dat | grep -Fx 'no*.dat'
  printf '%s\n' a1.txt txt ab aaaaa xyz > glob-data
  grep a*txt glob-data > expanded
  grep 'a*txt' glob-data > literal || test "$?" -eq 1
  if cmp -s expanded literal; then exit 1; fi
  set -f
  grep a*txt glob-data > noglob || test "$?" -eq 1
  cmp literal noglob
  printf 'Expanded: '; cat expanded
  printf 'Quoted and noglob: %s matches\n' "$(wc -l < literal)"
)

counts() (
  set -e
  while IFS=$'\t' read -r regex expected; do
    actual=$(grep -Ec "$regex" "$input") || test "$?" -eq 1
    printf '%s\t%s\t%s\n' "$regex" "$actual" "$expected"
    test "$actual" -eq "$expected"
  done < "$base/check/patterns.tsv"
  printf 'aab\n' | grep -Eob 'a|aa' | diff -u <(printf '0:aa\n') -
  printf 'aab\n' | grep -Eob 'a|aa'
)

dialects() (
  set -e
  grep '^a\{2\}b$' "$input" >"$work/bre"
  grep -E '^a{2}b$' "$input" >"$work/ere"
  diff -u "$work/bre" "$work/ere"
  if grep '^a+b$' "$input"; then exit 1; fi
  grep -E '^a+b$' "$input"
  grep -E '^(ab|a{2,3})b$' "$input"
  printf 'C: '; LC_ALL=C grep -c '^[[:alpha:]]' "$input"
  printf 'ru_RU.utf8: '; LC_ALL=ru_RU.utf8 grep -c '^[[:alpha:]]' "$input"
  test "$(LC_ALL=C grep -c '^[[:alpha:]]' "$input")" -lt "$(LC_ALL=ru_RU.utf8 grep -c '^[[:alpha:]]' "$input")"
  for shell in bash zsh; do
    printf '%s builtin: ' "$shell"
    "$shell" -c "echo 'a\\nb'" | od -An -tx1
    printf '%s external: ' "$shell"
    "$shell" -c "/bin/echo 'a\\nb'" | od -An -tx1
  done
)

backrefs() (
  set -e
  grep '^\([[:alpha:]]\+\) \1$' "$input" | diff -u <(printf 'word word\ncat cat\n') -
  printf 'aa0\nab0\n' | grep '^\(a\)\10$' | grep -Fx aa0
  printf 'cat cat\n' | sed 's/cat/dog/' | grep -Fx 'dog cat'
  printf 'cat cat\n' | sed 's/cat/dog/g' | grep -Fx 'dog dog'
  printf 'abc\n' | sed -E 's/((a)b)(c)/\3-\2-\1/' | grep -Fx 'c-a-ab'
  printf 'abc\n' | tr 'ab' 'xy' | grep -Fx xyc
  printf 'abc\n' | sed 's/ab/x/' | grep -Fx xc
)

matching() (
  set -e
  while IFS=$'\t' read -r regex _; do
    grep -E "$regex" "$input" >"$work/grep" || test "$?" -eq 1
    "$match" "$regex" <"$input" >"$work/match" || test "$?" -eq 1
    diff -u "$work/grep" "$work/match"
  done < "$base/check/patterns.tsv"
  printf 'alpha9\n' | "$match" --groups '^([a-z]+)([0-9]+)$' | tee "$work/groups"
  diff -u <(printf 'alpha9\n1 [0,5) alpha\n2 [5,6) 9\n') "$work/groups"
  if "$match" >/dev/null; then exit 1; fi
  if "$match" '[' <"$input"; then exit 1; fi
  yes "$(printf '%4096s' A)" | head -n 12000 > "$work/large" || test "${PIPESTATUS[0]}" -eq 141
  /usr/bin/time -f '%M' -o "$work/normal" "$match" A <"$work/large" >/dev/null
  /usr/bin/time -f '%M' -o "$work/leak" "$base/sources/lab06-measure-leak" A <"$work/large" >/dev/null
  printf 'RSS normal=%s KiB; without release=%s KiB\n' "$(cat "$work/normal")" "$(cat "$work/leak")"
  test "$(cat "$work/leak")" -gt "$(( $(cat "$work/normal") + 8192 ))"
)

replacements() (
  set -e
  while IFS='|' read -r regex replacement line; do
    printf '%s\n' "$line" | sed -E "s~$regex~$replacement~" >"$work/sed"
    "$replace" "$regex" "$replacement" "$line" >"$work/replace"
    diff -u "$work/sed" "$work/replace"
    printf '%s => %s\n' "$line" "$(cat "$work/replace")"
  done <<'CASES'
cat|dog|cat cat
(cat)|[\1]|cat
([a-z]+)([0-9]+)|\2-\1|x12
a|&-&|abc
^|>|alpha
$|<|alpha
x|y|none
[[:digit:]]+|N|a123b
(a)?b|<\1>|b
a|\\|a
CASES
  if "$replace" '(a)' '\2' a; then exit 1; fi
  if "$replace" '[' x a; then exit 1; fi
  printf '%s' '\\' | od -An -tx1
  printf '%s' "\\" | od -An -tx1
  printf '%s' \\\\\\\\ | od -An -tx1
)

package_check() (
  set -e
  rpm -qpl "$LAB06_RPM" | sort | diff -u <(printf '/usr/bin/lab06-match\n/usr/bin/lab06-replace\n') -
  test -f "$LAB06_DEBUG_RPM"
  printf 'alpha9\n' | hsh-run "$LAB06_HASHER" -- lab06-match --groups '^([a-z]+)([0-9]+)$' | diff -u <(printf 'alpha9\n1 [0,5) alpha\n2 [5,6) 9\n') -
  hsh-run "$LAB06_HASHER" -- lab06-replace '(cat)' '[\1]' 'cat cat' | grep -Fx '[cat] cat'
)

check build make -C "$base/sources" all lab06-measure-leak
check shell-globs globs
check regex-counts counts
check dialects-locales dialects
check backreferences backrefs
check c-match matching
check c-replace replacements
if [[ -n ${LAB06_HASHER:-} && -n ${LAB06_RPM:-} && -n ${LAB06_DEBUG_RPM:-} ]]; then
  check rpm-install package_check
else
  echo 'SKIP rpm-install'
  ((skipped+=1))
fi
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$passed" "$failed" "$skipped"
((failed == 0))

#!/bin/sh
set -eu
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
printf ALT > "$w/input"
{
 for cmd in md5sum sha1sum sha256sum; do "$cmd" "$w/input" | cut -d ' ' -f1; done
 openssl dgst -sha256 -binary "$w/input" | base64
 md5sum "$w/input" | cut -d ' ' -f1
} > "$w/expected"
printf 'md5 "ALT"\nsha1 %s\nsha256 %s\nSha256 "ALT"\nunknown "ALT"\nmd5 %s\n' "$w/input" "$w/input" "$w/input" |
 ./lab08-hash >"$w/out" 2>"$w/errors"
grep -Fx 'unknown algorithm: unknown' "$w/errors"
diff -u "$w/expected" "$w/out"
cat "$w/out"

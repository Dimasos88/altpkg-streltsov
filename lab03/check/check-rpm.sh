#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hasher_dir=$1
stage=$(mktemp -d)
trap 'rm -r -- "$stage"' EXIT

mkdir -p "$stage"/{SOURCES,SRPMS} "$stage/lab03-1.0"
cp "$root/sources/"{Makefile,main.c,output.c,counter.c,lab03.h} "$stage/lab03-1.0/"
tar -C "$stage" -czf "$stage/SOURCES/lab03-1.0.tar.gz" lab03-1.0
rpmbuild -bs --define "_topdir $stage" "$root/specs/lab03.spec"
hsh --lazy-cleanup "$hasher_dir" "$stage/SRPMS/lab03-1.0-alt1.src.rpm"

arch=$(rpm --eval '%{_arch}')
bindir=$(rpm --eval '%{_bindir}')
libdir=$(rpm --eval '%{_libdir}')
repo=$hasher_dir/repo/$arch/RPMS.hasher
package=$repo/lab03-1.0-alt1.$arch.rpm
debug=$repo/lab03-debuginfo-1.0-alt1.$arch.rpm
ls -l -- "$package" "$debug"
rpm -qpl "$package" | tee "$stage/rpm-files"
grep -Fx "$bindir/lab03-static" "$stage/rpm-files"
grep -Fx "$bindir/lab03-shared" "$stage/rpm-files"
grep -Fx "$libdir/liblab03.so.1" "$stage/rpm-files"
rpm -qp --requires "$package" | tee "$stage/rpm-requires"
rpm -qp --provides "$package" | tee "$stage/rpm-provides"
grep -F 'liblab03.so.1' "$stage/rpm-provides"

hsh-install "$hasher_dir" lab03
hsh-run "$hasher_dir" -- env -u LD_LIBRARY_PATH lab03-static alpha beta gamma > "$stage/static.stdout"
hsh-run "$hasher_dir" -- env -u LD_LIBRARY_PATH lab03-shared alpha beta gamma > "$stage/shared.stdout"
cmp "$stage/static.stdout" "$stage/shared.stdout"
cmp "$stage/shared.stdout" "$root/check/three.stdout"
hsh-run "$hasher_dir" -- readelf -d "$bindir/lab03-shared" > "$stage/shared.needed"
hsh-run "$hasher_dir" -- readelf -d "$bindir/lab03-static" > "$stage/static.needed"
grep -F 'Shared library: [liblab03.so.1]' "$stage/shared.needed"
if grep -F 'Shared library: [liblab03.so.1]' "$stage/static.needed"; then
    exit 1
fi
hsh-run "$hasher_dir" -- env -u LD_LIBRARY_PATH ldd "$bindir/lab03-shared" > "$stage/installed.ldd"
cat "$stage/installed.ldd"
loaded=$(awk '$1 == "liblab03.so.1" && $2 == "=>" {print $3}' "$stage/installed.ldd")
test -n "$loaded"
loaded_real=$(hsh-run "$hasher_dir" -- readlink -f "$loaded")
packed_real=$(hsh-run "$hasher_dir" -- readlink -f "$libdir/liblab03.so.1")
test "$loaded_real" = "$packed_real"
if grep -F 'not found' "$stage/installed.ldd"; then
    exit 1
fi

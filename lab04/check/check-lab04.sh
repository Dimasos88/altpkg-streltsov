#!/bin/bash
set -uo pipefail
export LC_ALL=C
root=$(cd -- "$(dirname -- "$0")/.." && pwd) || exit 1
work=$(mktemp -d) || exit 1
trap 'rm -rf -- "$work"' EXIT
logs=${LAB04_LOGS:-"$root/logs"}
mkdir -p -- "$logs" || exit 1
export XDG_CONFIG_HOME=$work/config TMPDIR=$work
todo=$root/sources/lab04-todo
passed=0 failed=0 skipped=0

check() {
    local name=$1
    shift
    "$@" >"$logs/$name.log" 2>&1 &
    if wait "$!"; then
        printf 'PASS %s\n' "$name"
        ((passed+=1))
    else
        printf 'FAIL %s\n' "$name"
        ((failed+=1))
    fi
}
skip() { printf 'SKIP %s\n' "$1"; ((skipped+=1)); }

shell_basics() (
    set -e
    shopt -s expand_aliases
    alias lab04ls='ls --color=auto'
    type -a cd printf sort rpm lab04ls
    rpm -qf "$(command -v sort)" "$(command -v rpm)"
    local_value=parent
    bash -c 'printf "Before export: <%s>\n" "${local_value:-}"; test -z "${local_value:-}"'
    export local_value
    bash -c 'printf "After export: <%s>\n" "$local_value"; test "$local_value" = parent; local_value=child'
    printf 'Parent: %s\n' "$local_value"
    test "$local_value" = parent
    v=one:two:three
    printf '#  %s\n## %s\n%%  %s\n%%%% %s\n' "${v#*:}" "${v##*:}" "${v%:*}" "${v%%:*}"
    emit() { printf 'stdout\n'; printf 'stderr\n' >&2; }
    emit >"$work/combined" 2>&1
    emit 2>&1 >"$work/stdout"
    emit >"$work/default-fd"
    cat "$work/combined" "$work/stdout"
    if diff -u "$work/stdout" "$work/combined"; then exit 1; fi
    cmp "$work/default-fd" "$work/stdout"
    while IFS= read -r name; do
        if rpm -q --qf '%{NAME}\n' "$name" | sort -u | head -n 1 > "$work/pipeline"; then
            diff -u <(printf '%s\n' "$name") "$work/pipeline" || exit 1
            printf 'pipeline: %s, exit 0\n' "$name"
        else
            exit 1
        fi
    done <<'PACKAGES'
coreutils
PACKAGES
)

temporary_cleanup() (
    set -e
    a=$(bash "$root/sources/temp-demo")
    b=$(bash "$root/sources/temp-demo")
    printf '%s\n%s\n' "$a" "$b"
    [[ $a != "$b" && ! -e $a && ! -e $b ]]
    if bad=$(bash "$root/sources/temp-demo" error); then exit 1; fi
    [[ ! -e $bad ]]
    for sig in INT TERM; do
        python3 - "$root/sources/temp-demo" "$sig" <<'PY'
import os, signal, subprocess, sys
p = subprocess.Popen(["bash", sys.argv[1], "wait"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
try:
    path = p.stdout.readline().strip()
    assert os.stat(path).st_mode & 0o777 == 0o600
    p.send_signal(getattr(signal, "SIG" + sys.argv[2]))
    assert p.wait(timeout=5) == 128 + getattr(signal, "SIG" + sys.argv[2])
    assert not os.path.exists(path)
    print(sys.argv[2], "mode=600, cleaned:", path)
finally:
    if p.poll() is None:
        p.kill()
        p.wait()
PY
    done
    d=$(mktemp -d "$work/dir.XXX")
    [[ $(stat -c %a "$d") == 700 ]]
    f=$(mktemp -u "$work/dry.XXX")
    [[ ! -e $f ]]
    if mktemp "$work/short.XX"; then exit 1; fi
    stat -c 'directory mode=%a' "$d"
)

text_processing() (
    set -e
    ps -eo pid=,comm= | awk 'NF>=2 {print $1,$2}' > "$logs/process-commands.txt"
    ps -eo pid=,uid= | awk 'NF==2 {print $1,$2}' > "$logs/process-users.txt"
    sort -k1,1 "$logs/process-commands.txt" >"$work/commands"
    sort -k1,1 "$logs/process-users.txt" >"$work/users"
    join --check-order "$work/commands" "$work/users" > "$logs/process-joined.txt"
    test -s "$logs/process-joined.txt"
    cut -d ' ' -f2 "$logs/process-joined.txt" | tr '[:lower:]' '[:upper:]' >"$work/upper"
    head -n 3 "$work/upper"
    tail -n 3 "$work/upper"
    locale -a
    national=$(locale -a | grep -i -m1 '^ru_RU.*utf')
    printf 'a 1\nB 2\nz 3\n' >"$work/case-a"
    printf 'a x\nB y\nz q\n' >"$work/case-b"
    sort "$work/case-a" >"$work/c-a"
    sort "$work/case-b" >"$work/c-b"
    if LC_ALL="$national" join --check-order "$work/c-a" "$work/c-b" > /dev/null; then exit 1; fi
    join --check-order "$work/c-a" "$work/c-b"
    printf 'ALT\n' >"$work/bytes"
    hexdump -C "$work/bytes"
    od -An -tx1 "$work/bytes"
    xxd "$work/bytes"
    rpm -qf "$(command -v hexdump)" "$(command -v od)" "$(command -v xxd)" | tee "$work/hex-packages"
    test "$(sort -u "$work/hex-packages" | wc -l)" -eq 3
)

moreutils_checks() (
    set -e
    printf 'z\na\n' > "$work/rewrite"
    sort < "$work/rewrite" > "$work/rewrite"
    [[ ! -s $work/rewrite ]]
    printf 'z\na\n' > "$work/rewrite"
    sort "$work/rewrite" | sponge "$work/rewrite"
    diff -u <(printf 'a\nz\n') "$work/rewrite"
    ts '[%H:%M:%S]' < "$work/rewrite"
)

todo_checks() (
    set -e
    bash "$todo" list
    test -f "$XDG_CONFIG_HOME/lab04-todo/tasks.tsv"
    bash "$todo" add 'Build the RPM'
    bash "$todo" add 'Read the manual'
    bash "$todo" add 'Verify the logs'
    bash "$todo" done 2
    bash "$todo" list | tee "$work/list"
    diff -u "$root/check/todo.expected" "$work/list"
    test "$(wc -l < "$XDG_CONFIG_HOME/lab04-todo/tasks.tsv")" -eq 3
    [[ -z $(find "$XDG_CONFIG_HOME" -name '.tasks.*' -print -quit) ]]
)

dialog_checks() (
    set -e
    before=$(find "$work" -maxdepth 1 -name 'tmp.*' | sort)
    { sleep 0.4; printf '\033'; sleep 1; } |
        TERM=xterm timeout 10 script -qec "bash '$todo'" "$logs/dialog-session.txt" > /dev/null
    grep -aq 'Lab04 Todo' "$logs/dialog-session.txt"
    [[ $(find "$work" -maxdepth 1 -name 'tmp.*' | sort) == "$before" ]]
    printf 'Dialog menu and cleanup confirmed\n'
)

rpm_checks() (
    set -e
    local artifacts=$1 dependencies
    test "$(rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}' "$artifacts/direct.rpm")" = 'lab04-todo 1.0-alt1'
    dependencies=$(rpm -qp --requires "$artifacts/direct.rpm")
    for dep in /bin/bash coreutils dialog gawk util-linux; do
        grep -Fx "$dep" <<<"$dependencies"
    done
    rpm -qpl "$artifacts/direct.rpm" | grep -Fx /usr/bin/lab04-todo
)

gear_rebuild_checks() (
    set -e
    local artifacts=$1
    test "$(rpm -qp "$artifacts/direct.rpm")" = "$(rpm -qp "$artifacts/gear-old.rpm")"
    diff -u <(rpm -qpl "$artifacts/direct.rpm" | sort) <(rpm -qpl "$artifacts/gear-old.rpm" | sort)
    diff -u <(rpm -qp --requires "$artifacts/direct.rpm" | sort) <(rpm -qp --requires "$artifacts/gear-old.rpm" | sort)
)

version_checks() (
    set -e
    local artifacts=$1 version
    test "$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$artifacts/gear-new.rpm")" = 1.1-alt1
    rpm -qp --changelog "$artifacts/gear-new.rpm" | grep -F 'Add count command'
    export XDG_CONFIG_HOME=$work/version-todo
    for version in old new; do
        mkdir -p "$work/$version"
        (cd "$work/$version"; rpm2cpio "$artifacts/gear-$version.rpm" | cpio -id --quiet)
    done
    if bash "$work/old/usr/bin/lab04-todo" count; then exit 1; fi
    bash "$work/new/usr/bin/lab04-todo" add 'Count test'
    test "$(bash "$work/new/usr/bin/lab04-todo" count)" = 1
)

check bash-syntax bash -n "$todo"
check shell-basics shell_basics
check temporary-cleanup temporary_cleanup
check text-processing text_processing
if command -v sponge >/dev/null && command -v ts >/dev/null; then check moreutils moreutils_checks; else skip moreutils; fi
check todo-cli todo_checks
if command -v dialog >/dev/null; then check todo-dialog dialog_checks; else skip todo-dialog; fi
if [[ -n ${LAB04_RPM_DIR:-} ]]; then
    check rpm-package rpm_checks "$LAB04_RPM_DIR"
    check gear-import gear_rebuild_checks "$LAB04_RPM_DIR"
    check gear-version version_checks "$LAB04_RPM_DIR"
else
    skip rpm-package; skip gear-import; skip gear-version
fi
if [[ -n ${LAB04_GEAR_URL:-} ]]; then
    check gear-remote-tags bash -c 'set -o pipefail; git ls-remote --tags "$1" > "$2" && grep -q "refs/tags/1.0-alt1$" "$2" && grep -q "refs/tags/1.1-alt1$" "$2"' _ "$LAB04_GEAR_URL" "$work/tags"
else
    skip gear-remote-tags
fi
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$passed" "$failed" "$skipped"
((failed == 0))

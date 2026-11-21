#!/bin/bash
set -euo pipefail
number=1
rooter=()
workdir=$HOME/hasher-lab05
while (($#)); do
    case $1 in
        --number) number=${2:?missing number}; shift 2 ;;
        --workdir) workdir=${2:?missing directory}; shift 2 ;;
        --rooter) rooter=(--rooter); shift ;;
        --) shift; break ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done
mkdir -p "$workdir"
if [[ ! -d $workdir/chroot/bin ]]; then
    hsh --number="$number" --initroot-only "$workdir"
fi
hsh-install --number="$number" "$workdir" gdb gdbserver gcc "$@"
if [[ -r /etc/resolv.conf && -d $workdir/chroot/.in ]]; then
    install -m 0644 -T /etc/resolv.conf "$workdir/chroot/.in/lab05-resolv.conf"
    hsh-run --number="$number" --rooter "$workdir" -- install -m 0644 -T /.in/lab05-resolv.conf /etc/resolv.conf
fi
exec hsh-shell --number="$number" ${rooter[@]+"${rooter[@]}"} --mountpoints=/proc "$workdir"

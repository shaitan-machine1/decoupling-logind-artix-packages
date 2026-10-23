#!/bin/bash
set -euo pipefail

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manager=$repo/user-service-manager
work=$(mktemp -d /tmp/s6-user-service-manager.XXXXXX)
manager_pid=
cleanup() {
    status=$?
    trap - EXIT
    if [ -n "$manager_pid" ] && kill -0 "$manager_pid" 2>/dev/null; then
        kill -TERM "$manager_pid" 2>/dev/null || true
        wait "$manager_pid" 2>/dev/null || true
    fi
    rm -rf "$work"
    exit "$status"
}
trap cleanup EXIT

mkdir -p "$work/bin" "$work/config/s6/sv/default/contents.d" \
    "$work/config/s6/sv/demo" "$work/runtime"
printf 'bundle\n' >"$work/config/s6/sv/default/type"
: >"$work/config/s6/sv/default/contents.d/demo"
printf 'longrun\n' >"$work/config/s6/sv/demo/type"
printf '#!/bin/sh\nexec sleep 3600\n' >"$work/config/s6/sv/demo/run"
chmod 755 "$work/config/s6/sv/demo/run"

cat >"$work/bin/s6-rc-compile" <<'EOF'
#!/bin/sh
set -eu
[ "$#" -eq 2 ]
[ -f "$2/default/type" ]
[ -f "$2/demo/run" ]
mkdir -p "$1"
printf '%s\n' "$2" >"$1/source"
EOF
cat >"$work/bin/s6-svscan" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$$" >"$1/.mock-svscan-pid"
trap 'exit 0' TERM INT HUP
while :; do sleep 1; done
EOF
cat >"$work/bin/s6-svscanctl" <<'EOF'
#!/bin/sh
set -eu
mode=$1
scandir=$2
[ -f "$scandir/.mock-svscan-pid" ] || exit 1
pid=$(cat "$scandir/.mock-svscan-pid")
case $mode in
    -a) kill -0 "$pid" ;;
    -t) kill -TERM "$pid" ;;
    *) exit 64 ;;
esac
EOF
cat >"$work/bin/s6-rc-init" <<'EOF'
#!/bin/sh
set -eu
live=
while [ "$#" -gt 0 ]; do
    case $1 in
        -c) shift 2 ;;
        -l) live=$2; shift 2 ;;
        *) scandir=$1; shift ;;
    esac
done
[ -n "$live" ] && [ -n "${scandir:-}" ]
mkdir -p "$live"
EOF
cat >"$work/bin/s6-rc" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >>"$MOCK_S6_RC_LOG"
EOF
chmod 755 "$work/bin"/*

if "$manager" --ready-fd nope >/dev/null 2>&1; then
    echo 'manager accepted malformed readiness fd' >&2
    exit 1
else
    [ "$?" -eq 64 ]
fi

mkfifo "$work/ready"
PATH="$work/bin:/usr/bin:/bin" \
HOME="$work/home" \
XDG_CONFIG_HOME="$work/config" \
XDG_RUNTIME_DIR="$work/runtime" \
MOCK_S6_RC_LOG="$work/s6-rc.log" \
    "$manager" --ready-fd 3 3>"$work/ready" >"$work/manager.log" 2>&1 &
manager_pid=$!
IFS= read -r ready <"$work/ready"
[ -z "$ready" ]
kill -0 "$manager_pid"
[ -f "$work/runtime/s6/source/demo/run" ]
[ -f "$work/runtime/s6/compiled/source" ]
grep -Fx -- "-l $work/runtime/s6/live -u change default" "$work/s6-rc.log"
kill -TERM "$manager_pid"
wait "$manager_pid"
manager_pid=
grep -Fx -- "-l $work/runtime/s6/live -da change" "$work/s6-rc.log"

rm -rf "$work/config/s6/sv/demo"
ln -s /tmp "$work/config/s6/sv/escaped"
if PATH="$work/bin:/usr/bin:/bin" \
   HOME="$work/home" \
   XDG_CONFIG_HOME="$work/config" \
   XDG_RUNTIME_DIR="$work/runtime" \
   MOCK_S6_RC_LOG="$work/s6-rc.log" \
   "$manager" --ready-fd 3 3>/dev/null >/dev/null 2>&1; then
    echo 'manager accepted a symlinked service source' >&2
    exit 1
fi

echo 's6 user service manager tests passed'

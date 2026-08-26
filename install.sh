#!/usr/bin/env bash
# leer installer — lean config-recovery tool
# Usage:   sudo ./install.sh
#          sudo ./install.sh --remove     (asks about snapshots)
set -Eeuo pipefail

DESTDIR="${DESTDIR:-}"
BINDIR="/usr/local/bin"
ACTION="install"
[[ ${1:-} == "--remove" ]] && ACTION="remove"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

if [[ -n $DESTDIR ]]; then
    mkdir -p -- "$DESTDIR"
elif [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    :
else
    echo "run with sudo (or set DESTDIR for sandbox install)" >&2
    exit 1
fi

cd "$(dirname "$0")"

if [[ $ACTION == remove ]]; then
    say "removing leer"
    rm -f -- "${DESTDIR}${BINDIR}/leer" \
             "${DESTDIR}/etc/leer.conf" \
             "${DESTDIR}/usr/share/man/man8/leer.8" \
             "${DESTDIR}/usr/share/man/man8/leer.8.gz"
    if [[ -z $DESTDIR && -d ${DESTDIR}/var/lib/leer/snapshots ]] && [[ -n $(ls -A "${DESTDIR}/var/lib/leer/snapshots" 2>/dev/null) ]]; then
        read -r -p "Delete snapshot store (${DESTDIR}/var/lib/leer)? ALL restore data will be lost [y/N] " ans
        case $ans in y|Y|yes|Yes) rm -rf -- "${DESTDIR}/var/lib/leer"; say "store removed.";; *) say "store kept at /var/lib/leer";; esac
    else
        rm -rf -- "${DESTDIR}/var/lib/leer" 2>/dev/null || true
    fi
    say "done. leer no longer touches pacman operations or your bootloader."
    exit 0
fi

say "installing leer -> ${DESTDIR}${BINDIR}/leer"
install -Dm755 bin/leer "${DESTDIR}${BINDIR}/leer"

if [[ -e ${DESTDIR}/etc/leer.conf ]]; then
    say "/etc/leer.conf already exists — leaving it untouched"
    if ! grep -q '^TARGET_HOME=' "${DESTDIR}/etc/leer.conf" && [[ -n ${SUDO_USER:-} ]]; then
        th=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [[ -n $th ]]; then
            say "adding TARGET_HOME=$th (so root-run snapshots capture $SUDO_USER's home)"
            printf '\nTARGET_HOME="%s"\n' "$th" >> "${DESTDIR}/etc/leer.conf"
        fi
    fi
else
    say "writing /etc/leer.conf"
    install -Dm644 conf/leer.conf "${DESTDIR}/etc/leer.conf"
    if [[ -n ${SUDO_USER:-} ]]; then
        th=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        [[ -n $th ]] && printf '\nTARGET_HOME="%s"\n' "$th" >> "${DESTDIR}/etc/leer.conf"
    fi
fi

say "installing man page"
if command -v gzip >/dev/null; then
    install -d "${DESTDIR}/usr/share/man/man8"
    gzip -c doc/leer.8 > "${DESTDIR}/usr/share/man/man8/leer.8.gz"
else
    install -Dm644 doc/leer.8 "${DESTDIR}/usr/share/man/man8/leer.8"
fi

say "creating snapshot store"
install -d --mode=755 "${DESTDIR}/var/lib/leer" "${DESTDIR}/var/lib/leer/snapshots"

command -v zenity >/dev/null \
    && say "zenity found — GUI picker enabled" \
    || say "zenity NOT found — picker falls back to numbered TTY menu"

say "done. leer never runs automatically; you invoke everything."
cat <<EOF
  sudo leer snap               # first snapshot
  leer list                    # view history
  sudo leer restore <id> --pick   # choose exactly what to restore
  sudo leer schedule set daily   # optional auto-snapshots (hourly..yearly/--at)
  leer gui                       # graphical hub for everything above
  leer doctor                    # sanity checks
EOF

#!/usr/bin/env bash
# uninstall.sh — remove leer from this machine (single confirmation screen)
#
# Usage:
#   sudo ./uninstall.sh                  guided: shows plan, one y/N confirm
#   sudo ./uninstall.sh --yes            no prompt (same removals)
#   sudo ./uninstall.sh --keep-snapshots exclude snapshot store from removal
#   sudo ./uninstall.sh --keep-config    exclude /etc/leer.conf from removal
#   sudo ./uninstall.sh --purge          explicit full wipe (same as default + wins over --keep-*)
#   sudo ./uninstall.sh --dry-run        print the plan, change nothing
set -u

VERSION="0.7.0"

YES=no PURGE=no KEEP_SNAPSHOTS=no KEEP_CONFIG=no DRY_RUN=no
BIN="${LEER_UNINSTALL_BIN:-/usr/local/bin/leer}"
CONF="${LEER_UNINSTALL_CONF:-/etc/leer.conf}"
MAN_GZ="${LEER_UNINSTALL_MAN:-/usr/share/man/man8/leer.8.gz}"
MAN_RAW="${LEER_UNINSTALL_MAN:-/usr/share/man/man8/leer.8}"
STORE="${LEER_UNINSTALL_STORE:-/var/lib/leer}"
UNIT_DIR="${LEER_UNIT_DIR:-/etc/systemd/system}"
SVC="$UNIT_DIR/leer-snapshot.service"
TMR="$UNIT_DIR/leer-snapshot.timer"

for arg in "$@"; do
    case $arg in
        --remove|-r)       YES=yes ;;   # install.sh --remove compatibility: keep data, no prompt
        --purge)           PURGE=yes ;;
        --keep-snapshots)  KEEP_SNAPSHOTS=yes ;;
        --keep-config)     KEEP_CONFIG=yes ;;
        --dry-run)         DRY_RUN=yes ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

die() { echo "uninstall: $*" >&2; exit 1; }
[[ $DRY_RUN == yes || ${EUID:-$(id -u)} -eq 0 ]] || die "run with sudo"

# --purge overrides keep-flags (warn on conflict)
if [[ $PURGE == yes ]]; then
    [[ $KEEP_SNAPSHOTS == yes ]] && echo "note: --keep-snapshots ignored (--purge given)" >&2
    [[ $KEEP_CONFIG    == yes ]] && echo "note: --keep-config ignored (--purge given)" >&2
    KEEP_SNAPSHOTS=no; KEEP_CONFIG=no
fi

DEL_BIN=yes
DEL_MAN=yes
DEL_CONF=yes;   [[ $KEEP_CONFIG    == yes ]] && DEL_CONF=no
DEL_STORE=yes;  [[ $KEEP_SNAPSHOTS == yes ]] && DEL_STORE=no
[[ $PURGE == no && $KEEP_SNAPSHOTS == no && ! -d $STORE/snapshots ]] && DEL_STORE=no

# ---- live state ----
SCHED_DESC="not installed"
[[ -f $TMR ]] && SCHED_DESC="$(sed -n 's/^OnCalendar=//p' "$TMR" 2>/dev/null || echo installed)"
SNAP_N=0; SNAP_SIZE="—"
if [[ -d $STORE/snapshots ]]; then
    SNAP_N=$(find "$STORE/snapshots" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/MANIFEST' \; -print 2>/dev/null | wc -l)
    SNAP_SIZE=$(du -sh "$STORE" 2>/dev/null | cut -f1)
fi

# ---- plan ----
echo
echo "leer uninstaller v$VERSION"
echo "========================="
DRY=""; [[ $DRY_RUN == yes ]] && DRY="(dry-run — nothing will be changed)"
echo "$DRY"
SCHED_LINE="not installed → nothing to do"
[[ -f $TMR ]] && SCHED_LINE="→ will be disabled + removed"
printf '  %-52s %s\n' "schedule timer ($SCHED_DESC)" "$SCHED_LINE"
[[ -e $BIN ]] || printf '  %-52s %s\n' "$BIN" "(not installed — skipped)" && DEL_BIN=no

printf '  %-52s %s\n' "man page"                  "→ removed"
printf '  %-52s %s\n' "$CONF"                     "$([[ $DEL_CONF == yes ]] && echo → removed || echo → KEPT)"
printf '  %-52s %s\n' "snapshots ($SNAP_N, $SNAP_SIZE)" \
    "$([[ $DEL_STORE == yes ]] && echo '→ DELETED' || echo '→ KEPT')"
echo

if [[ $DRY_RUN != yes ]]; then
    read -r -p "Continue? [y/N] " ans
    case $ans in y|Y|yes|Yes) ;; *) echo "aborted — nothing changed."; exit 0;; esac
fi

removed=0 kept=0
step() { # $1=desc  $2=enabled(yes/no)  $3=command...
    local desc=$1 en=$2; shift 2
    if [[ $en != yes ]]; then
        printf '  KEPT    %s\n' "$desc"; kept=$((kept + 1)); return 0
    fi
    if [[ $DRY_RUN == yes ]]; then
        printf '  WOULD   %s\n' "$desc"
    else
        "$@" >/dev/null 2>&1 && printf '  REMOVED %s\n' "$desc" || printf '  FAILED  %s\n' "$desc"
    fi
    removed=$((removed + 1))
    return 0
}

echo "-- applying --"
step "schedule units" "$( [[ -f $TMR || -f $SVC ]] && echo yes || echo no )" bash -c '
    systemctl disable --now leer-snapshot.timer >/dev/null 2>&1 || true
    rm -f -- '"$(printf '%q' "$SVC")"' '"$(printf '%q' "$TMR")"'
    systemctl daemon-reload >/dev/null 2>&1 || true'

step "binary"      "$([[ -e $BIN ]] && echo yes || echo no)"   rm -f -- "$BIN"
step "man page"    "$([[ -e $MAN_GZ || -e $MAN_RAW ]] && echo yes || echo no)" rm -f -- "$MAN_GZ" "$MAN_RAW"
step "config file" "$DEL_CONF"  rm -f -- "$CONF"
step "snapshot store ($SNAP_N snapshots, $SNAP_SIZE)" "$DEL_STORE" rm -rf -- "$STORE"

echo
if [[ $DRY_RUN == yes ]]; then
    echo "dry-run complete — nothing was modified."
else
    echo "done. removed items: see above."
    [[ $DEL_STORE == no ]] && echo "your snapshots are safe at: $STORE"
    command -v leer >/dev/null 2>&1 && echo "warning: a 'leer' binary is still on PATH ($(command -v leer))" || true
fi
exit 0

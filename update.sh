#!/usr/bin/env bash
# update.sh — upgrade the installed leer from this source folder
#
# Usage:
#   sudo ./update.sh           apply update (asks y/N)
#   ./update.sh --check        only compare versions, change nothing
#   sudo ./update.sh --yes     apply without prompt
set -euo pipefail

YES=no CHECK=no
for arg in "$@"; do
    case $arg in
        --yes|-y) YES=yes ;;
        --check)  CHECK=yes ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

SRC="$(cd "$(dirname "$0")" && pwd)"
installed_ver=$({ command -v leer >/dev/null 2>&1 && leer --version || true; } | awk 'NR==1{print $2}')
repo_ver=$("$SRC/bin/leer" --version | awk '{print $2}')

echo "installed : ${installed_ver:-none}"
echo "source    : $repo_ver"

if [[ $CHECK == yes ]]; then
    [[ $installed_ver == "$repo_ver" ]] && echo "up to date." \
        || echo "update available: ${installed_ver:-none} -> $repo_ver"
    exit 0
fi

[[ $installed_ver == "$repo_ver" ]] && { echo "already up to date."; exit 0; }

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "needs root — re-run as:  sudo ./update.sh" >&2
    exit 1
fi

if [[ $YES != yes ]]; then
    read -r -p "Apply update now? [y/N] " ans
    case $ans in y|Y|yes|Yes) ;; *) echo "aborted."; exit 0;; esac
fi

"$SRC/install.sh"

new_ver=$(leer --version | awk '{print $2}')
echo
echo "updated: ${installed_ver:-none} -> $new_ver"

echo "next: sudo leer doctor"

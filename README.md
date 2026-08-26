# leer

**User-configuration snapshot & selective-restore tool for Arch-family systems.**

leer takes versioned snapshots of your desktop + shell configuration, and lets you
roll back entirely or file-by-file through an interactive terminal menu.
It is deliberately *not* a system-recovery tool: kernels, packages and boot
states are out of scope (that's what btrfs/snapper or Timeshift are for).

```
broken theme?  → sudo leer restore <id> --pick   → untick everything except .themes
bad shell edit?→ same command, tick only .zshrc
DE won't start?→ Ctrl+Alt+F3 → sudo leer restore <id>   (TTY picker works headless)
```

---

## Install / Update / Uninstall

```bash
sudo ./install.sh        # install (+ first-run hints)
./update.sh              # compare installed vs this folder; --check / --yes
sudo ./uninstall.sh      # guided removal (asks before deleting data)
```

Requirements: **bash · rsync · pacman · systemd** (Arch family).
Optional: none — everything runs in the terminal.

## Commands

| Command | What it does |
|---|---|
| `sudo leer snap [--tag MSG]` | create a snapshot |
| `leer list` | history table |
| `leer diff <id> [<id2>\|live]` | what changed between states |
| `sudo leer restore <id> [--pick]` | roll back (see picker below) |
| `sudo leer drop <id> [--yes]` | delete one snapshot |
| `sudo leer prune [<n>]` | keep newest n |
| `sudo leer schedule set daily\|--at '<expr>'\|off` | opt-in auto-snapshots |
| `leer doctor` | health check |

## The restore picker (`--pick`)

Lists every captured item at mixed granularity `.config/sway/`, `.zshrc`,
`.themes/`, `/etc` as one unit. Items that differ from your current system are
**pre-checked** with change counts (`3m/1d`). Untick anything you want left alone.

Runs as a numbered terminal menu identical on a desktop, over SSH, or from
a TTY when the desktop is dead (Ctrl+Alt+F3). Deletions only ever apply inside paths you
ticked caches, histories and unrelated files can't be touched by accident.

## Scheduling

Opt-in systemd timer: `hourly · daily · weekly · monthly · yearly` or any
`OnCalendar` expression. Missed runs execute at next boot; runs are tagged
`auto`; retention still enforced. Off by default.

## Interactive restore (`--pick`)

`sudo leer restore <id> --pick` shows a numbered terminal menu of every
captured item `.config/sway/`, `.zshrc`, `.themes/`, `/etc` as one unit.
Items that differ from your current system are **pre-checked** with change
counts (`3m/1d`). Type the numbers to restore (or `a` for all), confirm,
and only those paths are written. Works identically on a desktop and over
TTY/SSH.

## Configuration — `/etc/leer.conf`

```bash
LEER_KEEP=10          # snapshots retained (auto-pruned)
SNAP_DIR="..."        # storage override (default /var/lib/leer/snapshots)
HOME_PATHS=(auto)     # 'auto' or explicit list (.config .zshrc …)
THEME_DIRS=1          # include ~/.themes ~/.icons ~/.fonts
ETC_ENABLE=1          # capture /etc
TARGET_HOME=""        # pin user home when running as root (installer sets it)
GLOBAL_EXCLUDES=(…)   # basename patterns skipped everywhere
```

## Recovery playbook

- **Configs broken, machine boots** → TTY (`Ctrl+Alt+F3`) or terminal:
  `sudo leer list` → `sudo leer restore <id> --pick`
- **Desktop dead but boots to login** → TTY login works independently of the DE;
  same command
- **Package suspects?** every restore prints which packages differ from the
  snapshot's recorded package list

## Safety properties

- Never runs automatically (except a schedule you configured)
- Restores show a dry-run plan and require explicit confirmation
- Deletions scoped per selected path; excludes re-applied during restore
- `drop` refuses the last snapshot; `prune` refuses below minimum
- Passwords are used transiently for one sudo action — never stored

## Honest limitations

- Snapshots live on the same disk a total disk failure loses them too
- Overlay restore doesn't remove files created *after* a snapshot
- Arch-family only (pacman); multi-user systems: one home per invocation via
  `TARGET_HOME`

## Layout

```
bin/leer            main tool
conf/leer.conf      defaults
doc/leer.8          man page
install.sh          installer (--remove delegates)
update.sh           self-update from this folder
uninstall.sh        guided removal
hooks/…             (none in lean builds)
```

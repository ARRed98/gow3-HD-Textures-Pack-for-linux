#!/usr/bin/env bash
# gears3-hd.sh — install / rollback Gears of War 3 HD Texture Pack 1.3 on Linux
# Replaces the three Windows .bat installers, which misbehave under Wine's cmd.exe.

set -euo pipefail

# ---- Defaults (edit if your paths move) ------------------------------------

DEFAULT_GEARGAME_CANDIDATES=(
    "/path/to/Gears 3 Jacinto v1.1.1/GearGame"
    "$PWD/../GearGame"
    "$PWD/GearGame"
)

DEFAULT_PACK_ROOTS=(
    "$PWD"
    "$HOME/Downloads/Gears 3 Jacinto v1.1.1"
    "/path/to/Decompiled/Gears 3 Jacinto v1.1.1"
)

# ---- Utilities -------------------------------------------------------------

die()  { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARNING: $*" >&2; }

human_size() {
    if [ -e "$1" ]; then du -sh "$1" 2>/dev/null | cut -f1; else echo "?"; fi
}

find_geargame() {
    if [ -n "${GEARGAME:-}" ] && [ -f "$GEARGAME/Config/GearEngine.ini" ]; then
        echo "$GEARGAME"; return 0
    fi
    local d
    for d in "${DEFAULT_GEARGAME_CANDIDATES[@]}"; do
        if [ -f "$d/Config/GearEngine.ini" ]; then echo "$d"; return 0; fi
    done
    return 1
}

find_phase_dir() {
    local phase="$1" name="phase${phase}"
    local candidates=()
    [ -n "${PACK_ROOT:-}" ] && candidates+=("$PACK_ROOT/$name")
    local root
    for root in "${DEFAULT_PACK_ROOTS[@]}"; do candidates+=("$root/$name"); done
    local d
    for d in "${candidates[@]}"; do
        if [ -d "$d/Content" ]; then echo "$d"; return 0; fi
    done
    return 1
}

# ---- Commands --------------------------------------------------------------

backup_phase() {
    local pack_dir="$1" game_content="$2" backup_dir="$3"
    local pack_content="$pack_dir/Content"
    mkdir -p "$backup_dir"

    local count=0 rel src dst f
    while IFS= read -r -d '' f; do
        rel="${f#"$pack_content"/}"
        src="$game_content/$rel"
        dst="$backup_dir/$rel"
        if [ -f "$src" ] && [ ! -f "$dst" ]; then
            mkdir -p "$(dirname "$dst")"
            cp -f -- "$src" "$dst"
            count=$((count + 1))
        fi
    done < <(find "$pack_content" -type f -name '*.upk' -print0)

    printf '  Backed up %d new file(s).\n' "$count"
    printf '  Backup now: %s files, %s\n' \
        "$(find "$backup_dir" -type f | wc -l)" "$(human_size "$backup_dir")"
}

install_phase() {
    local phase="$1"
    local pack_dir
    pack_dir=$(find_phase_dir "$phase") \
        || die "Could not find phase${phase}/Content. Use -p ROOT or fix DEFAULT_PACK_ROOTS."

    local game_content="$GEARGAME/Content"
    local backup_dir="$GEARGAME/Content_Backup_DryreL_HD"
    local marker="$game_content/HD_TexturePack_Phase${phase}.version"

    echo
    echo "==============================================================================="
    echo " PHASE ${phase}"
    echo "==============================================================================="
    echo " Pack:   $pack_dir  ($(human_size "$pack_dir/Content"))"
    echo " Game:   $GEARGAME"
    echo " NOTE:   Make sure Gears of War 3 is CLOSED before continuing."

    if [ -f "$marker" ] && [ "${FORCE:-0}" != "1" ]; then
        echo " Status: already installed (v$(cat "$marker")).  Use -f to force reinstall."
        return 0
    fi

    echo
    echo "[1/3] Backing up originals..."
    backup_phase "$pack_dir" "$game_content" "$backup_dir"

    echo
    echo "[2/3] Copying HD packages..."
    cp -a -- "$pack_dir/Content/." "$game_content/"
    rm -f "$game_content/HD_TexturePack.version"
    printf '1.3\n' > "$marker"
    echo "  Done."

    echo
    echo "[3/3] Applying texture size caps..."
    local caps="$pack_dir/HD_TexturePack_Caps.ps1"
    if [ ! -f "$caps" ]; then
        echo "  (no caps script in this phase)"
    elif ! command -v pwsh >/dev/null 2>&1; then
        warn "pwsh not found — install it ('sudo pacman -S powershell') to apply caps."
    else
        pwsh -NoProfile -ExecutionPolicy Bypass -File "$caps" -GearGame "$GEARGAME" \
            || warn "caps script returned non-zero; check GearEngine.ini."
    fi
}

cmd_status() {
    [ -d "$GEARGAME" ] || die "GearGame path does not exist: $GEARGAME"

    echo "GearGame: $GEARGAME"
    echo
    echo "Installed phases:"
    local p f
    for p in 1 2 3; do
        f="$GEARGAME/Content/HD_TexturePack_Phase${p}.version"
        if [ -f "$f" ]; then
            printf '  Phase %s:  v%s\n' "$p" "$(cat "$f")"
        else
            printf '  Phase %s:  not installed\n' "$p"
        fi
    done

    echo
    local backup="$GEARGAME/Content_Backup_DryreL_HD"
    if [ -d "$backup" ]; then
        printf 'Backup:  %s files, %s  (%s)\n' \
            "$(find "$backup" -type f | wc -l)" \
            "$(human_size "$backup")" \
            "$backup"
    else
        echo "Backup:  none"
    fi
}

cmd_install() {
    local target="${1:-}"
    [ -w "$GEARGAME/Content" ] || die "No write access to $GEARGAME/Content"

    case "$target" in
        1|2|3) install_phase "$target" ;;
        all)
            local p
            for p in 1 2 3; do
                if find_phase_dir "$p" >/dev/null; then
                    install_phase "$p"
                else
                    echo "Skipping phase $p (folder not found)"
                fi
            done
            ;;
        *) die "install requires one of: 1, 2, 3, all" ;;
    esac

    echo
    cmd_status
}

cmd_rollback() {
    local backup="$GEARGAME/Content_Backup_DryreL_HD"
    [ -d "$backup" ] || die "No backup found at $backup"
    [ -w "$GEARGAME/Content" ] || die "No write access to $GEARGAME/Content"

    printf 'Restoring %s files from %s ...\n' \
        "$(find "$backup" -type f | wc -l)" "$backup"
    cp -a -- "$backup/." "$GEARGAME/Content/"

    rm -f "$GEARGAME/Content/HD_TexturePack_Phase1.version" \
          "$GEARGAME/Content/HD_TexturePack_Phase2.version" \
          "$GEARGAME/Content/HD_TexturePack_Phase3.version" \
          "$GEARGAME/Content/HD_TexturePack.version"

    echo "Rollback complete."
}

usage() {
    cat <<'EOF'
Usage: gears3-hd.sh [options] <command> [arg]

Commands:
  status              Show installed phases + backup size
  install <phase>     Install phase: 1 | 2 | 3 | all
  rollback            Restore originals from Content_Backup_DryreL_HD

Options:
  -g PATH    GearGame folder (contains Config/GearEngine.ini)
  -p ROOT    Folder containing phase1/, phase2/, phase3/
  -f         Force reinstall even if phase marker present
  -h         Help

Env:  GEARGAME, PACK_ROOT, FORCE=1

Examples:
  gears3-hd.sh status
  gears3-hd.sh install all
  gears3-hd.sh install 2 -g "/path/to/NVME/Decompiled/Gears 3 Jacinto v1.1.1/GearGame"
  gears3-hd.sh rollback
EOF
}

# ---- Argument parsing ------------------------------------------------------

GEARGAME="${GEARGAME:-}"
PACK_ROOT="${PACK_ROOT:-}"
FORCE="${FORCE:-0}"

positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        -g)         GEARGAME="$2"; shift 2 ;;
        -p)         PACK_ROOT="$2"; shift 2 ;;
        -f|--force) FORCE=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        --)         shift; positional+=("$@"); break ;;
        -*)         die "Unknown option: $1 (use -h for help)" ;;
        *)          positional+=("$1"); shift ;;
    esac
done
set -- "${positional[@]}"

[ $# -ge 1 ] || { usage; exit 2; }
COMMAND="$1"; shift

GEARGAME=$(find_geargame) \
    || die "GearGame not found. Pass -g PATH (folder containing Config/GearEngine.ini)."
export GEARGAME PACK_ROOT FORCE

case "$COMMAND" in
    status)   cmd_status ;;
    install)  cmd_install "${1:-}" ;;
    rollback) cmd_rollback ;;
    *)        usage; exit 2 ;;
esac

# Gears of War 3 HD Texture Pack — Linux Installer

A single bash script that replaces the three Windows `.bat` installers for the [Gears of War 3 HD Texture Pack 1.3](https://www.nexusmods.com/gearsofwar3/mods/28).

Runs fully native on Linux — `cp`/`find` for backup and install, `pwsh` for the `.ini` texture-cap edits. **No Wine required.**

> **AI Disclosure:** This installer script was developed with the assistance of an AI language model.

## What it does

For each phase, in order:

1. **Backs up** every original `.upk` the phase replaces into `GearGame/Content_Backup_DryreL_HD/` (per-file — never overwrites an existing backup).
2. **Copies** the phase's `Content/` over `GearGame/Content/`.
3. **Writes** `HD_TexturePack_PhaseN.version` (`1.3`).
4. **Raises texture caps** in `GearGame/Config/GearEngine.ini` via `HD_TexturePack_Caps.ps1`.

Also supports `status` and `rollback`.

## Requirements

```bash
sudo pacman -S powershell unzip
```

Tested on CachyOS; should work on any Arch-based distro. Debian/Ubuntu equivalents:

```bash
sudo apt install powershell unzip
```

## Setup

### 1. Prepare the phase folders

Put the four ZIPs beside the script (or point `ZIPS=` at them), then extract.

> **Phase 2 ships as two parts — extract both into the same `phase2/` folder** so they merge.

```bash
mkdir -p ~/gow3 && cd ~/gow3
ZIPS="$HOME/Downloads"

P1="$ZIPS/GoW3 HD Texture Pack Phase1 V1.3 28 1.3 2026-10-11T07-38Z AgpTQEAwX.zip"
P2A="$ZIPS/GoW3 HD Texture Pack Phase2 V1.3 (PART1) 28 1.3 2026-10-11T08-47Z ps9nLzpY6.zip"
P2B="$ZIPS/GoW3 HD Texture Pack Phase2 V1.3 (PART2) 28 1.3 2026-10-11T09-32Z 9khVfl9N8.zip"
P3="$ZIPS/GoW3 HD Texture Pack Phase3 V1.3 28 1.3 2026-10-11T09-37Z vDywIWv7E.zip"

unzip -q "$P1"  -d phase1
unzip -q "$P2A" -d phase2
unzip -q "$P2B" -d phase2      # PART2 merges into the same folder
unzip -q "$P3"  -d phase3
```

Some ZIPs wrap everything in a top-level folder. Flatten it (harmless if already flat):

```bash
for p in phase1 phase2 phase3; do
    e=$(find "$p" -mindepth 1 -maxdepth 1)
    if [ "$(echo "$e" | wc -l)" = "1" ] && [ -d "$e" ]; then
        mv "$e"/* "$p/" 2>/dev/null || true
        rmdir "$e" 2>/dev/null || true
    fi
done
```

Verify:

```bash
for p in phase1 phase2 phase3; do
    printf '%-7s  %-6s  upk=%-4s  caps=%s\n' "$p" \
        "$(du -sh "$p" | cut -f1)" \
        "$(find "$p/Content" -type f -name '*.upk' 2>/dev/null | wc -l)" \
        "$([ -f "$p/HD_TexturePack_Caps.ps1" ] && echo yes || echo NO)"
done
```

Expected output:

```text
phase1   3.1G    upk=379   caps=yes
phase2   5.4G    upk=699   caps=yes
phase3   200M    upk=19    caps=yes
```

If any line shows `upk=0` or `caps=NO`, the flatten step didn't collapse a wrapper folder — inspect with `find "$p" -maxdepth 2` and move the contents up manually.

### 2. Get the script

Copy [`gears3-hd.sh`](gears3-hd.sh) to `~/gow3/` and make it executable:

```bash
chmod +x ~/gow3/gears3-hd.sh
```

### 3. Install

```bash
cd ~/gow3

./gears3-hd.sh status           # nothing installed yet
./gears3-hd.sh install all      # phase 1 → 2 → 3
```

## Usage

```text
gears3-hd.sh [options] <command> [arg]
```

### Commands

| Command | Description |
|---|---|
| `status` | Show which phases are installed and backup size |
| `install 1` | Install Phase 1 only (characters, weapons, vehicles) |
| `install 2` | Install Phase 2 only (environment, levels, effects) |
| `install 3` | Install Phase 3 only (interface, HUD) |
| `install all` | Install all three in order |
| `rollback` | Restore all originals from `Content_Backup_DryreL_HD/` |

### Options

| Option | Description |
|---|---|
| `-g PATH` | GearGame folder (contains `Config/GearEngine.ini`) |
| `-p ROOT` | Folder containing `phase1/`, `phase2/`, `phase3/` |
| `-f` | Force reinstall even if the phase marker exists |
| `-h` | Help |

### Environment variables

- `GEARGAME` — overrides auto-detected GearGame path
- `PACK_ROOT` — overrides auto-detected phase-folder root
- `FORCE=1` — same as `-f`

### Common invocations

```bash
# install everything with auto-detected paths
./gears3-hd.sh install all

# reinstall Phase 2 after a game update
./gears3-hd.sh install 2 -f

# override paths explicitly
./gears3-hd.sh -g "/path/to/Gears 3 Jacinto v1.1.1/GearGame" \
               -p "$HOME/gow3" \
               install all

# undo everything
./gears3-hd.sh rollback
```

## Auto-detection

The script tries the following locations, in order:

- **GearGame** — `/path/to/Gears 3 Jacinto v1.1.1/GearGame`, then `../GearGame` and `./GearGame` relative to `$PWD`.
- **Phase folders** — `$PWD/phaseN`, then `~/gow3/phaseN`, then `~/Downloads/Gears 3 Jacinto v1.1.1/phaseN`.

Pass `-g PATH` and `-p ROOT` if your layout differs.

## Notes

- **Close the game** before running `install` or `rollback`. The copy step touches hundreds of `.upk` files; a running game can leave partially written packages.
- **Backup accumulates** across phases in `GearGame/Content_Backup_DryreL_HD/` (~8.3 GB after all three). First writer wins — a later phase never overwrites an original that an earlier phase already captured.
- **First launch is slower.** Every `.upk` change invalidates the shader cache, so the game recompiles on first boot. 2–3× normal load time is normal.
- **Gears3 Multipatch Tool** — if installed, rerun *its* installer after this script. It re-applies UI patches to files Phase 3 replaced and re-applies VRAM caps. The script prints a reminder when it detects the tool.
- **`.ini` caps survive rollback.** The backup covers `Content/` only, not `Config/GearEngine.ini`. Edit that file manually if you want vanilla caps back after a rollback — or leave it, since the raised caps are harmless on vanilla textures.
- **The `.bat` files** inside each `phaseN/` are kept for reference only; this script never invokes them.

## Uninstall

```bash
./gears3-hd.sh rollback
```

Restores all 1,097 originals, deletes the three `HD_TexturePack_Phase*.version` markers, and leaves `Content_Backup_DryreL_HD/` in place (safe to delete manually afterwards).

## Credits

- **DryreL** — original HD Texture Pack ([NexusMods mod 28](https://www.nexusmods.com/gearsofwar3/mods/28))
- Windows `.bat` installers by the original author — this repo is a Linux-native rewrite

## License

Script: MIT. Textures: see the original NexusMods page for the author's terms.

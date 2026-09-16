# Versioned Firmware Files and Version Folders on the OTA Host — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every image built from `~/repo/tasmota` carries its version in the filename, lives in a per-version folder on http://192.168.22.11/tasmota/, and the version is also visible on the device (`Status 2`). Devices keep their current `OtaUrl` unchanged; a stable name per profile is a symlink that `--promote` moves, which also gives canary upgrades and one-command rollback.

**Architecture:** `muh/version.sh` derives one version from `git describe --match 'muh-v*'` and writes a git-ignored header `tasmota/muh_build_id.h`; the override turns that into Tasmota's `TASMOTA_SHA_SHORT`, so a device reports `15.6.0(15.6.0-muh1-<image>)`. `muh/build.sh` collects into `build/<version>/<profile>_<token>.<ext>`, `--publish` rsyncs that folder to `<OTA dir>/<version>/` (untagged/dirty builds to `dev/<version>/`), `--promote` repoints `<OTA dir>/<profile>.<ext>` symlinks at the folder. Host-side work (checksums, promote, list, prune) lives in `muh/ota-host.sh`, piped over SSH so nothing is installed on the host. ESP8266 profiles get a `tasmota-muh-minimal` companion because 1 MB devices upgrade in two steps. CI names release assets the same way.

**Tech Stack:** bash, rsync/ssh, nginx on 192.168.22.11 (follows symlinks; `disable_symlinks` not set), PlatformIO 6.1.19 in `.venv`, Tasmota fork `muh` at tag `muh-v15.6.0`.

## Global Constraints

- **Filename rule.** Tasmota rewrites the OTA filename for its fallbacks (ESP8266 `-minimal`, ESP32 HTTPS `-safeboot`, `tasmota/tasmota_support/support_tasmota.ino` ~1440 and ~1470): it cuts the file type at the FIRST `.` of the filename and replaces everything after the LAST `-`. Therefore the version part of a filename must contain neither `.` nor `-`:
  - folder: `15.6.0-muh1` (dots and dashes fine, only the filename is parsed)
  - file: `<profile>_<token>.<ext>`, `token` = version with `.` and `-` replaced by `_` → `tasmota32solo1-muh_15_6_0_muh1.bin`
  - profile names contain no `_` (all current ones comply; keep it that way)
- **Devices' `OtaUrl` does not change.** Stable names `<OTA dir>/<profile>.bin`, `.bin.gz`, `.factory.bin` stay, as symlinks.
- **Version string.** From `git describe --tags --match 'muh-v*' --dirty`, prefix `muh-v` stripped. Exact clean tag → channel `release` (`15.6.0-muh1`). Anything else → channel `dev` (`15.6.0-muh1-3-gabc1234[-dirty]`), published under `dev/`, never promoted without `--force`.
- **Tag convention** (README-MUH already says so): `muh-v<upstream>-muh<N>`. The current tag `muh-v15.6.0` is the plain merge; the first release with this plan is `muh-v15.6.0-muh1`.
- Maps stay local (`build/<version>/`) and in CI artifacts; they are not uploaded to the OTA host.
- Nothing is flashed by this plan. Upgrades stay manual, one device at a time.
- `pio-tools/` is not modified.

## Facts verified 2026-09-16

- Minimal rewrite example with today's names: `…/tasmota-muh-plug.bin.gz` → `…/tasmota-muh-minimal.bin.gz` (last dash before `plug`). One `tasmota-muh-minimal` image therefore serves all three ESP8266 profiles, but only if it exists next to the file the device fetches. No such image is built today, so a 1 MB ESP8266 (e.g. Athom Plug V2: `Free` 364 KB, `tasmota-muh-plug.bin` 653 KB) could not upgrade to a MUH profile at all.
- A naive versioned name breaks it: `tasmota-muh-plug-15.6.0.bin.gz` → `tasmota-muh-plug-minimal.6.0.bin.gz`.
- `tasmota/tasmota.ino` includes `include/tasmota_version.h` (defines empty `TASMOTA_SHA_SHORT`) before `my_user_config.h`, which includes `user_config_override.h` last, so the override can redefine it. `STR()` is expanded later (`tasmota.ino:678`). `gcc -E` confirms `STR(MUH_BUILD_ID-)` with `MUH_BUILD_ID` = `15.6.0-muh1` yields `"15.6.0-muh1-"`.
- A `-D` flag with the version would change the global build flags on every commit and rebuild everything including the framework; a generated header only recompiles units that include `user_config_override.h` (measured 2026-09-16: the Tasmota unit plus ~156 library objects, because several libraries include the override transitively). Acceptable: it only happens when the version changes.

---

### Task 1: `muh/version.sh` and its test

**Files:**
- Create: `muh/version.sh` (sourced, not executed)
- Create: `muh/test-version.sh` (executable)
- Modify: `.gitignore` (add `tasmota/muh_build_id.h`)

**Interfaces:**
- Produces: exported `MUH_VERSION`, `MUH_VERTOKEN`, `MUH_CHANNEL`; function `muh_version_from_describe <describe>` printing `version token channel`; file `tasmota/muh_build_id.h` containing exactly `#define MUH_BUILD_ID <MUH_VERSION>`.

- [ ] **Step 1: Write the failing test** `muh/test-version.sh`:
```bash
#!/usr/bin/env bash
# Unit tests for muh/version.sh and for the filename rule Tasmota's OTA
# fallbacks impose (support_tasmota.ino: first '.', last '-').
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }

MUH_VERSION_NO_HEADER=1 . muh/version.sh

check "exact tag"        "$(muh_version_from_describe muh-v15.6.0-muh1)"                  "15.6.0-muh1 15_6_0_muh1 release"
check "plain merge tag"  "$(muh_version_from_describe muh-v15.6.0)"                       "15.6.0 15_6_0 release"
check "commits after"    "$(muh_version_from_describe muh-v15.6.0-muh1-3-gabc1234)"       "15.6.0-muh1-3-gabc1234 15_6_0_muh1_3_gabc1234 dev"
check "dirty tag"        "$(muh_version_from_describe muh-v15.6.0-muh1-dirty)"            "15.6.0-muh1-dirty 15_6_0_muh1_dirty dev"
check "dirty after"      "$(muh_version_from_describe muh-v15.6.0-3-gabc1234-dirty)"      "15.6.0-3-gabc1234-dirty 15_6_0_3_gabc1234_dirty dev"

# Tasmota's fallback filename rewrite, same algorithm as the C code
tasmota_fallback() { python3 - "$1" "$2" <<'PY'
import sys
url, suffix = sys.argv[1], sys.argv[2]
b = url.rfind('/') + 1
name = url[b:]
e = name.find('.')
typ = name[e:] if e >= 0 else ''
d = name.rfind('-')
stem = name[:d] if d >= 0 else (name[:e] if e >= 0 else name)
print(url[:b] + stem + '-' + suffix + typ)
PY
}
B=http://192.168.22.11/tasmota
check "stable 8266 name -> minimal"    "$(tasmota_fallback $B/tasmota-muh-plug.bin.gz minimal)"                          "$B/tasmota-muh-minimal.bin.gz"
check "versioned 8266 name -> minimal" "$(tasmota_fallback $B/15.6.0-muh1/tasmota-muh-plug_15_6_0_muh1.bin.gz minimal)"   "$B/15.6.0-muh1/tasmota-muh-minimal.bin.gz"
check "3em versioned -> minimal"       "$(tasmota_fallback $B/15.6.0-muh1/tasmota-muh-3em_15_6_0_muh1.bin.gz minimal)"    "$B/15.6.0-muh1/tasmota-muh-minimal.bin.gz"
check "why no dots in names"           "$(tasmota_fallback $B/tasmota-muh-plug-15.6.0.bin.gz minimal)"                    "$B/tasmota-muh-plug-minimal.6.0.bin.gz"

# promote parsing used by muh/ota-host.sh
base=tasmota32s3-muh-hdgd_15_6_0_muh1.factory.bin
check "profile from file" "${base%%_*}" "tasmota32s3-muh-hdgd"
check "ext from file"     "${base#*.}"  "factory.bin"

# every profile name must be free of '_'
while read -r p; do [[ $p != *_* ]] || { echo "FAIL profile name contains _: $p"; fail=1; }; done \
  < <(grep -o '^\[env:tasmota[0-9a-z]*-muh[^]]*\]' platformio_muh.ini | sed 's/\[env:\(.*\)\]/\1/')

exit $fail
```
- [ ] **Step 2: Run it, expect failure** (`muh/version.sh` missing): `bash muh/test-version.sh` → `No such file or directory`.
- [ ] **Step 3: Implement** `muh/version.sh`:
```bash
# muh/version.sh — source from the repo root.
# Sets MUH_VERSION (15.6.0-muh1 | 15.6.0-muh1-3-gabc1234[-dirty]),
#      MUH_VERTOKEN (same with . and - replaced by _, safe in OTA filenames),
#      MUH_CHANNEL (release | dev)
# and writes tasmota/muh_build_id.h unless MUH_VERSION_NO_HEADER=1.

muh_version_from_describe() {
  local v=${1#muh-v} channel=release
  if [[ $v =~ -[0-9]+-g[0-9a-f]+(-dirty)?$ || $v == *-dirty ]]; then channel=dev; fi
  printf '%s %s %s\n' "$v" "${v//[.-]/_}" "$channel"
}

_muh_desc=$(git describe --tags --match 'muh-v*' --dirty 2>/dev/null) \
  || _muh_desc="muh-v0.0.0-0-g$(git rev-parse --short HEAD)"
read -r MUH_VERSION MUH_VERTOKEN MUH_CHANNEL < <(muh_version_from_describe "$_muh_desc")
export MUH_VERSION MUH_VERTOKEN MUH_CHANNEL
unset _muh_desc

if [[ ${MUH_VERSION_NO_HEADER:-0} != 1 ]]; then
  _muh_hdr=tasmota/muh_build_id.h
  _muh_want="#define MUH_BUILD_ID $MUH_VERSION"
  # rewrite only on change: the header is included by the main Tasmota unit
  [[ -f $_muh_hdr && $(<"$_muh_hdr") == "$_muh_want" ]] || printf '%s\n' "$_muh_want" > "$_muh_hdr"
  unset _muh_hdr _muh_want
fi
```
- [ ] **Step 4: Run test, expect pass**: `bash muh/test-version.sh` → all `ok`, exit 0. Also `. muh/version.sh; echo "$MUH_VERSION $MUH_CHANNEL"; cat tasmota/muh_build_id.h` in the repo (expect `15.6.0 release` on the tagged commit with a clean tree, otherwise a `dev` string) and `git status --short` does not list the header.
- [ ] **Step 5: Commit**: `build: muh/version.sh derives release/dev version and build id header`.

---

### Task 2: Build id visible on the device

**Files:**
- Modify: `tasmota/user_config_override.h` (append block before the final `#endif`)

- [ ] **Step 1: Add**
```c
// Build id from muh/version.sh (git-ignored header). Status 2 then reports
// e.g. "15.6.0(15.6.0-muh1-tasmota32)"; tools/fleet-check.sh compares it with
// the version promoted on the OTA host.
// Included unconditionally: the ESP8266 toolchain (GCC 4.8.2) has no
// __has_include. muh/build.sh and CI always generate the header.
#include "muh_build_id.h"
#undef  TASMOTA_SHA_SHORT
#define TASMOTA_SHA_SHORT MUH_BUILD_ID-
```
- [ ] **Step 2: Verify** (after `. muh/version.sh` with `muh/build.env` loaded): `.venv/bin/pio run -e tasmota32solo1-muh`, then `strings build_output/firmware/tasmota32solo1-muh.bin | grep -m1 -F "($MUH_VERSION-"` prints the image string. Build a second time without changes and confirm the log does not recompile libraries (`grep -c 'Compiling .pio/build/tasmota32solo1-muh/lib' ` on the second run's output is 0).
- [ ] **Step 3: Commit**: `build: report MUH build id in Status 2 via TASMOTA_SHA_SHORT`.

---

### Task 3: `tasmota-muh-minimal` companion for ESP8266 two-step OTA

**Files:**
- Modify: `platformio_muh.ini` (new env), `platformio_override.ini` (`default_envs`)

- [ ] **Step 1: Env**
```ini
; ESP8266 1 MB devices first flash this image, then the real one. Tasmota
; derives its URL from the device's OtaUrl: <dir>/<name up to last '-'>-minimal<ext>,
; so for tasmota-muh-plug/-bresser/-3em it is tasmota-muh-minimal.bin.gz.
[env:tasmota-muh-minimal]
extends     = env:tasmota-minimal
build_flags = ${env:tasmota-minimal.build_flags} ${muh.build_flags}
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/tasmota-muh-minimal.bin.gz"'
```
- [ ] **Step 2:** add `tasmota-muh-minimal` to `default_envs`.
- [ ] **Step 3: Verify**: `.venv/bin/pio run -e tasmota-muh-minimal`; `stat -c %s build_output/firmware/tasmota-muh-minimal.bin.gz` must be below 360000 (1 MB devices report `Free` 364 KB; the ESP8266 core stores the compressed image and unpacks it on boot, so the `.gz` size is what must fit). Measured 2026-09-16: `.bin` 373104, `.bin.gz` 263416, upstream minimal the same size. If it is larger, find the MUH flag responsible (`user_config_override.h` features are undone for `FIRMWARE_MINIMAL` by `tasmota_configurations.h`; check which survive with `-DFIRMWARE_MINIMAL` in the `gcc -E -dM` method) and exclude it for `FIRMWARE_MINIMAL` in the override.
- [ ] **Step 4: Commit**: `build: tasmota-muh-minimal for ESP8266 two-step upgrades`.

---

### Task 4: Versioned build layout, publish, promote, list, prune

**Files:**
- Create: `muh/ota-host.sh`
- Replace: `muh/build.sh`

**Interfaces:**
- `muh/build.sh [--clean] [--publish] [--promote [--force]] [profile ...|all]`
- `muh/build.sh --promote-only <folder> [--force]` (folder is `15.6.0-muh1` or `dev/…`; rollback)
- `muh/build.sh --list`, `muh/build.sh --prune <keep>`
- `ssh host bash -s -- <cmd> <otadir> [args] < muh/ota-host.sh` with `cmd` in `sums <sub>`, `promote <sub> [--force]`, `list`, `prune <keep>`.

- [ ] **Step 1: `muh/ota-host.sh`**
```bash
#!/usr/bin/env bash
# Runs ON the OTA host, piped over ssh by muh/build.sh:
#   ssh host bash -s -- <cmd> <otadir> [args] < muh/ota-host.sh
# Layout: <otadir>/<version>/..., <otadir>/dev/<version>/...,
#         <otadir>/<profile>.<ext> -> <version>/<profile>_<token>.<ext>
set -euo pipefail
cmd=$1 dir=$2; shift 2
cd "$dir"
shopt -s nullglob

stable_sums() {
  local links=(*.bin *.bin.gz)
  sha256sum -- "${links[@]}" > .SHA256SUMS.tmp && mv -f .SHA256SUMS.tmp SHA256SUMS
  for l in "${links[@]}"; do [[ -L $l ]] && printf '%s -> %s\n' "$l" "$(readlink "$l")"; done > .CURRENT.tmp
  mv -f .CURRENT.tmp CURRENT
}

case $cmd in
  sums)
    sub=$1
    (cd "$sub" && sha256sum -- *_*.bin *_*.bin.gz > SHA256SUMS)
    ;;
  promote)
    sub=$1 force=${2:-}
    [[ -d $sub ]] || { echo "no such version folder: $sub"; exit 1; }
    if [[ $sub == dev/* && $force != --force ]]; then echo "refusing to promote dev build $sub (add --force)"; exit 1; fi
    files=("$sub"/*_*.bin "$sub"/*_*.bin.gz)
    [[ ${#files[@]} -gt 0 ]] || { echo "no images in $sub"; exit 1; }
    for f in "${files[@]}"; do
      base=${f##*/}                 # tasmota32solo1-muh_15_6_0_muh1.factory.bin
      link=${base%%_*}.${base#*.}   # tasmota32solo1-muh.factory.bin
      ln -s "$f" ".$link.tmp"
      mv -Tf ".$link.tmp" "$link"   # atomic, also replaces a former regular file
    done
    rm -f manifest.txt             # pre-versioning leftover
    stable_sums
    echo "promoted $sub:"; grep -F " -> $sub/" CURRENT
    ;;
  list)
    echo "release:"; for d in [0-9]*/; do echo "  ${d%/}"; done | sort -V
    echo "dev:";     for d in dev/*/; do echo "  ${d%/}"; done
    echo "current:"; sed 's/^/  /' CURRENT 2>/dev/null || true
    ;;
  prune)
    keep=$1
    referenced=$(for l in *.bin *.bin.gz; do [[ -L $l ]] && dirname "$(readlink "$l")"; done | sort -u)
    mapfile -t rel < <(for d in [0-9]*/; do echo "${d%/}"; done | sort -V)
    for ((i = 0; i < ${#rel[@]} - keep; i++)); do
      d=${rel[i]}
      grep -qxF -- "$d" <<<"$referenced" && continue
      echo "prune $d"; rm -rf -- "$d"
    done
    while read -r d; do
      grep -qxF -- "$d" <<<"$referenced" && continue
      echo "prune $d"; rm -rf -- "$d"
    done < <(find dev -mindepth 1 -maxdepth 1 -type d -mtime +14 2>/dev/null)
    ;;
  *) echo "unknown command $cmd"; exit 1 ;;
esac
```
- [ ] **Step 2: `muh/build.sh`** (full replacement; venv, env checks and profile parsing unchanged from today, manifest merge removed)
```bash
#!/usr/bin/env bash
# Build MUH Tasmota profiles into versioned folders and publish/promote them.
#
#   muh/build.sh [--clean] [--publish] [--promote [--force]] [profile ...|all]
#   muh/build.sh --promote-only <folder> [--force]     # rollback, e.g. 15.6.0-muh1
#   muh/build.sh --list
#   muh/build.sh --prune <keep>                         # keep newest <keep> releases
#
# Local:  build/<version>/<profile>_<token>.bin|.bin.gz|.factory.bin|.map.gz
# Host:   $MUH_OTA_DIR/<version>/..., dev/<version>/... (untagged or dirty),
#         $MUH_OTA_DIR/<profile>.<ext> symlinks = what devices' OtaUrl fetch.
# <token> = version with . and - as _ (Tasmota's OTA fallbacks parse filenames
# at the first '.' and last '-'). Needs muh/build.env.
set -euo pipefail
cd "$(dirname "$0")/.."

ENVFILE=muh/build.env
[[ -f $ENVFILE ]] || { echo "missing $ENVFILE (copy muh/build.env.example)"; exit 1; }
set -a; . "$ENVFILE"; set +a

host() {
  for v in MUH_OTA_HOST MUH_OTA_DIR; do [[ -n ${!v:-} ]] || { echo "$v empty in $ENVFILE"; exit 1; }; done
  ssh "$MUH_OTA_HOST" bash -s -- "$@" < muh/ota-host.sh
}

case ${1:-} in
  --list)         host list "$MUH_OTA_DIR"; exit ;;
  --prune)        host prune "$MUH_OTA_DIR" "${2:?usage: --prune <keep>}"; exit ;;
  --promote-only) host promote "$MUH_OTA_DIR" "${2:?usage: --promote-only <folder>}" ${3:-}; exit ;;
esac

for v in MUH_WIFI_SSID MUH_WIFI_PASS MUH_SYSLOG_HOST MUH_OTA_BASE; do
  [[ -n ${!v:-} ]] || { echo "$v is empty in $ENVFILE"; exit 1; }
done

# The espressif32 platform scripts need Python 3.10-3.13; the host has 3.14.
PIO=.venv/bin/pio
if [[ ! -x $PIO ]]; then
  command -v uv >/dev/null || { echo "need uv to create .venv (pacman -S uv)"; exit 1; }
  uv venv --python 3.13 .venv
  uv pip install --python .venv/bin/python platformio==6.1.19 pyyaml
fi

ALL=$(grep -o '^\[env:tasmota[0-9a-z]*-muh[^]]*\]' platformio_muh.ini | sed 's/\[env:\(.*\)\]/\1/')
publish=0 promote=0 clean=0 force='' profiles=()
for a in "$@"; do
  case $a in
    --publish) publish=1 ;;
    --promote) promote=1; publish=1 ;;
    --force)   force=--force ;;
    --clean)   clean=1 ;;
    all)       profiles+=($ALL) ;;
    *) grep -qxF -- "$a" <<<"$ALL" || { echo "unknown profile $a; known: $ALL"; exit 1; }; profiles+=("$a") ;;
  esac
done
[[ ${#profiles[@]} -gt 0 ]] || profiles=($ALL)
# ESP8266 profiles need the minimal image next to them (two-step OTA)
for p in "${profiles[@]}"; do [[ $p == tasmota-muh-* ]] && { profiles+=(tasmota-muh-minimal); break; }; done
mapfile -t profiles < <(printf '%s\n' "${profiles[@]}" | awk '!seen[$0]++')

. muh/version.sh
sub=$MUH_VERSION
[[ $MUH_CHANNEL == dev ]] && sub=dev/$MUH_VERSION
if [[ $promote -eq 1 && $MUH_CHANNEL == dev && -z $force ]]; then
  echo "refusing to promote dev build $MUH_VERSION: tag muh-v<upstream>-muh<N> on a clean tree, or add --force"
  exit 1
fi
echo "version $MUH_VERSION ($MUH_CHANNEL) -> build/$sub"

out=build/$sub
mkdir -p "$out"
[[ $clean -eq 1 ]] && rm -rf build_output .pio/build
[[ -f $out/build-info.txt ]] || {
  echo "version $MUH_VERSION ($MUH_CHANNEL)"
  echo "commit $(git rev-parse HEAD)"
} > "$out/build-info.txt"

for p in "${profiles[@]}"; do
  echo "=== $p"
  "$PIO" run -e "$p"
  rm -f "$out/${p}_"*
  for ext in bin bin.gz factory.bin; do
    f=build_output/firmware/$p.$ext
    [[ -f $f ]] && cp "$f" "$out/${p}_$MUH_VERTOKEN.$ext"
  done
  for ext in map map.gz; do
    f=build_output/map/$p.$ext
    [[ -f $f ]] && cp "$f" "$out/${p}_$MUH_VERTOKEN.$ext"
  done
  echo "built $p $(date -Iseconds) on $(uname -n)" >> "$out/build-info.txt"
done

# stable minimal name inside the folder, for canaries pointed at a versioned URL
if [[ -f $out/tasmota-muh-minimal_$MUH_VERTOKEN.bin.gz ]]; then
  ln -sfn "tasmota-muh-minimal_$MUH_VERTOKEN.bin.gz" "$out/tasmota-muh-minimal.bin.gz"
  ln -sfn "tasmota-muh-minimal_$MUH_VERTOKEN.bin"    "$out/tasmota-muh-minimal.bin"
fi
(cd "$out" && sha256sum -- *_*.bin *_*.bin.gz > SHA256SUMS 2>/dev/null) || true
echo; cat "$out/SHA256SUMS"

if [[ $publish -eq 1 ]]; then
  ssh "$MUH_OTA_HOST" mkdir -p "$MUH_OTA_DIR/$sub"
  rsync -rlt --chmod=D755,F644 --exclude='*.map' --exclude='*.map.gz' "$out/" "$MUH_OTA_HOST:$MUH_OTA_DIR/$sub/"
  host sums "$MUH_OTA_DIR" "$sub"
  echo "published $MUH_OTA_BASE/$sub/"
fi
if [[ $promote -eq 1 ]]; then
  host promote "$MUH_OTA_DIR" "$sub" $force
fi
```
- [ ] **Step 3: Verify without the host**: `bash -n muh/build.sh muh/ota-host.sh`; `bash muh/test-version.sh`; `muh/build.sh nope` → exit 1. On a dirty tree `muh/build.sh --promote tasmota32solo1-muh` → refuses before building.
- [ ] **Step 4: Verify ota-host.sh locally** against a scratch dir (no ssh): create `/tmp/ota-t/15.6.0-muh1/{tasmota32solo1-muh_15_6_0_muh1.bin,tasmota32solo1-muh_15_6_0_muh1.factory.bin,tasmota-muh-plug_15_6_0_muh1.bin.gz}` with dummy content and a regular file `/tmp/ota-t/tasmota32solo1-muh.bin`; run `bash muh/ota-host.sh promote /tmp/ota-t 15.6.0-muh1`; expect three symlinks, `CURRENT` with three lines, `SHA256SUMS` hashing the dummy content; `promote /tmp/ota-t dev/x` → refuses; `prune /tmp/ota-t 0` keeps `15.6.0-muh1` (referenced).
- [ ] **Step 5: Commit**: `build: versioned image names and folders; publish/promote/list/prune via muh/ota-host.sh`.

---

### Task 5: CI uses the same names

**Files:**
- Modify: `.github/workflows/muh-build.yml`

- [ ] **Step 1:** build job: `actions/checkout@v4` with `with: { fetch-depth: 0 }` (describe needs tags and history). Add a step before `pio run`:
```yaml
      - name: Version
        run: |
          bash muh/test-version.sh
          . muh/version.sh
          echo "MUH_VERSION=$MUH_VERSION" >> "$GITHUB_ENV"
          echo "MUH_VERTOKEN=$MUH_VERTOKEN" >> "$GITHUB_ENV"
```
- [ ] **Step 2:** Collect step:
```yaml
      - name: Collect
        run: |
          p=${{ matrix.profile }}
          mkdir -p "out/$p"
          for ext in bin bin.gz factory.bin map map.gz; do
            f=build_output/firmware/$p.$ext; [ -f "$f" ] || f=build_output/map/$p.$ext
            [ -f "$f" ] && cp "$f" "out/$p/${p}_${MUH_VERTOKEN}.$ext"
          done
          (cd "out/$p" && sha256sum * > SHA256SUMS)
```
- [ ] **Step 3:** release step: name the release after the version (`with: name: MUH ${{ github.ref_name }}`); assets are already versioned; keep the combined `SHA256SUMS`.
- [ ] **Step 4: Verify**: YAML parses (`.venv/bin/python -c 'import yaml; yaml.safe_load(open(".github/workflows/muh-build.yml"))'`); `tasmota-muh-minimal` appears in the matrix list produced by the grep. Commit: `ci: versioned asset names, shared version logic`.

---

### Task 6: First versioned release and host migration

- [ ] **Step 1:** clean tree, `git tag -a muh-v15.6.0-muh1 -m "MUH 15.6.0 build 1: versioned images, build id, minimal"`.
- [ ] **Step 2:** `muh/build.sh --promote all` (builds 12 profiles incl. minimal, publishes to `15.6.0-muh1/`, promotes). Expected: `version 15.6.0-muh1 (release)`, `promoted 15.6.0-muh1:` with 12 profiles' lines.
- [ ] **Step 3: Verify host**:
```bash
muh/build.sh --list
curl -s http://192.168.22.11/tasmota/CURRENT
curl -s http://192.168.22.11/tasmota/15.6.0-muh1/SHA256SUMS
ssh ben@192.168.22.11 'cd /var/www/html/tasmota && find . -maxdepth 1 -type f'   # only SHA256SUMS and CURRENT remain as regular files
curl -sI http://192.168.22.11/tasmota/tasmota-muh-minimal.bin.gz | head -1          # 200
```
- [ ] **Step 4: Every device's OtaUrl resolves** (from tasmota-scripts): `tools/fleet-cmd.sh OtaUrl` and `curl -s -o /dev/null -w '%{http_code}'` on each returned URL → 200 for every MUH device.
- [ ] **Step 5: Rollback drill**: `muh/build.sh --promote-only 15.6.0` must fail (folder does not exist, the old flat files were not versioned) — expected, documents that rollback works from `15.6.0-muh1` onward.
- [ ] **Step 6:** `git push origin muh muh-v15.6.0-muh1`. The tag triggers CI; it needs the four repository secrets.

---

### Task 7: `make fleet` shows the running build (tasmota-scripts)

**Files:**
- Modify: `tools/fleet-check.sh`, `README.md`

- [ ] **Step 1:** fetch `CURRENT` once (`OTA_BASE=${OTA_BASE:-http://192.168.22.11/tasmota}`), and per device read `Status 2` `Version` (e.g. `15.6.0(15.6.0-muh1-tasmota32)`) and `OtaUrl`:
```bash
current=$(curl -s --max-time 5 "$OTA_BASE/CURRENT")
...
ver=$(cm "$ip" Status%202 | grep -o '"Version":"[^"]*"' | cut -d'"' -f4)
img=${ver#*(}; img=${img%)}
ota=$(cm "$ip" OtaUrl | grep -o '"OtaUrl":"[^"]*"' | cut -d'"' -f4)
want=$(awk -v f="${ota##*/}" '$1 == f {print $3}' <<<"$current"); want=${want%/*}; want=${want#dev/}
if [[ -z $want ]]; then build=stock
elif [[ $img == "$want-"* ]]; then build=$want
else build="old:${ver%%(*}"; note="$note UPGRADE-PENDING"; fi
```
  Add a `BUILD` column. `UPGRADE-PENDING` is informational and does NOT change the exit code (every device shows it until it is upgraded).
- [ ] **Step 2: Verify**: `bash tools/fleet-check.sh HZ_WW` shows `old:15.1.0 … UPGRADE-PENDING` today and exit 0 if otherwise healthy. Commit: `feat(fleet-check): BUILD column against promoted OTA version`.

---

### Task 8: Docs

- [ ] `README-MUH.md`: layout on the host, filename rule and why, version/channel rules, `--publish`/`--promote`/`--promote-only`/`--list`/`--prune`, canary flow:
  1. `muh/build.sh --publish all` (no promote)
  2. canary: `OtaUrl http://192.168.22.11/tasmota/15.6.0-muh2/tasmota32solo1-muh_15_6_0_muh2.bin`, `Upgrade 1`, check, then set `OtaUrl` back to the stable name
  3. `muh/build.sh --promote-only 15.6.0-muh2`
  4. rollback: `muh/build.sh --promote-only 15.6.0-muh1`
- [ ] tasmota-scripts `README.md`: one line on the `BUILD` column.
- [ ] Commit both repos.

## Self-Review

- Version in filename: Task 4 (`<profile>_<token>.<ext>`), CI Task 5. Version folders: Task 4/6 (`<version>/`, `dev/<version>/`). Devices unaffected: stable symlinks, verified in Task 6 Step 4.
- The Tasmota filename-rewrite trap is encoded in tests (Task 1) and in the naming rule; the missing ESP8266 minimal image is fixed (Task 3) and linked inside each folder.
- Build id: header approach avoids full rebuilds (Task 2 Step 2 checks it).
- Rollback and canary: Task 4 `--promote-only`, documented in Task 8.
- Placeholders: none. Names: `muh/version.sh`, `muh/test-version.sh`, `muh/ota-host.sh`, `MUH_VERSION`, `MUH_VERTOKEN`, `MUH_CHANNEL`, `tasmota/muh_build_id.h`, `tasmota-muh-minimal`, `CURRENT`, `SHA256SUMS`.

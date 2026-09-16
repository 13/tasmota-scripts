# Tasmota Fork: Build Profiles, Local Build Script, GitHub Actions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `~/repo/tasmota` (fork `github.com/13/tasmota`, tag `muh-v15.2.0`) from "comment a `BEN_*` define, run pio, hope" into named build profiles that build identically on this machine and on GitHub Actions, with Wi-Fi credentials, syslog host and OTA base URL injected, images published to a LAN OTA directory, and every build keeping its `.map` so the next crash can be decoded.

**Architecture:** Profiles are PlatformIO envs `muh-*` in a new tracked file `platformio_muh.ini`, pulled in via `extra_configs` from `platformio_override.ini`. Each env `extends` the matching upstream env (`tasmota32solo1`, `tasmota32`, `tasmota32c3`, `tasmota32s2`, `tasmota32s3`, `tasmota`) and adds its `-DBEN_*` flag(s); shared flags live in a `[muh]` section. Secrets and site values come from environment variables (`${sysenv.MUH_*}`), loaded from a git-ignored `muh/build.env` locally and from repository secrets in CI. `muh/build.sh` builds profiles, collects `.bin`/`.factory.bin`/`.map` plus a manifest into `build/`, and optionally rsyncs to the OTA host. `.github/workflows/muh-build.yml` builds the matrix on tag push and manual dispatch, uploads artifacts, and attaches them to a GitHub Release. Fleet-side settings (OtaUrl, syslog) are pushed with a small script in `tasmota-scripts`.

**Tech Stack:** PlatformIO 6.1.19 in a project-local `.venv` (Python 3.13 via `uv`; system Python 3.14 is too new for the espressif32 platform scripts), Tasmota fork at `~/repo/tasmota` (last upstream merge `fcdb10631`, prerelease-15.2.0), GitHub Actions ubuntu-latest, rsync/ssh.

## Global Constraints

- Repo is private; history is NOT rewritten. But after Task 1 no credential may remain in any tracked file at HEAD.
- Nothing in `~/repo/tasmota` outside these files changes: `platformio_override.ini`, new `platformio_muh.ini`, `tasmota/user_config_override.h`, new `muh/` dir, new `.github/workflows/muh-build.yml`, `.gitignore`, `README-MUH.md`. The existing source patches (webserver footer, tuyamcu v1/v2 swap, AS608 LED colours) stay untouched.
- Every `muh-*` env `extends` an upstream env and only ADDS `build_flags` via `${env:<parent>.build_flags}` first; no board/partition changes except where the parent env already sets them.
- The `BEN_*` macro names in `user_config_override.h` stay exactly as they are (including the misspelt `BEN_PARKASSITANT`).
- Build must FAIL if `MUH_WIFI_SSID`, `MUH_WIFI_PASS`, `MUH_SYSLOG_HOST` or `MUH_OTA_BASE` is unset (no silent empty credentials).
- Firmware output naming is upstream's: `build_output/firmware/<env>.bin`, `build_output/firmware/<env>.factory.bin` (ESP32), `build_output/map/<env>.map`. Do not modify `pio-tools/`.
- Site values (fill once in `muh/build.env`; the plan uses these names, not literal hosts): `MUH_OTA_HOST` (ssh target `user@host`), `MUH_OTA_DIR` (directory served over http), `MUH_OTA_BASE` (http URL of that directory as devices see it, no trailing slash), `MUH_SYSLOG_HOST` (IP for udp/514). The old custom env `tasmota32s2-display` hard-codes `http://192.168.22.99/tasmota/`; that host is the historical OTA server and the likely value.

## Profiles (final list)

| env | extends | extra flags | devices |
|---|---|---|---|
| `muh-solo1` | `env:tasmota32solo1` | — | Shelly Plus 1 / 1PM / 2PM: HZ_WW, HZ_DG, FL2, FL3, Bad, HD_INT, HD_EXT, G_EXT, G_INT, PV_A |
| `muh-32` | `env:tasmota32` | — | SOLAR_EXT, PV, generic ESP32 |
| `muh-32c3` | `env:tasmota32c3` | — | Shelly Mini G3 (WZ3, G_TREPPE, HZ_DGB), Athom Plug V3 (PlugUD) |
| `muh-32s3-hdgd` | `env:tasmota32s3` | `-DBEN_HDGD` | HD, GD |
| `muh-32s3-park` | `env:tasmota32s3` | `-DBEN_PARKASSITANT` | PARK2 |
| `muh-32s2-park` | `env:tasmota32s2` | `-DBEN_PARKASSITANT` | PARK1 |
| `muh-32s2-epaper` | `env:tasmota32s2` | `-DBEN_EPAPER -DFIRMWARE_DISPLAYS` + display libs (copied from the fork's `tasmota32s2-display` env) | epaper |
| `muh-32-annauhr` | `env:tasmota32` | `-DBEN_ANNA_UHR` | AnnaUhr |
| `muh-32-3em` | `env:tasmota32` | `-DBEN_SHELLY3EM` | 3EM |
| `muh-8266-bresser` | `env:tasmota` | `-DBEN_TUYA_BRESSER` | ESP12S Bresser |
| `muh-8266-plug` | `env:tasmota` | — | Athom Plug V2 (8266) |

Deviation from the agreed list, with reason: `solo1-ds18b20` is folded into `muh-solo1` and `BEN_DS18B20` (DS18x20 with ID-as-name) plus `BEN_PV` (`USE_WEBSEND_RESPONSE`, tiny) go into the shared `[muh]` flags. HZ_WW and SOLAR_EXT both already run ID-named DS18B20 keys, the flags cost nothing on devices without the sensor, and one image per chip class is simpler to keep on the OTA server.

---

### Task 1: Credentials and site values via environment, out of tracked files

**Files:**
- Modify: `tasmota/user_config_override.h` (lines with `STA_SSID1`, `STA_PASS1`; add syslog and OTA blocks)
- Create: `muh/build.env.example`
- Modify: `.gitignore` (add `muh/build.env`, `build/`)

**Interfaces:**
- Produces build macros consumed by the override: `MUH_WIFI_SSID`, `MUH_WIFI_PASS`, `MUH_SYSLOG_HOST`, `MUH_OTA_URL` (all string literals passed as `-D`).

- [ ] **Step 1: Replace the credential block** in `tasmota/user_config_override.h`:
```c
// Wi-Fi credentials come from the build environment (muh/build.env locally,
// repository secrets in CI). Missing values must fail the build, not ship empty.
#ifndef MUH_WIFI_SSID
#error "MUH_WIFI_SSID not set: source muh/build.env or set the CI secret"
#endif
#ifndef MUH_WIFI_PASS
#error "MUH_WIFI_PASS not set: source muh/build.env or set the CI secret"
#endif
#undef  STA_SSID1
#define STA_SSID1 MUH_WIFI_SSID
#undef  STA_PASS1
#define STA_PASS1 MUH_WIFI_PASS
```
- [ ] **Step 2: Add site defaults** after the MQTT block:
```c
// Syslog to a durable host so a crash storm leaves evidence. Applied on
// settings reset only; existing devices get it via tasmota-scripts/tools/fleet-cmd.sh.
#ifndef MUH_SYSLOG_HOST
#error "MUH_SYSLOG_HOST not set"
#endif
#undef  SYS_LOG_LEVEL
#define SYS_LOG_LEVEL          LOG_LEVEL_INFO
#undef  SYS_LOG_HOST
#define SYS_LOG_HOST           MUH_SYSLOG_HOST
#undef  SYS_LOG_PORT
#define SYS_LOG_PORT           514

// OTA URL per profile, from platformio_muh.ini
#ifndef MUH_OTA_URL
#error "MUH_OTA_URL not set"
#endif
#undef  OTA_URL
#define OTA_URL                MUH_OTA_URL

// Shared MUH features (see plan): DS18x20 named by ID, WebSend responses
#define BEN_DS18B20
#define BEN_PV
```
  Delete the commented `// #define BEN_DS18B20` and `// #define BEN_PV` lines at the top of the file (they are now defined unconditionally); leave the other commented `BEN_*` lines as documentation.
- [ ] **Step 3: `muh/build.env.example`**
```sh
# Copy to muh/build.env (git-ignored) and fill in. Sourced by muh/build.sh.
MUH_WIFI_SSID=muhxnetwork
MUH_WIFI_PASS=change-me
# Host receiving syslog (udp/514) from all devices
MUH_SYSLOG_HOST=192.168.22.99
# rsync target for built images and the URL devices use to fetch them
MUH_OTA_HOST=ben@192.168.22.99
MUH_OTA_DIR=/var/www/html/tasmota
MUH_OTA_BASE=http://192.168.22.99/tasmota
```
- [ ] **Step 4: `.gitignore`**: append `muh/build.env` and `build/`.
- [ ] **Step 5: Verify no secret at HEAD**: `git grep -n 'Wombat' -- . ':!*.md'` returns nothing after staging. `grep -c 'STA_PASS1' tasmota/user_config_override.h` shows only the macro line.
- [ ] **Step 6: Commit**: `build: take Wi-Fi, syslog and OTA values from the environment`.

---

### Task 2: `platformio_muh.ini` profiles

**Files:**
- Create: `platformio_muh.ini`
- Modify: `platformio_override.ini` (`extra_configs`, `default_envs`)

- [ ] **Step 1: `platformio_muh.ini`**
```ini
; MUH build profiles. Included by platformio_override.ini (extra_configs).
; Every env extends an upstream env and only adds flags. Site values come
; from the environment: MUH_WIFI_SSID, MUH_WIFI_PASS, MUH_SYSLOG_HOST, MUH_OTA_BASE.

[muh]
build_flags = -DUSE_BERRY_PARTITION_WIZARD
              -DMUH_WIFI_SSID='"${sysenv.MUH_WIFI_SSID}"'
              -DMUH_WIFI_PASS='"${sysenv.MUH_WIFI_PASS}"'
              -DMUH_SYSLOG_HOST='"${sysenv.MUH_SYSLOG_HOST}"'

[env:muh-solo1]
extends     = env:tasmota32solo1
build_flags = ${env:tasmota32solo1.build_flags} ${muh.build_flags}
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-solo1.bin"'

[env:muh-32]
extends     = env:tasmota32
build_flags = ${env:tasmota32.build_flags} ${muh.build_flags}
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32.bin"'

[env:muh-32c3]
extends     = env:tasmota32c3
build_flags = ${env:tasmota32c3.build_flags} ${muh.build_flags}
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32c3.bin"'

[env:muh-32s3-hdgd]
extends     = env:tasmota32s3
build_flags = ${env:tasmota32s3.build_flags} ${muh.build_flags}
              -DBEN_HDGD
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32s3-hdgd.bin"'

[env:muh-32s3-park]
extends     = env:tasmota32s3
build_flags = ${env:tasmota32s3.build_flags} ${muh.build_flags}
              -DBEN_PARKASSITANT
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32s3-park.bin"'

[env:muh-32s2-park]
extends     = env:tasmota32s2
build_flags = ${env:tasmota32s2.build_flags} ${muh.build_flags}
              -DBEN_PARKASSITANT
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32s2-park.bin"'

[env:muh-32s2-epaper]
extends     = env:tasmota32s2
build_flags = ${env:tasmota32s2.build_flags} ${muh.build_flags}
              -DBEN_EPAPER -DFIRMWARE_DISPLAYS
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32s2-epaper.bin"'
lib_extra_dirs = lib/libesp32, lib/lib_basic, lib/lib_display, lib/lib_ssl
lib_ignore  = ${env:tasmota32_base.lib_ignore}
              Micro-RTSP
              epdiy

[env:muh-32-annauhr]
extends     = env:tasmota32
build_flags = ${env:tasmota32.build_flags} ${muh.build_flags}
              -DBEN_ANNA_UHR
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32-annauhr.bin"'

[env:muh-32-3em]
extends     = env:tasmota32
build_flags = ${env:tasmota32.build_flags} ${muh.build_flags}
              -DBEN_SHELLY3EM
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-32-3em.bin"'

[env:muh-8266-bresser]
extends     = env:tasmota
build_flags = ${env:tasmota.build_flags} ${muh.build_flags}
              -DBEN_TUYA_BRESSER
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-8266-bresser.bin.gz"'

[env:muh-8266-plug]
extends     = env:tasmota
build_flags = ${env:tasmota.build_flags} ${muh.build_flags}
              -DMUH_OTA_URL='"${sysenv.MUH_OTA_BASE}/muh-8266-plug.bin.gz"'
```
  Note: `env:tasmota` already sets `-DOTA_URL=...` in its flags; the override's `#undef OTA_URL / #define OTA_URL MUH_OTA_URL` wins because `user_config_override.h` is included after `my_user_config.h`; verify in Step 3 that the compiler does not warn about `OTA_URL` redefinition (if it does, add `-UOTA_URL` right after `${env:tasmota.build_flags}` in the two 8266 envs).
- [ ] **Step 2: `platformio_override.ini`**: under `[platformio]` add `extra_configs = platformio_muh.ini`; replace the whole `default_envs` list with the eleven `muh-*` names; remove the now-duplicated `build_flags = -DUSE_BERRY_PARTITION_WIZARD` from `[tasmota]` (it is in `[muh]`).
- [ ] **Step 3: Verify one env per chip class builds** (with `muh/build.env` filled and sourced: `set -a; . muh/build.env; set +a`):
```bash
pio run -e muh-solo1 -e muh-32c3 -e muh-8266-plug 2>&1 | tail -5
ls -la build_output/firmware/muh-solo1.bin build_output/firmware/muh-solo1.factory.bin build_output/map/muh-solo1.map
strings build_output/firmware/muh-solo1.bin | grep -c "$MUH_OTA_BASE/muh-solo1.bin"   # 1
```
  Negative test: `env -u MUH_WIFI_PASS pio run -e muh-solo1` must fail with the `#error` text.
- [ ] **Step 4: Commit**: `build: muh-* PlatformIO profiles in platformio_muh.ini`.

---

### Task 3: `muh/build.sh` local build + publish

**Files:**
- Create: `muh/build.sh` (executable)

**Interfaces:**
- `muh/build.sh [--publish] [--clean] [profile ...|all]`. Default `all`. Output `build/<profile>/{<profile>.bin,<profile>.factory.bin,<profile>.map}` (8266: `.bin` and `.bin.gz`, no factory), `build/manifest.txt` (git describe, date, per-file sha256). `--publish` rsyncs `build/*/*.bin*` flat into `$MUH_OTA_HOST:$MUH_OTA_DIR/` plus the manifest, keeps maps local under `build/`.

- [ ] **Step 1: Script**
```bash
#!/usr/bin/env bash
# Build MUH Tasmota profiles locally and optionally publish to the LAN OTA dir.
# Usage: muh/build.sh [--publish] [--clean] [profile ...|all]
# Needs muh/build.env (copy from muh/build.env.example).
set -euo pipefail
cd "$(dirname "$0")/.."

ENVFILE=muh/build.env
[[ -f $ENVFILE ]] || { echo "missing $ENVFILE (copy muh/build.env.example)"; exit 1; }
set -a; . "$ENVFILE"; set +a
for v in MUH_WIFI_SSID MUH_WIFI_PASS MUH_SYSLOG_HOST MUH_OTA_BASE; do
  [[ -n ${!v:-} ]] || { echo "$v is empty in $ENVFILE"; exit 1; }
done

# The espressif32 platform scripts need Python 3.10-3.13; the host has 3.14.
# Use a project-local venv (created with uv on first run) instead of system pio.
PIO=.venv/bin/pio
if [[ ! -x $PIO ]]; then
  command -v uv >/dev/null || { echo "need uv to create .venv (pacman -S uv)"; exit 1; }
  uv venv --python 3.13 .venv
  uv pip install --python .venv/bin/python platformio==6.1.19
fi

ALL=$(grep -o '^\[env:muh-[^]]*\]' platformio_muh.ini | sed 's/\[env:\(.*\)\]/\1/')
publish=0 clean=0 profiles=()
for a in "$@"; do
  case $a in
    --publish) publish=1 ;;
    --clean) clean=1 ;;
    all) profiles+=($ALL) ;;
    *) grep -qx "$a" <<<"$ALL" || { echo "unknown profile $a; known: $ALL"; exit 1; }; profiles+=("$a") ;;
  esac
done
[[ ${#profiles[@]} -gt 0 ]] || profiles=($ALL)

[[ $clean -eq 1 ]] && rm -rf build_output .pio/build
version=$(git describe --tags --always --dirty)
mkdir -p build
: > build/manifest.txt
echo "version $version" >> build/manifest.txt
echo "built $(date -Iseconds) on $(hostname)" >> build/manifest.txt

for p in "${profiles[@]}"; do
  echo "=== $p"
  "$PIO" run -e "$p"
  rm -rf "build/$p"; mkdir -p "build/$p"
  cp build_output/firmware/"$p".bin* "build/$p/"
  [[ -f build_output/map/$p.map ]] && cp "build_output/map/$p.map" "build/$p/"
  (cd "build/$p" && sha256sum ./*.bin* ) | sed "s|^\([0-9a-f]*\)  ./|\1  $p/|" >> build/manifest.txt
done
echo; cat build/manifest.txt

if [[ $publish -eq 1 ]]; then
  for v in MUH_OTA_HOST MUH_OTA_DIR; do [[ -n ${!v:-} ]] || { echo "$v empty, cannot publish"; exit 1; }; done
  files=()
  for p in "${profiles[@]}"; do files+=(build/"$p"/*.bin*); done
  rsync -av --chmod=F644 "${files[@]}" build/manifest.txt "$MUH_OTA_HOST:$MUH_OTA_DIR/"
  echo "published to $MUH_OTA_HOST:$MUH_OTA_DIR ($MUH_OTA_BASE)"
fi
```
- [ ] **Step 2: Verify**: `bash -n muh/build.sh`; `muh/build.sh muh-solo1` produces `build/muh-solo1/muh-solo1.bin`, `.factory.bin`, `.map` and a manifest with three sha256 lines; `muh/build.sh nope` exits 1 with the known list; `muh/build.sh --publish muh-solo1` then `curl -sI "$MUH_OTA_BASE/muh-solo1.bin" | head -1` → `HTTP/1.1 200`.
- [ ] **Step 3: Commit**: `build: muh/build.sh local build, manifest, --publish to OTA dir`.

---

### Task 4: GitHub Actions `muh-build.yml`

**Files:**
- Create: `.github/workflows/muh-build.yml`

Repository secrets to create (Settings > Secrets and variables > Actions): `MUH_WIFI_SSID`, `MUH_WIFI_PASS`, `MUH_SYSLOG_HOST`, `MUH_OTA_BASE`.

- [ ] **Step 1: Workflow**
```yaml
name: muh-build
on:
  push:
    tags: ['muh-v*']
  workflow_dispatch:
    inputs:
      profiles:
        description: 'space-separated muh-* profiles, or all'
        default: all
jobs:
  matrix:
    runs-on: ubuntu-latest
    outputs:
      profiles: ${{ steps.list.outputs.profiles }}
    steps:
      - uses: actions/checkout@v4
      - id: list
        run: |
          all=$(grep -o '^\[env:muh-[^]]*\]' platformio_muh.ini | sed 's/\[env:\(.*\)\]/\1/')
          want="${{ github.event.inputs.profiles || 'all' }}"
          [[ $want == all ]] && want=$all
          echo "profiles=$(echo $want | tr ' ' '\n' | jq -R . | jq -sc .)" >> "$GITHUB_OUTPUT"
  build:
    needs: matrix
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        profile: ${{ fromJson(needs.matrix.outputs.profiles) }}
    env:
      MUH_WIFI_SSID: ${{ secrets.MUH_WIFI_SSID }}
      MUH_WIFI_PASS: ${{ secrets.MUH_WIFI_PASS }}
      MUH_SYSLOG_HOST: ${{ secrets.MUH_SYSLOG_HOST }}
      MUH_OTA_BASE: ${{ secrets.MUH_OTA_BASE }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - uses: actions/cache@v4
        with:
          path: |
            ~/.platformio
            .pio
          key: pio-${{ runner.os }}-${{ matrix.profile }}-${{ hashFiles('platformio*.ini') }}
          restore-keys: pio-${{ runner.os }}-${{ matrix.profile }}-
      - run: pip install -U platformio
      - name: Guard secrets present
        run: for v in MUH_WIFI_SSID MUH_WIFI_PASS MUH_SYSLOG_HOST MUH_OTA_BASE; do [[ -n "${!v}" ]] || { echo "secret $v missing"; exit 1; }; done
      - run: pio run -e ${{ matrix.profile }}
      - name: Collect
        run: |
          mkdir -p out/${{ matrix.profile }}
          cp build_output/firmware/${{ matrix.profile }}.bin* out/${{ matrix.profile }}/
          [ -f build_output/map/${{ matrix.profile }}.map ] && cp build_output/map/${{ matrix.profile }}.map out/${{ matrix.profile }}/
          (cd out/${{ matrix.profile }} && sha256sum * > SHA256SUMS)
      - uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.profile }}
          path: out/${{ matrix.profile }}
          retention-days: 30
  release:
    if: startsWith(github.ref, 'refs/tags/muh-v')
    needs: build
    runs-on: ubuntu-latest
    permissions: { contents: write }
    steps:
      - uses: actions/download-artifact@v4
        with: { path: out }
      - run: |
          mkdir -p release
          for d in out/*/; do p=$(basename "$d"); for f in "$d"*; do cp "$f" "release/$(basename "$f")"; done; done
          (cd release && sha256sum *.bin* > SHA256SUMS)
          ls -la release
      - uses: softprops/action-gh-release@v2
        with:
          files: release/*
          generate_release_notes: true
```
  Maps are inside the artifacts and the release (`<profile>.map`), which is what Task 4 of the fleet-recovery plan lacked for stock builds. Keep them.
- [ ] **Step 2: Verify**: push the branch, run `workflow_dispatch` with `profiles: muh-solo1`; job green; artifact contains `.bin`, `.factory.bin`, `.map`, `SHA256SUMS`. Then tag `muh-v15.2.0-muh1` and push the tag; release page lists all eleven profiles' files.
- [ ] **Step 3: Commit**: `ci: muh-build workflow (matrix over muh-* profiles, release on muh-v* tags)`.

---

### Task 5: Fleet settings push (tasmota-scripts repo)

**Files (in `~/repo/tasmota-scripts`):**
- Create: `tools/fleet-cmd.sh`
- Modify: `README.md`

- [ ] **Step 1: Script** — send one Tasmota command to every device from `devices.tsv` (or given names/IPs), print replies:
```bash
#!/usr/bin/env bash
# Send one Tasmota command to devices. Usage: tools/fleet-cmd.sh '<command>' [name|ip ...]
# With no targets: every IP in devices.tsv plus $FLEET_EXTRA. Prints one line per device.
set -uo pipefail
cd "$(dirname "$0")/.."
cmd=${1:?command required}; shift
targets=()
if [[ $# -gt 0 ]]; then
  for t in "$@"; do ip=$(awk -F'\t' -v n="$t" '$1==n{print $2}' devices.tsv); targets+=("${ip:-$t}"); done
else
  while IFS=$'\t' read -r name ip _; do [[ $name == \#* || -z $name || $ip == "?" ]] && continue; targets+=("$ip"); done < devices.tsv
  for ip in ${FLEET_EXTRA:-}; do targets+=("$ip"); done
fi
enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$cmd")
rc=0
for ip in "${targets[@]}"; do
  name=$(curl -s --connect-timeout 3 --max-time 6 "http://$ip/cm?cmnd=DeviceName" | grep -o '"DeviceName":"[^"]*"' | cut -d'"' -f4)
  reply=$(curl -s --connect-timeout 3 --max-time 8 "http://$ip/cm?cmnd=$enc")
  [[ -z $reply ]] && rc=1
  printf '%-10s %-16s %s\n' "${name:-?}" "$ip" "${reply:-NO ANSWER}"
done
exit $rc
```
- [ ] **Step 2: Apply after the first published build** (values from `muh/build.env`):
```bash
tools/fleet-cmd.sh "Backlog LogHost $MUH_SYSLOG_HOST; LogPort 514; SysLog 2"
tools/fleet-cmd.sh "OtaUrl $MUH_OTA_BASE/muh-solo1.bin" HZ_WW HZ_DG FL2 FL3 BAD HD_INT HD_EXT G_EXT G_INT PV_A
tools/fleet-cmd.sh "OtaUrl $MUH_OTA_BASE/muh-32c3.bin" G_TREPPE PlugUD
tools/fleet-cmd.sh "OtaUrl $MUH_OTA_BASE/muh-32s3-hdgd.bin" HD GD
tools/fleet-cmd.sh "OtaUrl $MUH_OTA_BASE/muh-32s3-park.bin" PARK2
tools/fleet-cmd.sh "OtaUrl $MUH_OTA_BASE/muh-32-annauhr.bin" AnnaUhr
```
  Verify with `tools/fleet-cmd.sh OtaUrl` and `tools/fleet-cmd.sh SysLog`. Upgrading a device is then `Upgrade 1` on that device, one at a time, `make fleet` afterwards.
- [ ] **Step 3: README** line under Workflow: `tools/fleet-cmd.sh '<cmd>' [names]   # send a Tasmota command to devices`.
- [ ] **Step 4: Commit** in tasmota-scripts: `feat(tools): fleet-cmd.sh; document OtaUrl/syslog rollout`.

---

### Task 6: README-MUH.md in the fork

**Files:**
- Create: `README-MUH.md` in `~/repo/tasmota`

- [ ] **Step 1**: document profiles table (copy from this plan), `muh/build.env` setup, `muh/build.sh` usage, the workflow, secrets list, tagging convention `muh-v<upstream>-muh<N>`, how to update from upstream (`git fetch upstream; git merge upstream/master` then re-run `muh/build.sh all`), and where maps live for decoding `Status 12` call chains (`xtensa-esp32-elf-addr2line -e .pio/build/<env>/firmware.elf 0x....` locally, or the `.map` from the release).
- [ ] **Step 2: Commit**: `docs: README-MUH for profiles, build and CI`.

## Self-Review

- Secrets out of tracked files: Task 1. Profiles: Task 2 (eleven envs, two merges explained). Local script: Task 3. CI + releases: Task 4. LAN OTA publish: Task 3 `--publish`. Syslog defaults: Task 1 + Task 5 rollout to existing devices. Crash-decoding gap from the last incident: maps kept by Tasks 3/4 and documented in Task 6.
- Open value inputs live in one file (`muh/build.env`) and four CI secrets; no other placeholders.
- Not covered on purpose: rewriting git history (repo private, owner chose to keep), changing any Tasmota source, flashing devices (manual `Upgrade 1`, one at a time).

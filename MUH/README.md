# MUH Berry scripts

One script per device, dispatched by `autoexec.be` via `DeviceName`.
`muh_lib.be` holds the shared helpers; see the repo root README for the
boot chain, inventory and deploy workflow.

## Conventions

- Provisioning commands (template, IPs, names) live in the `#- ... -#`
  header of each device script. Note: many headers still show the
  copy-paste IP `192.168.22.70` — trust `../devices.tsv`, not the header.
- Config globals (`DARK_OFFSET`, `POWER_TIMER_DURATION`, ...) are assigned
  without `var` in device scripts to override the `muh_lib.be` defaults.
- `log()` (from autoexec.be) instead of `print()` — silenced via `DEBUG`.

## Safeboot

```
Backlog otaurl http://192.168.22.11:8000/tasmota32solo1-1450-safeboot.bin; upload 2
```

#!/usr/bin/env bash
# system-doctor.sh -- read-only health check for an Arch Linux host.
#
#   ./system-doctor.sh            full report for the current boot
#   ./system-doctor.sh -q         print only the sections that found something
#   ./system-doctor.sh -b -1      check the previous boot (crash / failed-shutdown triage)
#   ./system-doctor.sh -h         this help
#
# Read-only: writes nothing, restarts nothing, repairs nothing. Safe as a normal
# user. A few hardware checks (SMART, EDAC) need root and are reported as skipped
# when they cannot read the device. Exit status is the number of findings (capped
# at 125), so `system-doctor.sh || notify-send ...` works from a timer.
#
# Companion note: arch-linux/system-diagnostics-and-self-healing.md

set -euo pipefail

QUIET=0
BOOT=""

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

while getopts ":qb:h" opt; do
  case $opt in
    q) QUIET=1 ;;
    b) BOOT=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [ -n "$BOOT" ]; then BOOTFLAG=(-b "$BOOT"); else BOOTFLAG=(-b); fi

BOLD=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; RST=$'\033[0m'
[ -t 1 ] || { BOLD='' DIM='' GRN='' YEL='' RED='' RST=''; }

FINDINGS=0
have() { command -v "$1" >/dev/null 2>&1; }
hdr()  { [ "$QUIET" -eq 1 ] || printf '\n%s== %s%s\n' "$BOLD" "$*" "$RST"; }
ok()   { [ "$QUIET" -eq 1 ] || printf '   %sok%s    %s\n' "$GRN" "$RST" "$*"; }
note() { [ "$QUIET" -eq 1 ] || printf '   %s--%s    %s\n' "$DIM" "$RST" "$*"; }
warn() { printf '   %swarn%s  %s\n' "$YEL" "$RST" "$*"; FINDINGS=$((FINDINGS + 1)); }
bad()  { printf '   %sFAIL%s  %s\n' "$RED" "$RST" "$*"; FINDINGS=$((FINDINGS + 1)); }
indent() { sed "s/^/   $DIM/;s/\$/$RST/"; }

as_root=0
[ "$(id -u)" -eq 0 ] && as_root=1

# ---------------------------------------------------------------- firmware ---
hdr "Firmware / DMI"
if [ -r /sys/class/dmi/id/sys_vendor ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf '   %s\n' "$(cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name 2>/dev/null | paste -sd' ' -)"
    printf '   BIOS %s (%s)\n' \
      "$(cat /sys/class/dmi/id/bios_version 2>/dev/null)" \
      "$(cat /sys/class/dmi/id/bios_date 2>/dev/null)"
  fi
fi
if have fwupdmgr; then
  fu=$(fwupdmgr get-updates 2>/dev/null || true)
  case "$fu" in
    "") note "fwupdmgr returned nothing (offline or no LVFS device)" ;;
    *"No updates available"*|*"no available firmware updates"*|*"No available firmware updates"*) ok "no firmware updates advertised by fwupd" ;;
    *) warn "fwupdmgr may have firmware updates — run: fwupdmgr get-updates" ;;
  esac
else
  note "fwupd not installed — cannot check for UEFI/BIOS updates"
fi

# ------------------------------------------------------------- ACPI / BIOS ---
hdr "ACPI / BIOS firmware errors"
acpi=$(journalctl -k "${BOOTFLAG[@]}" --no-pager 2>/dev/null | grep -E 'ACPI (BIOS )?Error|Firmware Bug' || true)
if [ -z "$acpi" ]; then
  ok "none"
else
  warn "$(wc -l <<<"$acpi") ACPI firmware message(s) — usually a BIOS/DSTD bug, not failing hardware"
  grep -oE 'AE_[A-Z_]+' <<<"$acpi" | sort | uniq -c | sort -rn | head -4 | indent
  note "$(grep -oE '\[\\.?_[^]]+\]' <<<"$acpi" | sort -u | wc -l) distinct ACPI object(s) referenced"
  note "escalate only if a device is missing, or suspend/thermal/battery is broken"
fi

# ------------------------------------------------------- kernel err/warning ---
hdr "Kernel errors and warnings"
kw=$(journalctl -k "${BOOTFLAG[@]}" --no-pager -p warning 2>/dev/null || true)
if [ -z "$kw" ]; then
  ok "none"
else
  warn "$(wc -l <<<"$kw") kernel error/warning line(s)"
  grep -viE 'ACPI (BIOS )?Error|Firmware Bug' <<<"$kw" | sed 's/^[A-Z][a-z][a-z] [0-9]* [0-9:]* [^ ]* kernel: //' | sort | uniq -c | sort -rn | head -8 | indent
fi

# ------------------------------------------------------- hardware faults -----
hdr "Hardware faults (MCE / EDAC)"
if have ras-mc-ctl; then
  if [ "$as_root" -eq 1 ]; then
    s=$(ras-mc-ctl --summary 2>/dev/null || true)
    if grep -qE 'No (Memory|PCI|MC) errors' <<<"$s"; then ok "no machine-check errors logged"; else warn "machine-check events recorded"; indent <<<"$s"; fi
  else
    note "rasdaemon installed but needs root to read the EDAC counters"
  fi
else
  note "rasdaemon not installed — kernel MCEs reach the journal only (pacman -S rasdaemon)"
fi

# -------------------------------------------------------------------- SMART ---
hdr "Storage health (SMART)"
if have smartctl; then
  while read -r dev _; do
    [ -n "$dev" ] || continue
    if [ "$as_root" -eq 0 ]; then
      note "$dev — run 'sudo smartctl -H $dev' for the verdict"
      continue
    fi
    h=$(smartctl -H "$dev" 2>/dev/null | grep -iE 'overall-health|SMART Health' || true)
    if grep -qiE 'PASSED|OK' <<<"$h"; then ok "$dev — $h"; else warn "$dev — ${h:-no health line}"; fi
  done < <(smartctl --scan 2>/dev/null || true)
else
  note "smartmontools not installed"
fi

# -------------------------------------------------------------------- btrfs ---
if have btrfs && mount | grep -q 'type btrfs'; then
  hdr "btrfs device errors"
  out=$(btrfs device stats / 2>/dev/null || true)
  tot=$(awk '{s+=$NF} END{print s+0}' <<<"${out:-}")
  if [ "${tot:-0}" -gt 0 ]; then warn "btrfs reports non-zero error counters"; indent <<<"$out"; else ok "all btrfs error counters are zero"; fi
fi

# ---------------------------------------------------------------- systemd -----
hdr "Failed systemd units"
failed=$(systemctl --failed --no-legend --plain 2>/dev/null || true)
if [ -z "$failed" ]; then
  ok "none"
else
  warn "$(wc -l <<<"$failed") failed unit(s)"
  indent <<<"$failed"
  note "for each: systemctl status <unit> ; journalctl -u <unit> -b"
fi

# -------------------------------------------------------- recovery posture ----
hdr "Self-healing posture"
rtw=$(systemctl show -p RuntimeWatchdogUSec --value 2>/dev/null || echo 0)
rw=$(systemctl show -p RebootWatchdogUSec --value 2>/dev/null || echo 0)
panic=$(sysctl -n kernel.panic 2>/dev/null || echo '?')
case "$rtw" in 0|0s|0us|0ms|off|"") warn "systemd runtime watchdog is OFF (RuntimeWatchdogSec=0)" ;; *) ok "runtime watchdog armed: $rtw" ;; esac
[ "$panic" = "0" ] && warn "kernel.panic=0 — a panic leaves the box hung, no auto-reboot" || ok "auto-reboot after panic set to ${panic}s"
note "reboot watchdog: ${rw:-unset}"

# ---------------------------------------------------------------- boot ---------
if [ "$QUIET" -eq 0 ]; then
  hdr "Boot performance"
  if have systemd-analyze; then
    systemd-analyze 2>/dev/null | sed 's/^/   /' || true
    systemd-analyze blame 2>/dev/null | head -5 | indent
  else
    note "systemd-analyze unavailable"
  fi
fi

# ---------------------------------------------------------------- summary ------
printf '\n%s== %d finding(s)%s\n' "$BOLD" "$FINDINGS" "$RST"
[ "$FINDINGS" -gt 125 ] && exit 125 || exit "$FINDINGS"

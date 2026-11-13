#!/bin/sh
# Run every NixOS VM check and print a pass/fail summary.
set -eu

SYSTEM=${1:-x86_64-linux}
SCRIPT_DIR=$(CDPATH='' cd -P -- "$(dirname -- "$0")" && pwd -P)
FLAKE_DIR=$(CDPATH='' cd -P -- "$SCRIPT_DIR/../../nixos" && pwd -P)

TESTS="aide-integrity apparmor-active apparmor-not-aggressive
boot-health boot-time clamav-scanner
dns-resolution doas-privilege firewall-active
kernel-hardening kernel-modules-blacklist locale-timezone
package-smoke security-posture
user-isolation"

pass=0
fail=0
for t in $TESTS; do
    printf '%-30s' "$t"
    if nix build "$FLAKE_DIR#checks.$SYSTEM.$t" --no-link >/dev/null 2>&1; then
        printf 'ok\n'
        pass=$((pass + 1))
    else
        printf 'FAIL\n'
        fail=$((fail + 1))
    fi
done

printf '\n%d passed, %d failed, %d total\n' "$pass" "$fail" "$((pass + fail))"
exit "$fail"

#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:-x86_64-linux}"
TESTS=(
  aide-integrity apparmor-active apparmor-not-aggressive
  boot-health boot-time clamav-scanner
  dns-resolution doas-privilege firewall-active
  kernel-hardening kernel-modules-blacklist locale-timezone
  package-smoke security-posture
  user-isolation
)

pass=0 fail=0
for t in "${TESTS[@]}"; do
  printf "%-30s" "$t"
  if nix build ".#checks.$SYSTEM.$t" --no-link 2>/dev/null; then
    echo "✓"; ((pass++))
  else
    echo "✗"; ((fail++))
  fi
done

echo ""
echo "$pass passed, $fail failed, $((pass+fail)) total"
exit $fail

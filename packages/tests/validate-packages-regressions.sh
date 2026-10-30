#!/bin/bash
# Fast policy fixtures; no archives, makepkg calls, network or installation.
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/tests/package-policy.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
expect_failure() {
  local message=$1
  shift
  if "$@" >"$work/result.log" 2>&1; then
    echo "policy accepted invalid fixture: $message" >&2
    exit 1
  fi
  grep -Fq "$message" "$work/result.log"
}

metadata=$'depend = acl\ndepend = udev\ndepend = libseat'
check_multiseat_dependencies "$metadata"
for dependency in acl udev libseat; do
  changed=$(grep -Fvx "depend = $dependency" <<<"$metadata")
  expect_failure "multiseat is missing runtime dependency: $dependency" \
    check_multiseat_dependencies "$changed"
done

account='u sddm - "Simple Desktop Display Manager" /var/lib/sddm'
check_greeter_account "$account"
expect_failure 'sddm account definition is missing' check_greeter_account ''
expect_failure 'sddm must not have static video group membership' \
  check_greeter_account "$account"$'\nm\tsddm\tvideo'

check_source_policy $'source = libseat::git+https://example.invalid/repo.git\nsha256sums = SKIP' fixture
check_source_policy 'source = user-service-manager' fixture
expect_failure 'unexpected source checksum' \
  check_source_policy $'source = https://example.invalid/source\nsha256sums = forbidden' fixture
for url in git+ssh://git@example.invalid/repo.git git+http://example.invalid/repo.git git+git://example.invalid/repo.git; do
  expect_failure 'remote build source must use HTTPS' \
    check_source_policy "source = alias::$url" fixture
done

echo 'package-policy regressions passed (9 negative fixtures)'

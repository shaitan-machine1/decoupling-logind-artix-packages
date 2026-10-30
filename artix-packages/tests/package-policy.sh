# Shared policy checks for real package metadata and small regression fixtures.
check_source_policy() {
  local metadata=$1 recipe=$2
  if ! awk '$1 ~ /sums$/ && $3 != "SKIP" { exit 1 }' <<<"$metadata"; then
    echo "unexpected source checksum in $recipe" >&2
    return 1
  fi
  if ! awk '$1 ~ /^source(_.*)?$/ {
    source = $3; sub(/^.*::/, "", source)
    if (source ~ /:\/\// && source !~ /^(git\+)?https:\/\//) exit 1
  }' <<<"$metadata"; then
    echo "remote build source must use HTTPS in $recipe" >&2
    return 1
  fi
}

check_multiseat_dependencies() {
  local metadata=$1 dependency
  for dependency in acl udev libseat; do
    if ! grep -Fqx "depend = $dependency" <<<"$metadata"; then
      echo "multiseat is missing runtime dependency: $dependency" >&2
      return 1
    fi
  done
}

check_greeter_account() {
  local sysusers=$1
  if ! grep -Eq '^[[:space:]]*u[[:space:]]+sddm[[:space:]]' <<<"$sysusers"; then
    echo 'sddm account definition is missing' >&2
    return 1
  fi
  if grep -Eq '^[[:space:]]*m[[:space:]]+sddm[[:space:]]+video([[:space:]]|$)' <<<"$sysusers"; then
    echo 'sddm must not have static video group membership' >&2
    return 1
  fi
}

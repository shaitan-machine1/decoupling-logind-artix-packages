#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package() {
  local dir=$1 name=$2
  (cd "$root/$dir" && makepkg --packagelist) | grep "/${name}-" | grep -v -- '-debug-' | head -1
}
info() { bsdtar -xOf "$1" .PKGINFO; }
has() { info "$1" | grep -Fqx "$2"; }
lacks() { ! info "$1" | grep -Eq "$2"; }
files_lack() { ! bsdtar -tf "$1" | grep -Eq "$2"; }
files_have() {
  local archive=$1 path
  shift
  for path in "$@"; do
    bsdtar -tf "$archive" | grep -Fqx "$path"
  done
}

init=$(package init-logind-none init-logind-none)
libseat=$(package libseat libseat)
multi=$(package multiseat multiseat)
session=$(package sessiond sessiond)
manager=$(package s6-user-service-manager s6-user-service-manager)
dbus_user=$(package dbus-s6-user dbus-s6-user)
pipewire_user=$(package pipewire-s6-user pipewire-s6-user)
loginctl=$(package loginctl loginctl)
sddm=$(package sddm sddm)
for archive in "$init" "$libseat" "$multi" "$session" "$manager" \
               "$dbus_user" "$pipewire_user" "$loginctl" "$sddm"; do
  test -f "$archive"
done

has "$init" 'provides = init-logind'
has "$init" 'provides = elogind'
has "$init" 'conflict = init-logind'
has "$init" 'conflict = elogind-s6'
lacks "$init" '^(depend|replace) = '
files_lack "$init" '^usr/(bin|lib)/'

info "$libseat" | grep -Eq '^provides = libseat\.so(=|$)'
has "$libseat" 'provides = seatd=0.9.3'
has "$libseat" 'conflict = seatd'
lacks "$libseat" '^depend = (seatd|multiseat|sessiond|sddm)$'
files_have "$libseat" usr/lib/libseat.so usr/lib/libseat.so.1 usr/include/libseat.h
files_lack "$libseat" '^usr/bin/seatd$'

has "$multi" 'depend = libseat'
lacks "$multi" '^(provides|conflict|replace) = '
lacks "$multi" '^depend = (seatd|seat-udev|s6|scoped|sessiond|aclad|sddm)$'
files_have "$multi" \
  usr/bin/multiseatd \
  usr/bin/seat-launch \
  usr/lib/udev/rules.d/70-uaccess.rules \
  usr/lib/udev/rules.d/71-seat.rules \
  usr/lib/udev/rules.d/73-seat-late.rules \
  usr/share/dbus-1/system.d/org.decoupling.multiseatd1.conf
files_lack "$multi" 'usr/bin/seatd$|dist/s6|multiseatctl|seatctl'

has "$session" 'provides = session-manager'
has "$session" 'depend = user-service-manager'
lacks "$session" '^depend = (aclad|multiseat|seat-udev|scoped|s6|s6-base|s6-rc|coreutils)$'
files_lack "$session" 'sessionctl|etc/s6/user|usr/libexec/user-service-manager'
files_have "$session" \
  etc/sessiond.conf \
  usr/bin/sessiond \
  usr/lib/security/pam_sessiond.so \
  usr/libexec/sessiond/sessiond-user-launcher

has "$manager" 'provides = user-service-manager'
lacks "$manager" '^depend = sessiond$'
files_have "$manager" usr/libexec/user-service-manager
files_lack "$manager" 'flag-recommended'
files_lack "$dbus_user" 'contents.d/default|flag-recommended'
files_lack "$pipewire_user" 'contents.d/default|flag-recommended'
for service in pipewire pipewire-pulse wireplumber pipewire-user; do
  bsdtar -tf "$pipewire_user" | grep -q "etc/s6/user/sv/$service/"
done

lacks "$loginctl" '^depend = (aclad|libseat|multiseat|scoped|seat-udev|sessiond)$'
info "$loginctl" | grep -q '^optdepend = multiseat:'
info "$loginctl" | grep -q '^optdepend = sessiond:'
lacks "$loginctl" '^optdepend = (aclad|scoped|seat-udev):'
files_lack "$loginctl" 'multiseatctl|seatctl|sessionctl|scopectl|acladctl'
mode=$(bsdtar -tvf "$loginctl" | awk '$NF == "usr/bin/loginctl" {print $1}')
test "$mode" = '-rwxr-xr-x'

has "$sddm" 'depend = pam_rundir'
lacks "$sddm" '^depend = (aclad|elogind|init-logind|libseat|multiseat|scoped|seatd|sessiond)$'
has "$sddm" 'optdepend = elogind: provide the logind seat backend'
has "$sddm" 'optdepend = multiseat: provide the multiseatd backend'
files_lack "$sddm" 'etc/s6|10-multiseatd.conf|10-decoupling.conf|pam_sessiond|pam_aclad'

for name in sessiond-s6 multiseat-s6 sddm-s6; do
  archive=$(package s6-services "$name")
  test -f "$archive"
  case $name in
    sessiond-s6)
      lacks "$archive" '^depend = (aclad|multiseat|sddm|scoped|scoped-s6)$'
      files_have "$archive" etc/s6/sv/sessiond-srv/dependencies.d/mount-cgroups
      files_lack "$archive" 'scoped-|aclad-'
      ;;
    multiseat-s6)
      lacks "$archive" '^depend = (aclad|scoped|sddm|sessiond)$'
      files_have "$archive" etc/s6/sv/multiseatd-srv/run
      files_lack "$archive" 'multiseatd-scan|aclad-|scoped-'
      ;;
    sddm-s6)
      has "$archive" 'depend = multiseat-s6'
      lacks "$archive" '^depend = (aclad|aclad-s6|scoped|scoped-s6|sessiond|sessiond-s6)$'
      files_have "$archive" etc/sddm.conf.d/10-multiseatd.conf
      ! bsdtar -xOf "$archive" etc/sddm.conf.d/10-multiseatd.conf | grep -q SeatdSocketDir
      ;;
  esac
done

echo 'consolidated package metadata, ownership, and isolation checks passed'

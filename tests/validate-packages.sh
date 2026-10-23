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

init=$(package init-logind-none init-logind-none)
seat=$(package seat-udev seat-udev)
multi=$(package multiseat multiseat)
scoped=$(package scoped scoped)
session=$(package sessiond sessiond)
aclad=$(package aclad aclad)
manager=$(package s6-user-service-manager s6-user-service-manager)
dbus_user=$(package dbus-s6-user dbus-s6-user)
pipewire_user=$(package pipewire-s6-user pipewire-s6-user)
loginctl=$(package loginctl loginctl)
sddm=$(package sddm sddm)
for archive in "$init" "$seat" "$multi" "$scoped" "$session" "$aclad" "$manager" "$dbus_user" "$pipewire_user" "$loginctl" "$sddm"; do test -f "$archive"; done

has "$init" 'provides = init-logind'
has "$init" 'provides = elogind'
has "$init" 'conflict = init-logind'
has "$init" 'conflict = elogind-s6'
lacks "$init" '^(depend|replace) = '
files_lack "$init" '^usr/(bin|lib)/'

has "$seat" 'depend = udev'
lacks "$seat" '^(provides|conflict|replace) = '
files_lack "$seat" 'usr/bin|seatctl'
for rule in usr/lib/udev/rules.d/71-seat.rules usr/lib/udev/rules.d/73-seat-late.rules; do bsdtar -tf "$seat" | grep -Fqx "$rule"; done

has "$multi" 'provides = seatd=0.9.3'
info "$multi" | grep -Eq '^provides = libseat\.so(=1-64)?$'
has "$multi" 'conflict = seatd'
has "$multi" 'conflict = libseat'
lacks "$multi" '^replace = '
lacks "$multi" '^depend = (aclad|scoped|sessiond|sddm|s6-base|s6-rc)$'
for path in usr/bin/multiseatd usr/bin/seat-launch usr/bin/seatd usr/include/libseat.h usr/lib/libseat.so usr/lib/libseat.so.1; do bsdtar -tf "$multi" | grep -Fqx "$path"; done
files_lack "$multi" 'multiseatctl|seatctl'

lacks "$scoped" '^depend = (aclad|multiseat|sessiond|sddm|seat-udev)$'
files_lack "$scoped" 'scopectl'
has "$session" 'provides = session-manager'
has "$session" 'depend = scoped'
has "$session" 'depend = user-service-manager'
lacks "$session" '^depend = (aclad|multiseat|seat-udev|s6|s6-base|s6-rc|coreutils)$'
files_lack "$session" 'sessionctl|etc/s6/user|usr/libexec/user-service-manager'
for path in etc/sessiond.conf usr/bin/sessiond usr/lib/security/pam_sessiond.so usr/libexec/sessiond/sessiond-user-launcher; do bsdtar -tf "$session" | grep -Fqx "$path"; done
has "$aclad" 'optdepend = sessiond: reconcile session inventory and observe session closure'
lacks "$aclad" '^depend = (sessiond|scoped|multiseat|sddm)$'
files_lack "$aclad" 'acladctl'

has "$manager" 'provides = user-service-manager'
lacks "$manager" '^depend = sessiond$'
bsdtar -tf "$manager" | grep -Fqx 'usr/libexec/user-service-manager'
files_lack "$manager" 'flag-recommended'
files_lack "$dbus_user" 'contents.d/default|flag-recommended'
files_lack "$pipewire_user" 'contents.d/default|flag-recommended'
for service in pipewire pipewire-pulse wireplumber pipewire-user; do bsdtar -tf "$pipewire_user" | grep -q "etc/s6/user/sv/$service/"; done

has "$loginctl" 'conflict = elogind'
lacks "$loginctl" '^depend = (aclad|multiseat|scoped|seat-udev|sessiond)$'
for component in aclad multiseat scoped seat-udev sessiond; do info "$loginctl" | grep -q "^optdepend = $component:"; done
files_lack "$loginctl" 'multiseatctl|seatctl|sessionctl|scopectl|acladctl'
mode=$(bsdtar -tvf "$loginctl" | awk '$NF == "usr/bin/loginctl" {print $1}')
test "$mode" = '-rwxr-xr-x'

has "$sddm" 'depend = pam_rundir'
lacks "$sddm" '^depend = (aclad|elogind|init-logind|multiseat|scoped|seatd|sessiond)$'
has "$sddm" 'optdepend = elogind: provide the logind seat backend'
has "$sddm" 'optdepend = multiseat: provide the multiseatd backend and bundled seatd/libseat'
files_lack "$sddm" 'etc/s6|10-multiseatd.conf|10-decoupling.conf|pam_sessiond|pam_aclad'

for name in scoped-s6 sessiond-s6 aclad-s6 multiseat-s6 sddm-s6; do
  archive=$(package s6-services "$name")
  test -f "$archive"
  case $name in
    scoped-s6) lacks "$archive" '^depend = (aclad|multiseat|sddm|sessiond)$' ;;
    sessiond-s6) lacks "$archive" '^depend = (aclad|multiseat|sddm)$' ;;
    aclad-s6) lacks "$archive" '^depend = (multiseat|scoped|sddm|sessiond|sessiond-s6)$' ;;
    multiseat-s6) lacks "$archive" '^depend = (aclad|scoped|sddm|sessiond)$' ;;
    sddm-s6)
      has "$archive" 'depend = multiseat-s6'
      lacks "$archive" '^depend = (aclad|aclad-s6|scoped|scoped-s6|sessiond|sessiond-s6)$'
      bsdtar -tf "$archive" | grep -Fqx 'etc/sddm.conf.d/10-multiseatd.conf'
      ;;
  esac
done

echo 'modular package metadata, ownership, and isolation checks passed'

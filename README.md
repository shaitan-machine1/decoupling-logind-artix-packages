# decoupling-logind Artix packages

A simple PKGBUILD monorepo for the Phase 1 decoupled login stack.

Packages:

- `scoped`
- `seat-udev`
- `multiseat`
- `sessiond`
- `aclad`
- the patched `seatd`/libseat fork, which serves one configured seat per
  process
- the patched Wayland-only `sddm` fork, which also owns its configuration,
  PAM files and `sddm-srv`/`sddm-log` services
- `decoupling-logind-pam`, the single common PAM session fragment
- `decoupling-logind-s6`, which supplies the combined s6-rc service graph and
  provides Artix's `init-logind`, `logind`, and `elogind` dependencies without
  installing the elogind daemon or its D-Bus activation file

The source packages are pinned to exact Git commits. The repositories are
private, so builds require GitHub SSH access. Build each directory with
`makepkg`; install the resulting packages together before restoring Artix's
`base` metapackage.

The service graph is:

```text
mount-cgroups + dbus-srv -> scoped-srv -> sessiond-srv -> aclad-srv
udevadm + dbus-srv -> multiseatd-scan-srv -> multiseatd-srv
all four ------------------------------------> sddm-srv
```

`multiseatd-scan-srv` is the nested `s6-svscan` on `/run/multiseatd/scandir`.
multiseatd generates one immutable seatd service per udev seat under
`/run/multiseatd/services/<seat>-<hash>` and attaches it to that scan
directory, so each seat gets its own supervised `seatd` process, its own
root-only socket and its own static device allowlist. Topology changes are
applied only by `loginctl seat refresh`, which may terminate the graphical
sessions of the affected seats.

After package installation, synchronize and apply the Artix s6 repository:

```sh
sudo s6 repository sync
sudo s6 set enable logind sddm-srv
sudo s6 set apply
```

## Virtual terminals and udev rules

`sddm` is built with `-DSDDM_INITIAL_VT=7` because Artix runs gettys on
tty1-tty6 and tty12, and SDDM cannot tell a used VT from a free one without
logind (`Display::isTtyInUse()` asks logind and answers "free" when it is
absent). Sessions are unaffected: they always allocate a fresh VT through
`VT_OPENQRY`.

`seat-udev` installs `71-seat.rules`/`73-seat-late.rules` and `aclad` installs
`70-uaccess.rules`. These replace the files elogind used to provide. Without
them no device carries a `seat`, `master-of-seat` or `uaccess` tag, so
multiseatd publishes no seat, creates no socket, and nothing graphical can
start. Installing the packages reloads udev's rules; devices that already
exist need `udevadm trigger` or a reboot.

## PAM

`decoupling-logind-pam` owns `/etc/pam.d/decoupling-logind-session`, which
runs `pam_env`, then `pam_sessiond`, then `pam_aclad`. Include it exactly once
per login path by adding `session include decoupling-logind-session` to
`/etc/pam.d/system-login`; the SDDM greeter includes it directly because it
does not go through `system-login`. See
`/usr/share/doc/decoupling-logind-pam/README.md`.

The SDDM PAM files deliberately contain neither `pam_elogind` nor
`pam_systemd`. `libelogind` may remain installed for unrelated dynamically
linked programs. The service package conflicts with and replaces `elogind`,
while advertising compatibility provides for Artix packages such as polkit
that carry a hard package dependency but are not used for session ownership.

Do not reboot a machine on which `/sbin/init` is missing. Reinstall its selected
init package (for this deployment, `s6-linux-init`) and verify the symlink
before rebooting.

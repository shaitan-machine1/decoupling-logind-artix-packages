# decoupling-logind Artix packages

A simple PKGBUILD monorepo for the Phase 1 decoupled login stack.

Packages:

- `scoped`
- `seat-udev`
- `multiseat`
- `sessiond`
- `aclad`
- the patched `seatd`/libseat fork
- the patched Wayland-only `sddm` fork
- `decoupling-logind-s6`, which supplies the combined s6-rc service graph and
  provides Artix's `init-logind` virtual dependency without elogind

The source packages are pinned to exact Git commits. The repositories are
private, so builds require GitHub SSH access. Build each directory with
`makepkg`; install the resulting packages together before restoring Artix's
`base` metapackage.

The service graph is:

```text
mount-cgroups + dbus-srv -> scoped-srv -> sessiond-srv -> aclad-srv
udevadm + dbus-srv ---------------------> multiseatd-srv
all four --------------------------------> sddm-srv
```

After package installation, synchronize and apply the Artix s6 repository:

```sh
sudo s6 repository sync
sudo s6 set enable logind sddm-srv
sudo s6 set apply
```

The SDDM PAM files deliberately contain neither `pam_elogind` nor
`pam_systemd`. `libelogind` may remain installed for unrelated dynamically
linked programs, but `elogind` and `elogind-s6` are not required.

Do not reboot a machine on which `/sbin/init` is missing. Reinstall its selected
init package (for this deployment, `s6-linux-init`) and verify the symlink
before rebooting.

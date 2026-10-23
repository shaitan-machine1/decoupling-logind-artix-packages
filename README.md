# decoupling-logind Artix packages

PKGBUILDs for independently installable parts of the decoupled login stack.
Private source repositories are pinned to exact commits and fetched over SSH,
so builds require the normal user's GitHub SSH access.

Current package outputs are:

- `init-logind-none`: empty `init-logind`/`elogind` compatibility provider;
- `seat-udev`: udev seat integration policy;
- `multiseat`: multiseatd, patched seatd, and patched libseat;
- `scoped`, `sessiond`, and `aclad`: independent daemons and their owned PAM
  modules where applicable;
- `scoped-s6`, `sessiond-s6`, `aclad-s6`, `multiseat-s6`, and `sddm-s6`, all
  produced by the `s6-services` split PKGBUILD;
- `s6-user-service-manager`: replaceable sessiond user-manager implementation;
- `dbus-s6-user` and `pipewire-s6-user`: optional, disabled user services;
- `loginctl`: unified administration and explicit PAM activation;
- `sddm`: the patched display-manager application.

There is no full-suite metapackage, combined service graph, separate final
seatd package, or common PAM-fragment package.

Build each selected directory as the normal user:

```sh
cd PACKAGE_DIRECTORY
makepkg --cleanbuild
```

Never remove Artix `base`. Before installation or reboot, verify:

```sh
test -x /usr/bin/s6-init
test "$(readlink -f /sbin/init)" = /usr/bin/s6-init
pacman -Qo /usr/bin/init
```

## Service packages

The split service packages preserve only real ordering:

```text
mount-cgroups + dbus-srv -> scoped-srv
dbus-srv + scoped-srv    -> sessiond-srv
dbus-srv + udevadm       -> aclad-srv
udevadm + dbus-srv        -> multiseatd-scan-srv -> multiseatd-srv
multiseatd-srv            -> sddm-srv
```

Installing one output does not install unrelated daemons. After installing a
selected profile, synchronize the Artix s6 repository and enable only that
profile's services.

Multiseatd generates one immutable seatd service per udev seat under
`/run/multiseatd/services`. Topology changes are applied only by
`loginctl seat refresh`, which previews changes and warns that refresh may
terminate graphical sessions.

## User services

The generic manager compiles disposable state below `$XDG_RUNTIME_DIR/s6` from
complete-directory overrides in this precedence order:

```text
$XDG_CONFIG_HOME/s6/sv
/etc/s6/user/adminsv
/etc/s6/user/sv
```

Optional D-Bus and PipeWire definitions are available but are not selected by
the packaged empty `default` bundle. Use raw s6-rc commands against
`$XDG_RUNTIME_DIR/s6/live` or create a home-owned `default` bundle.

## PAM administration

No package owns a common PAM include. `loginctl` owns `/etc/loginctl.conf` and
can inspect, activate, or deactivate its exact marked block in the configured
distribution PAM file:

```sh
loginctl pam status
sudo loginctl pam activate
sudo loginctl pam deactivate
```

`loginctl` never invokes `sudo`; mutation requires an already-root caller.
Sessiond and aclad remain fail-open optional PAM participants. Distribution
policy remains responsible for `pam_env` and any derivation of
`DBUS_SESSION_BUS_ADDRESS` from `XDG_RUNTIME_DIR`.

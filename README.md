# decoupling-logind Artix packages

PKGBUILDs for independently installable parts of the decoupled login stack.
Source repositories are pinned to exact commits and fetched anonymously over
HTTPS. Builds need no GitHub credentials or SSH key. The public Git dependencies
of `loginctl` also use HTTPS and are fetched during `prepare()`.

Current package outputs are:

- `init-logind-none`: empty `init-logind`/`elogind` compatibility provider;
- `libseat`: patched C libseat from the seatd fork, library only;
- `multiseat`: `multiseatd`, `seat-launch`, the udev seat/access policy and the
  root-only D-Bus policy;
- `sessiond`: session lifecycle daemon, `pam_sessiond.so` and the user-manager
  launcher;
- `sessiond-s6`, `multiseat-s6`, and `sddm-s6`, all produced by the
  `s6-services` split PKGBUILD;
- `s6-user-service-manager`: replaceable sessiond user-manager implementation;
- `dbus-s6-user` and `pipewire-s6-user`: optional, disabled user services;
- `loginctl`: unified administration and explicit PAM activation;
- `sddm`: the patched display-manager application.

There is no full-suite metapackage, combined service graph, ACL daemon, scope
daemon, separate seat-udev package, or common PAM-fragment package.

`libseat` provides `seatd` and `libseat.so` and conflicts with the distribution
`seatd` package because both own the library. `multiseat` depends on `libseat`
instead of providing or conflicting with either. There is no standalone
`seatd` server: clients receive an inherited server descriptor from
`multiseatd` over D-Bus.

Build each selected directory as the normal user:

```sh
cd PACKAGE_DIRECTORY
makepkg --cleanbuild
```

Source checksums are intentionally skipped for these build-only recipes,
including local source files. Exact Git revisions remain pinned.

Never remove Artix `base`. Before installation or reboot, verify:

```sh
test -x /usr/bin/s6-init
test "$(readlink -f /sbin/init)" = /usr/bin/s6-init
pacman -Qo /usr/bin/init
```

## Device policy

`multiseat` owns the complete ordered udev rule set:

```text
70-uaccess.rules    tag devices whose access follows the active session
71-seat.rules       make uaccess and seat devices seat members
73-seat-late.rules  resolve ID_SEAT and seat tags
```

`multiseat` directly depends on `acl` and `udev`, as well as the libudev
client library: it needs both libacl and a running device manager, independent
of the selected init system.

`multiseatd` is the sole direct-access ACL owner. Brokered DRM/evdev/hidraw
devices are available only through its embedded seatd actors; remaining
`uaccess` devices get UID ACLs from live client leases. Do not install or run
`aclad` alongside it.

## Service packages

The split service packages preserve only real ordering:

```text
dbus-srv + mount-cgroups -> sessiond-srv
dbus-srv + udevadm       -> multiseatd-srv
multiseatd-srv           -> sddm-srv
```

Installing one output does not install unrelated daemons. After installing a
selected profile, synchronize the Artix s6 repository and enable only that
profile's services.

`multiseatd` discovers seats continuously from udev and runs one in-process
seatd actor per seat. There are no per-seat services, no seat allowlist file
and no `seat refresh` command. Seat clients are created and revoked by root
over D-Bus, and `loginctl seat client list|revoke` is the administrative
interface.

The SDDM account is not added to `video`: its compositor receives brokered
device access through its seat client instead of permanent cross-seat group
permissions. The daemon's default singleton lock needs no service override.

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
Sessiond is the only fail-open optional PAM participant. Activation also
recognises and replaces the exact historical block that named `pam_aclad.so`.
Distribution policy remains responsible for `pam_env` and any derivation of
`DBUS_SESSION_BUS_ADDRESS` from `XDG_RUNTIME_DIR`.

## Build-only validation

After building all recipe outputs, run as the normal user:

```sh
bash tests/validate-packages.sh
bash tests/validate-packages-regressions.sh
# After editing recipes, also verify regenerated metadata (slower):
bash tests/validate-packages.sh --check-recipes
```

Routine validation reads `.SRCINFO` and caches each archive's metadata and file
list, without running makepkg. Archives are expected beside their recipes;
set `PKGDEST` explicitly if they are stored elsewhere. `--check-recipes` also
runs makepkg once per recipe to compare freshly generated metadata.

Validation checks HTTPS-only remote sources, skipped source checksums, archive
contents, required runtime dependencies and component isolation. Fast negative
policy fixtures need no built archives and reject missing ACL/udev dependencies,
static greeter `video` membership, source checksums and non-HTTPS remote URLs.
No package is installed and no service is started. These checks are not
clean-chroot or hardware acceptance.

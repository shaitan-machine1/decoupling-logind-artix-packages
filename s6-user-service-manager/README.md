# s6-user-service-manager

`/usr/libexec/user-service-manager --ready-fd FD` starts one foreground s6-rc
manager for the invoking user. It writes one newline after the live database
and the `default` bundle are up, then stays alive until its scanner exits or it
receives `SIGTERM`. The readiness byte is opaque to sessiond.

Service sources are selected by complete-directory replacement in this order:

1. `/etc/s6/user/sv` (package definitions);
2. `/etc/s6/user/adminsv` (administrator overrides);
3. `${XDG_CONFIG_HOME:-$HOME/.config}/s6/sv` (user overrides).

The compiled database, scanner, effective source, and live state are disposable
and live below `$XDG_RUNTIME_DIR/s6`. There is no s6-frontend repository or
persistent compiled state.

Packages install available services but do not add them to `default`. To make a
service persistent, create a complete user-owned `default` bundle and add an
empty file named after each desired service under its `contents.d` directory.
The selection takes effect when the manager next starts.

Use raw s6-rc commands for live changes:

```sh
s6-rc -l "$XDG_RUNTIME_DIR/s6/live" -u change SERVICE
s6-rc -l "$XDG_RUNTIME_DIR/s6/live" -d change SERVICE
```

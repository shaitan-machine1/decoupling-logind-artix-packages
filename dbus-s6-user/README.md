# dbus-s6-user

This package installs the optional `dbus` user service. Installation does not
add it to the user's `default` bundle.

Start it for the current manager lifetime with:

```sh
s6-rc -l "$XDG_RUNTIME_DIR/s6/live" -u change dbus
```

The service reports readiness only after a method call succeeds against the
new `$XDG_RUNTIME_DIR/bus` socket. Add `dbus` to a user-owned
`$XDG_CONFIG_HOME/s6/sv/default/contents.d` to select it on future logins.

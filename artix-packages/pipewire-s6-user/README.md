# pipewire-s6-user

This package installs the optional `pipewire`, `pipewire-pulse`, and
`wireplumber` longruns and the `pipewire-user` bundle. Installation does not
add any of them to the user's `default` bundle.

Start the complete graph for the current manager lifetime with:

```sh
s6-rc -l "$XDG_RUNTIME_DIR/s6/live" -u change pipewire-user
```

`pipewire-pulse` and `wireplumber` depend on `pipewire`. PipeWire readiness is
checked with `pw-cli`, and PulseAudio compatibility readiness with `pactl`.
WirePlumber has no stable native readiness channel in this package and is
therefore considered up when supervision successfully starts its process.

Add `pipewire-user` to a user-owned
`$XDG_CONFIG_HOME/s6/sv/default/contents.d` to select the bundle on future
logins.

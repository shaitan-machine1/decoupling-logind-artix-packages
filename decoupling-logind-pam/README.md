# decoupling-logind-pam

Ships `/etc/pam.d/decoupling-logind-session`, the single place where the
decoupled login stack is wired into PAM:

```text
session    required     pam_env.so
session    required     pam_sessiond.so timeout=30s
session    required     pam_aclad.so timeout=30s
```

`pam_sessiond` creates the session and its scope; `pam_aclad` then grants the
seat's device ACLs to that session's user, so it must come second.

## Enabling it

The fragment is included exactly once per login path. Every Artix text login,
`su -l`, and the SDDM user session reach PAM through `system-login`, so add
one line to `/etc/pam.d/system-login`, after its own `session` includes:

```text
session    include      decoupling-logind-session
```

`pambase` owns `system-login`, so the edit survives upgrades as a local
change and pacman reports a `.pacnew` when upstream changes the file.

The SDDM greeter does not go through `system-login`; the `sddm` package's
`/etc/pam.d/sddm-greeter` includes the fragment directly.

Do not add `pam_sessiond` or `pam_aclad` to any other file: a second include
would open a second session for the same login.

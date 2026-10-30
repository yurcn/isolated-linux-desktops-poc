# One TTY, One Environment: Isolated Linux Desktops with Minimal Privileges


Proof-of-Concept: A lightweight approach to desktop isolation on Linux Xorg: **one desktop per environment, each running in its own Podman container on a dedicated Linux TTY.**

The idea is simple:

- Minimal XFCE desktop and only the required applications.
- Separate user, PID, mount, network, UTS, and cgroup namespaces.
- Dropped Linux capabilities, `no-new-privileges`, and AppArmor confinement.
- Dedicated filesystem, home directory, and controlled network access.
- Host-side Xorg with per-display X11 authentication.
- Native switching between environments using `Ctrl+Alt+F7`, `Ctrl+Alt+F8`, etc.

**Architecture:**

```text
         Linux Host
    (Hardened Linux Kernel)
              |
    +---------+---------+
    |         |         |
   tty7      tty8      tty9
    |         |         |
  Xorg :7  Xorg :8   Xorg :9
    |         |         |
  Podman    Podman    Podman
    |         |         |
   XFCE      XFCE      XFCE
    |         |         |
   Work      Dev     Untrusted
    |         |         |
  netns A   netns B   netns C
  home A    home B    home C
```

Login chain after tty8:
```text
getty@tty8
   v
console login
   v
~/.profile
   v
startx
   v
host Xorg :8 / vt8
   v
~/.xinitrc-isolated
   v
sudo isolated-ui-run
   v
Podman
   v
container-entrypoint
   v
configure eth0
   v
UID/GID 1001
   v
dbus-run-session
   v
XFCE
```

Each container runs its own GUI applications with a minimal privilege set, while the host manages the physical display and TTY switching. No heavyweight virtual machines or full desktop installations are required.

The critical dependency is the **shared host kernel**. It must remain patched and hardened, with protections such as [Yama ptrace restrictions](https://docs.kernel.org/admin-guide/LSM/Yama.html), [kernel self-protection](https://docs.kernel.org/security/self-protection.html), and properly enforced AppArmor policies.

**This isn't VM-grade isolation**: the shared kernel and host-side X11 integration remain part of the trusted computing base. But it significantly reduces unnecessary access and limits the potential blast radius of compromised applications.

## Host preparation

### Bridge

```bash
sudo podman network create \
    --driver bridge \
    --interface-name virbr0 \
    --opt mode=unmanaged \
    --ipam-driver=none \
    --disable-dns \
    ui-virbr0
```

### `~/.xinitrc-isolated`

```sh
#!/bin/sh

export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

AUTH="${XDG_RUNTIME_DIR}/isolated-ui.Xauthority"
SOURCE_AUTH="${XAUTHORITY:-$HOME/.Xauthority}"

COOKIE="$(
    xauth -f "$SOURCE_AUTH" list |
    awk '$1 ~ /\/unix:8$/ { print $3; exit }'
)"

if [ -z "$COOKIE" ]; then
    echo "Cannot find X11 cookie for DISPLAY=$DISPLAY" >&2
    exit 1
fi

rm -f "$AUTH"
touch "$AUTH"
chmod 600 "$AUTH"
xauth -f "$AUTH" add \
    "isolated-ui/unix${DISPLAY}" \
    MIT-MAGIC-COOKIE-1 \
    "$COOKIE"
sudo -n /usr/local/sbin/isolated-ui-run
RC=$?

rm -f "$AUTH"

exit "$RC"
```

###  `~/.profile`:

```sh
if [ "$(tty 2>/dev/null)" = "/dev/tty8" ] \
    && [ -z "${DISPLAY:-}" ] \
    && [ -z "${WAYLAND_DISPLAY:-}" ]; then

    exec startx "$HOME/.xinitrc-isolated" -- \
        :8 vt8 -keeptty -nolisten tcp
fi
```

### build

```shell
podman build     -t local/isolated-xfce:24.04     -f Containerfile .

```

#!/bin/bash

set -euo pipefail

mount --make-rshared /

# Remount cgroup
umount /sys/fs/cgroup
mount -t cgroup2 -o rw,relatime,nsdelegate cgroup2 /sys/fs/cgroup

# fix permissions
if [[ -d ~rootless/.local/share/docker ]]; then
    chown rootless:rootless ~rootless/.local/share/docker
fi

if [[ -d /shared/run ]]; then
    chown rootless:rootless /shared/run
fi

exec /lib/systemd/systemd
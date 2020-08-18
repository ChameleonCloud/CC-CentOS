#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

### OS-specific installs

source /etc/os-release
dnf install -y epel-release
dnf install -y qemu-img python3-pip kpartx ufw
ufw --force enable

### Generic installs

pip install diskimage-builder

#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

YUM=yum
source /etc/os-release
if [[ $ID = 'centos' ]]; then
  if [[ $VERSION_ID = '8' ]]; then
    YUM=dnf
  fi
  ### OS-specific installs
  $YUM install -y epel-release
  $YUM install -y qemu-img python3-pip kpartx ufw
  ufw --force enable
else
  echo 'CnetOS is required, aborting.'
  exit 1
fi

### Generic installs

pip3 install diskimage-builder

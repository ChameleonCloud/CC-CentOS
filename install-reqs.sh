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
  # libgcrypt-1.8.3 (default with latest centos 8) is not compatible with the latest qemu-img
  # error message if not upgrading: qemu-img: Unable to initialize gcrypt
  $YUM upgrade -y libgcrypt
else
  echo 'CnetOS is required, aborting.'
  exit 1
fi

### Generic installs

pip3 install diskimage-builder

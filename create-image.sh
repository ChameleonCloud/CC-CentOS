#!/bin/bash
set -ex

export DISTRO_NAME=centos

VARIANT="base"
CUDA_VERSION=""
TMPDIR=`mktemp -d`
mkdir -p $TMPDIR/common

while [ "$1" != "" ]; do
    case $1 in
        -o | --output )         shift
                                OUTPUT_FILE=$1
                                ;;
        -n | --release )        shift
                                CENTOS_RELEASE=$1
                                ;;
        -v | --variant )        shift
                                VARIANT=$1
                                ;;
        -g | --region )         shift
                                REGION=$1
                                ;;
                                                       
        * )                     echo "Unrecognized option $1"
                                exit 1
    esac
    shift
done

export DIB_RELEASE=$CENTOS_RELEASE

case "$VARIANT" in
"base")
  IMAGE_NAME="CC-CentOS$DIB_RELEASE"
  EXTRA_ELEMENTS=""
  ;;
"gpu")
  IMAGE_NAME="CC-CentOS$DIB_RELEASE-CUDA"
  EXTRA_ELEMENTS="cc-cuda"
  ;;
"fpga")
  IMAGE_NAME="CC-CentOS$DIB_RELEASE-FPGA"
  if [ "$REGION" == "CHI@TACC" ]; then
  	EXTRA_ELEMENTS="cc-fpga-tacc"
  elif [ "$REGION" == "CHI@UC" ]; then
  	EXTRA_ELEMENTS="cc-fpga-uc"
  else
  	echo "Region is required for FPGA build"
  	exit 1
  fi
  ;;
*)
  echo "Must provide image type, one of: base, gpu"
  exit 1
esac

OUTPUT_FILE="$TMPDIR/common/$IMAGE_NAME.qcow2"

# Clone the required repositories for Heat contextualization elements
if [ ! -d tripleo-image-elements ]; then
  git clone https://git.openstack.org/openstack/tripleo-image-elements.git
fi
if [ ! -d heat-agents ]; then
  git clone https://git.openstack.org/openstack/heat-agents.git
fi

# Required by diskimage-builder to discover element collections
export ELEMENTS_PATH='elements:tripleo-image-elements/elements:heat-agents/'
export FS_TYPE='xfs'
export LIBGUESTFS_BACKEND='direct'
export DIB_INSTALLTYPE_pip_and_virtualenv=package

export DEPLOYMENT_BASE_ELEMENTS="heat-config heat-config-script"
export AGENT_ELEMENTS="os-collect-config os-refresh-config os-apply-config"

IFS=' ' read -ra ELEM <<< "$AGENT_ELEMENTS"
for i in "${ELEM[@]}"; do
  ELEM_FILE="tripleo-image-elements/elements/$i/install.d/$i-source-install/10-$i"
  PKG_FILE="tripleo-image-elements/elements/$i/package-installs.yaml"
  # virtualenv version >= 20.0.0 doesn't work with
  # https://github.com/openstack/tripleo-image-elements/blob/master/elements/os-apply-config/install.d/os-apply-config-source-install/10-os-apply-config#L6
  # virtualenv: error: too few arguments [--setuptools version]
  # update virtualenv
  sed -i 's/virtualenv --setuptools/python3 -m venv/' $ELEM_FILE
  # error in anyjson setup command: use_2to3 is invalid
  # setuptools>=58 breaks support for use_2to3
  sed -i "s/'setuptools>=1.0'/'setuptools>=1.0,<58.0'/" $ELEM_FILE
  sed -i "s/python-dev://" $PKG_FILE
done
# the following modifications are added for centos 7
# the default python version for centos7 is python2
# we can't set the default to python3, as yum doesn't work with python3
sed -i '10i $OS_COLLECT_CONFIG_VENV_DIR/bin/pip install --upgrade pip' tripleo-image-elements/elements/os-collect-config/install.d/os-collect-config-source-install/10-os-collect-config
sed -i 's/pip/pip3/' heat-agents/heat-config/install.d/heat-config-source-install/50-heat-config-soure
sed -i 's/\/usr\/bin\/env python/\/usr\/bin\/env python3/' heat-agents/heat-config/bin/heat-config-notify

ELEMENTS="vm block-device-efi dhcp-all-interfaces $AGENT_ELEMENTS $DEPLOYMENT_BASE_ELEMENTS"

if [ -f "$OUTPUT_FILE" ]; then
  echo "removing existing $OUTPUT_FILE"
  rm -f "$OUTPUT_FILE"
fi

disk-image-create centos chameleon-common $ELEMENTS $EXTRA_ELEMENTS -o $OUTPUT_FILE

if [ -f "$OUTPUT_FILE.qcow2" ]; then
  mv $OUTPUT_FILE.qcow2 $OUTPUT_FILE
fi

COMPRESSED_OUTPUT_FILE="$OUTPUT_FILE-compressed"
qemu-img convert $OUTPUT_FILE -O qcow2 -c $COMPRESSED_OUTPUT_FILE
echo "mv $COMPRESSED_OUTPUT_FILE $OUTPUT_FILE"
mv $COMPRESSED_OUTPUT_FILE $OUTPUT_FILE

if [ $? -eq 0 ]; then
  echo "Image built in $OUTPUT_FILE"
  if [ -f "$OUTPUT_FILE" ]; then
    echo "to add the image in glance run the following command:"
    echo "openstack image create --disk-format qcow2 --container-format bare --file $OUTPUT_FILE \"$IMAGE_NAME\""
  fi
else
  echo "Failed to build image in $OUTPUT_FOLDER"
  exit 1
fi

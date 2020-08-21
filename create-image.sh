#!/bin/bash
set -ex

export DISTRO_NAME=centos
#export DIB_PYTHON_VERSION=3

VARIANT="base"
CUDA_VERSION=""
TMPDIR=`mktemp -d`
mkdir -p $TMPDIR/common
OUTPUT_FILE="$TMPDIR/common/$IMAGE_NAME.qcow2"

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
        -c | --cuda )           shift
                                CUDA_VERSION=$1
                                ;;
        -g | --region )         shift
                                REGION=$1
                                ;;
        -k | --kvm )            shift
                                KVM=$1
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
  if [ "$CUDA_VERSION" == "" ]; then
    echo "You must specify a cuda version"
  	exit 1
  fi
  IMAGE_NAME="CC-CentOS$DIB_RELEASE-${CUDA_VERSION^^}"
  EXTRA_ELEMENTS="cc-$CUDA_VERSION"
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

# Clone the required repositories for Heat contextualization elements
if [ ! -d tripleo-image-elements ]; then
  git clone https://git.openstack.org/openstack/tripleo-image-elements.git
  # update virtualenv
  sed -i 's/virtualenv --setuptools/python3 -m venv/' tripleo-image-elements/elements/os-apply-config/install.d/os-apply-config-source-install/10-os-apply-config
  sed -i 's/virtualenv --setuptools/python3 -m venv/' tripleo-image-elements/elements/os-collect-config/install.d/os-collect-config-source-install/10-os-collect-config
  sed -i 's/virtualenv --setuptools/python3 -m venv/' tripleo-image-elements/elements/os-refresh-config/install.d/os-refresh-config-source-install/10-os-refresh-config
fi
if [ ! -d heat-agents ]; then
  git clone https://git.openstack.org/openstack/heat-agents.git
  # use python3
  sed -i 's/pip/pip3/' heat-agents/heat-config/install.d/heat-config-source-install/50-heat-config-soure
  sed -i 's/\/usr\/bin\/env python/\/usr\/bin\/env python3/' heat-agents/heat-config/bin/heat-config-notify
fi

# Forces diskimage-builder to install software using package rather than source
# See https://docs.openstack.org/diskimage-builder/latest/user_guide/install_types.html
export DIB_DEFAULT_INSTALLTYPE='source'
export DIB_INSTALLTYPE_os_apply_config='source'
export DIB_INSTALLTYPE_os_collect_config='source'
export DIB_INSTALLTYPE_os_refresh_config='source'
# Required by diskimage-builder to discover element collections
export ELEMENTS_PATH='elements:tripleo-image-elements/elements:heat-agents/'
export FS_TYPE='xfs'
export LIBGUESTFS_BACKEND='direct'

ELEMENTS="vm"

# Install and configure the os-collect-config agent to poll the metadata
# server (heat service or zaqar message queue and so on) for configuration
# changes to execute
export AGENT_ELEMENTS="os-collect-config os-refresh-config os-apply-config"

# heat-config installs an os-refresh-config script which will invoke the
# appropriate hook to perform configuration. The element heat-config-script
# installs a hook to perform configuration with shell scripts
export DEPLOYMENT_BASE_ELEMENTS="heat-config heat-config-script"

export DIB_INSTALLTYPE_pip_and_virtualenv=package

if [ -f "$OUTPUT_FILE" ]; then
  echo "removing existing $OUTPUT_FILE"
  rm -f "$OUTPUT_FILE"
fi

SITE_ELEMENTS=""
if $KVM; then
  echo "kvm image"
  SITE_ELEMENTS="kvm"
else
  echo "chi image"
  SITE_ELEMENTS="chi"
fi

disk-image-create centos chameleon-common $ELEMENTS $SITE_ELEMENTS $EXTRA_ELEMENTS $AGENT_ELEMENTS $DEPLOYMENT_BASE_ELEMENTS -o $OUTPUT_FILE --no-tmpfs --root-label img-rootfs

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
    echo "glance image-create --name \"$IMAGE_NAME\" --disk-format qcow2 --container-format bare --file $OUTPUT_FILE"
  fi
else
  echo "Failed to build image in $OUTPUT_FOLDER"
  exit 1
fi

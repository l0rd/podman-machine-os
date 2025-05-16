#!/bin/bash

set -exo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DEFAULT_PODMAN_BINARY="$( [ "Linux" = "$( uname -s )" ] && echo "podman-remote" || echo "podman"  )"
PODMAN_BINARY=${PODMAN_BINARY:-${DEFAULT_PODMAN_BINARY}}

provider2extension() {
  PROVIDER=$1
  case $PROVIDER in
    applehv)
      echo "raw"
      ;;
    libkrun)
      echo "raw"
      ;;
    hyperv)
      echo "vhdx"
      ;;
    qemu)
      echo "qcow2"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# normalizeArch converts arch names
# to one of the two arch used in the
# images names ("x86_64" and "aarch64")
normalizeArch() {
  ARCH=$1
  case $ARCH in
    arm64)
      echo "aarch64"
      ;;
    *)
      echo "$ARCH"
  esac
}

# normalizeProvider converts provider name
# to one of the provider names used in
# images names (for example the iamge named
# "applhv" is used for "libkrun" too)
normalizeProvider() {
  PROVIDER=$1
  case $PROVIDER in
    libkrun)
      echo "applehv"
      ;;
    *)
      echo "$PROVIDER"
  esac
}

defaultImageName() {
  ARCH=$( uname -m )
  PROVIDER="$( $PODMAN_BINARY info 2> /dev/null | grep provider | awk '{print $2}' || true )"
  EXT="$( provider2extension "$PROVIDER" )"
  PROVIDER="$( normalizeProvider "$PROVIDER" )"
  ARCH="$( normalizeArch "$ARCH" )"
  echo "podman-machine.${ARCH}.${PROVIDER}.${EXT}.zst"
}

download_image() {
  OUTPUT_DIR=$1
  FILE_NAME=$2
  if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir "$OUTPUT_DIR";
  fi
  CIRRUS_URL="https://api.cirrus-ci.com/v1/artifact/github/containers/podman-machine-os/image_build/image"
  curl -sSL -o "$OUTPUT_DIR/$FILE_NAME" "${CIRRUS_URL}/$FILE_NAME"
}

DEFAULT_IMAGES_FOLDER="$SCRIPT_DIR"/../outdir
DEFAULT_IMAGE_NAME="$( defaultImageName )"

if [ "$#" -eq 1 ]; then
  MACHINE_PATH=$1
elif [[ ${MACHINE_IMAGE_PATH} ]]; then
  MACHINE_PATH=${MACHINE_IMAGE_PATH}
elif [ -f "$DEFAULT_IMAGES_FOLDER"/"$DEFAULT_IMAGE_NAME" ]; then
  MACHINE_PATH="$DEFAULT_IMAGES_FOLDER"/"$DEFAULT_IMAGE_NAME"
else
    echo "No path to machine image provided. Downloading it from cirrus-ci.com."
    download_image "$DEFAULT_IMAGES_FOLDER" "$DEFAULT_IMAGE_NAME"
    MACHINE_PATH="$DEFAULT_IMAGES_FOLDER"/"$DEFAULT_IMAGE_NAME"
fi

echo "using images from ${MACHINE_PATH}"
export MACHINE_IMAGE_PATH=$MACHINE_PATH

ginkgo -v

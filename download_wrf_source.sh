#!/bin/bash
# Run on DTN: clone/checkout WRF v4.7.1 + submodules.
set -euo pipefail
INSTALL_DIR="${INSTALL_DIR:-/home/apps/chpc/earth/WRF-4.7.1-gcc}"
BUILD_DIR="${INSTALL_DIR}/build"
WRF_VERSION="${WRF_VERSION:-v4.7.1}"
WRF_SOURCE_URL="${WRF_SOURCE_URL:-https://github.com/wrf-model/WRF.git}"

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

if [[ -d WRF/.git ]]; then
    cd WRF
    git fetch --all --tags
    git checkout "${WRF_VERSION}"
    git submodule sync
    git submodule update --init --recursive
else
    git clone "${WRF_SOURCE_URL}" WRF
    cd WRF
    git checkout "${WRF_VERSION}"
    git submodule update --init --recursive
fi

echo "Ready: ${BUILD_DIR}/WRF  ($(git describe --tags --always))"
echo "Next (compute node): ./install_wrf_lengau_gcc.sh"

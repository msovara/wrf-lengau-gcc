#!/bin/bash
# Run on DTN: clone/checkout WPS (match WRF major.minor, e.g. v4.7.1 or master).
set -euo pipefail
INSTALL_DIR="${INSTALL_DIR:-/home/apps/chpc/earth/WRF-4.7.1-gcc}"
BUILD_DIR="${INSTALL_DIR}/build"
WPS_VERSION="${WPS_VERSION:-v4.7.1}"
WPS_SOURCE_URL="${WPS_SOURCE_URL:-https://github.com/wrf-model/WPS.git}"

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

if [[ -d WPS/.git ]]; then
    cd WPS
    git fetch --all --tags
    git checkout "${WPS_VERSION}" 2>/dev/null || git checkout master
else
    git clone "${WPS_SOURCE_URL}" WPS
    cd WPS
    git checkout "${WPS_VERSION}" 2>/dev/null || git checkout master
fi

echo "Ready: ${BUILD_DIR}/WPS ($(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD))"
echo "Next (compute node, after WRF): ./install_wps_lengau_gcc.sh"

#!/bin/bash
# ---------------------------------------------------------------------------
# WPS — Lengau — GNU gfortran + MPICH (after WRF built with install_wrf_lengau_gcc.sh)
# ---------------------------------------------------------------------------
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/home/apps/chpc/earth/WRF-4.7.1-gcc}"
BUILD_DIR="${INSTALL_DIR}/build"
WRF_DIR="${BUILD_DIR}/WRF"
WPS_DIR="${BUILD_DIR}/WPS"
NETCDF_MODULE="${NETCDF_MODULE:-chpc/earth/netcdf/4.7.4/gcc-8.3.0}"

# WPS master/current: Linux x86_64 gfortran — usually 1=serial, 2=serial_NO_GRIB2,
# 3=dmpar, 4=dmpar_NO_GRIB2. We want dmpar + GRIB2 → default 3.
WPS_CONFIG_OPTION="${WPS_CONFIG_OPTION:-3}"

echo "=== WPS installer (GCC + MPICH) ==="
echo "WPS_DIR        = ${WPS_DIR}"
echo "WRF_DIR        = ${WRF_DIR}"
echo "CONFIG_OPTION  = ${WPS_CONFIG_OPTION}"
echo

[[ -f "${WPS_DIR}/configure" ]] || { echo "ERROR: WPS missing at ${WPS_DIR} — run download_wps_source.sh on DTN."; exit 1; }
[[ -x "${WRF_DIR}/main/wrf.exe" ]] || { echo "ERROR: build WRF first (main/wrf.exe missing)."; exit 1; }

module purge 2>/dev/null || true
module load "${NETCDF_MODULE}"

export NETCDF="$(nc-config --prefix)"
export WRF_DIR
export JASPERLIB="${JASPERLIB:-/usr/lib64}"
export JASPERINC="${JASPERINC:-/usr/include}"

cd "${WPS_DIR}"
./clean -a >/dev/null 2>&1 || ./clean >/dev/null 2>&1 || true

printf '%s\n' "${WPS_CONFIG_OPTION}" | ./configure 2>&1 | tee configure.log

[[ -f configure.wps ]] || { echo "ERROR: configure.wps missing — run ./configure interactively."; exit 2; }

sed -i 's|^DM_FC[[:space:]]*=.*|DM_FC               = mpif90 -f90=gfortran|' configure.wps
sed -i 's|^DM_CC[[:space:]]*=.*|DM_CC               = mpicc -cc=gcc|'       configure.wps

./compile 2>&1 | tee compile.log

failed=0
for e in geogrid/src/geogrid ungrib/src/ungrib metgrid/src/metgrid; do
    [[ -x "${e}.exe" ]] || { echo "MISSING: ${e}.exe"; failed=1; }
done
[[ ${failed} -eq 0 ]] || { echo "ERROR: WPS build failed — see compile.log"; exit 3; }

mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/share/wps"
cp -f geogrid/src/geogrid.exe ungrib/src/ungrib.exe metgrid/src/metgrid.exe "${INSTALL_DIR}/bin/"
cp -rf ungrib/Variable_Tables "${INSTALL_DIR}/share/wps/" 2>/dev/null || true
cp -f  link_grib.csh "${INSTALL_DIR}/bin/" 2>/dev/null || true

echo "=== WPS complete ==="
ls -la "${INSTALL_DIR}/bin"/{geogrid,ungrib,metgrid}.exe

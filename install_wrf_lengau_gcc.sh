#!/bin/bash
# ---------------------------------------------------------------------------
# WRF v4.7.1 — CHPC Lengau — GNU gfortran + gcc + MPICH + NetCDF (GCC build)
#
# Prerequisite: source at ${BUILD_DIR}/WRF from download_wrf_source.sh (DTN).
# Run on a compute node (PBS). Uses ONLY the MPICH shipped with the NetCDF
# module — do not load OpenMPI in the same session.
# ---------------------------------------------------------------------------
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/home/apps/chpc/earth/WRF-4.7.1-gcc}"
BUILD_DIR="${INSTALL_DIR}/build"
MODULE_DIR="${MODULE_DIR:-/apps/chpc/scripts/modules/earth}"
MODULE_NAME="${MODULE_NAME:-wrf-lengau-gcc}"
WRF_VERSION="${WRF_VERSION:-v4.7.1}"

NETCDF_MODULE="${NETCDF_MODULE:-chpc/earth/netcdf/4.7.4/gcc-8.3.0}"

# WRF v4.7.1 Linux x86_64: GNU (gfortran/gcc), (dmpar) — verify with ./configure.
WRF_CONFIG_OPTION="${WRF_CONFIG_OPTION:-35}"
WRF_NEST_OPTION="${WRF_NEST_OPTION:-1}"
WRF_CASE="${WRF_CASE:-em_real}"

NUM_CORES="${NUM_CORES:-4}"

echo "=== WRF ${WRF_VERSION} installer (GCC + MPICH, Lengau) ==="
echo "INSTALL_DIR    = ${INSTALL_DIR}"
echo "BUILD_DIR      = ${BUILD_DIR}"
echo "MODULE_DIR     = ${MODULE_DIR} (${MODULE_NAME})"
echo "NETCDF_MODULE  = ${NETCDF_MODULE}"
echo "WRF_CONFIG     = ${WRF_CONFIG_OPTION} (nesting=${WRF_NEST_OPTION})"
echo "NUM_CORES      = ${NUM_CORES}"
echo

[[ -d "${BUILD_DIR}/WRF" ]] || {
    echo "ERROR: ${BUILD_DIR}/WRF not found. Run download_wrf_source.sh on the DTN first."
    exit 1
}

module purge 2>/dev/null || true
module load "${NETCDF_MODULE}"

export NETCDF="$(nc-config --prefix 2>/dev/null || true)"
[[ -n "${NETCDF}" && -d "${NETCDF}" ]] || {
    echo "ERROR: could not resolve NetCDF prefix (nc-config missing after loading ${NETCDF_MODULE}?)"
    exit 1
}

export WRF_ROOT="${INSTALL_DIR}"
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
export WRF_EM_CORE=1
export WRF_NMM_CORE=0

export JASPERLIB="${JASPERLIB:-/usr/lib64}"
export JASPERINC="${JASPERINC:-/usr/include}"

export FC=gfortran
export CC=gcc
export CXX=g++

echo
echo "Toolchain:"
command -v gfortran mpif90 mpicc || { echo "ERROR: gfortran/mpif90/mpicc not in PATH"; exit 1; }
gfortran --version | head -1
mpif90 --show 2>/dev/null | head -1 || true
echo "NETCDF = ${NETCDF}"
[[ -f "${NETCDF}/include/netcdf.h" ]] || { echo "ERROR: ${NETCDF}/include/netcdf.h missing"; exit 1; }
echo

cd "${BUILD_DIR}/WRF"

echo "Cleaning previous WRF build..."
./clean -a >/dev/null 2>&1 || true

echo "Running WRF ./configure (${WRF_CONFIG_OPTION}, nesting ${WRF_NEST_OPTION})..."
printf '%s\n%s\n' "${WRF_CONFIG_OPTION}" "${WRF_NEST_OPTION}" | ./configure 2>&1 | tee configure.log

[[ -f configure.wrf ]] || {
    echo "ERROR: configure.wrf missing — see configure.log. Run ./configure interactively and set WRF_CONFIG_OPTION."
    exit 2
}

# Ensure distributed-memory wrappers point at MPICH (matches CHPC NetCDF module)
sed -i 's|^DM_FC[[:space:]]*=.*|DM_FC           = mpif90 -f90=gfortran|' configure.wrf
sed -i 's|^DM_CC[[:space:]]*=.*|DM_CC           = mpicc -cc=gcc -DMPI2_SUPPORT|' configure.wrf

set +e
echo "=== compile pass 1/2 (-j ${NUM_CORES}) ==="
./compile -j "${NUM_CORES}" "${WRF_CASE}" 2>&1 | tee compile.log
echo "=== compile pass 2/2 (-j ${NUM_CORES}) ==="
./compile -j "${NUM_CORES}" "${WRF_CASE}" 2>&1 | tee compile_pass2.log
set -e

missing=0
for e in wrf real ndown tc; do
    [[ -x "main/${e}.exe" ]] || { echo "MISSING: main/${e}.exe"; missing=1; }
done
[[ ${missing} -eq 0 ]] || {
    echo
    echo "ERROR: required executables not built after two compile passes."
    grep -iE 'Fatal Error|fatal error|Error:|undefined reference|collect2:' compile_pass2.log \
        | sort -u | head -40 || true
    exit 3
}

echo
ls -la main/wrf.exe main/real.exe main/ndown.exe main/tc.exe

mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/share/wrf"
cp -f main/wrf.exe main/real.exe main/ndown.exe main/tc.exe "${INSTALL_DIR}/bin/"
cp -f configure.wrf compile.log compile_pass2.log configure.log "${INSTALL_DIR}/share/wrf/" 2>/dev/null || true

mkdir -p "${MODULE_DIR}"
cat > "${MODULE_DIR}/${MODULE_NAME}" <<MOD
#%Module1.0
##
## WRF ${WRF_VERSION} — Lengau — gfortran + MPICH + NetCDF 4.7.4 (gcc-8.3.0)
##
proc ModulesHelp { } {
    puts stderr "WRF ${WRF_VERSION} (GNU): NetCDF + MPICH from ${NETCDF_MODULE}."
    puts stderr "Use the same mpirun/mpiexec as this MPICH when running wrf.exe."
}
module-whatis "WRF ${WRF_VERSION} GNU build (Lengau)"

module load ${NETCDF_MODULE}

setenv  WRF_ROOT               ${INSTALL_DIR}
setenv  WRF_VERSION            ${WRF_VERSION}
setenv  WRF_COMPILER           "gfortran-gcc-8.3-mpich"
setenv  WRFIO_NCD_LARGE_FILE_SUPPORT 1
setenv  NETCDF                ${NETCDF}
prepend-path PATH              ${INSTALL_DIR}/bin
prepend-path LD_LIBRARY_PATH   ${INSTALL_DIR}/lib
MOD

cat > "${INSTALL_DIR}/setup_wrf_lengau_gcc.sh" <<'SETUP'
#!/bin/bash
module purge 2>/dev/null || true
module load chpc/earth/netcdf/4.7.4/gcc-8.3.0
export NETCDF="${NETCDF:-/apps/chpc/earth/netcdf2020}"
export NETCDF_ROOT="${NETCDF}"
export WRF_ROOT='WRF_ROOT_PLACEHOLDER'
export PATH="${WRF_ROOT}/bin:${PATH}"
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
echo "WRF (GNU) ready. Binaries: ${WRF_ROOT}/bin"
ls -1 "${WRF_ROOT}/bin"/*.exe 2>/dev/null || true
SETUP
sed -i "s|WRF_ROOT_PLACEHOLDER|${INSTALL_DIR}|g" "${INSTALL_DIR}/setup_wrf_lengau_gcc.sh"
chmod +x "${INSTALL_DIR}/setup_wrf_lengau_gcc.sh"

cat > "${INSTALL_DIR}/install_log_gcc.txt" <<LOG
WRF GNU build log
=================
Date:          $(date)
WRF version:   ${WRF_VERSION}
Install dir:   ${INSTALL_DIR}
NetCDF module: ${NETCDF_MODULE}
NETCDF:        ${NETCDF}
WRF configure: opt ${WRF_CONFIG_OPTION}, nest ${WRF_NEST_OPTION}

$(ls -la "${INSTALL_DIR}/bin"/*.exe)
LOG

echo
echo "=== WRF (GNU) install complete ==="
echo "Executables : ${INSTALL_DIR}/bin"
echo "Module file : ${MODULE_DIR}/${MODULE_NAME}"
echo "Usage: module load chpc/earth/${MODULE_NAME##*/}"

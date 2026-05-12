#!/bin/bash
# ---------------------------------------------------------------------------
# WRF v4.7.1 — CHPC Lengau — GNU gfortran + gcc + MPICH + NetCDF (GCC build)
#
# Prerequisite: WRF source at ${BUILD_DIR}/WRF (download_wrf_source.sh on DTN).
# WRF 4.7+ needs phys/physics_mmm from GitHub: run checkout_wrf_externals_dtn.sh on the DTN
# (./clean -a removes it). Leave WRF_RUN_CLEAN unset to auto-skip clean when .git exists.
# Run on a compute node (PBS). Use only the MPICH from the NetCDF module — do not load OpenMPI.
# ---------------------------------------------------------------------------
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/home/apps/chpc/earth/WRF-4.7.1-gcc}"
BUILD_DIR="${INSTALL_DIR}/build"
MODULE_DIR="${MODULE_DIR:-/apps/chpc/scripts/modules/earth}"
MODULE_NAME="${MODULE_NAME:-wrf-lengau-gcc}"
WRF_VERSION="${WRF_VERSION:-v4.7.1}"

NETCDF_MODULE="${NETCDF_MODULE:-chpc/earth/netcdf/4.7.4/gcc-8.3.0}"

# WRF v4.7.1 Linux x86_64 menu: 34 = GNU dmpar; 35 = GNU dm+sm (MPI+OpenMP).
WRF_CONFIG_OPTION="${WRF_CONFIG_OPTION:-34}"

# ./clean -a removes phys/physics_mmm; Lengau compute nodes usually cannot git clone.
# Unset WRF_RUN_CLEAN to auto: skip clean if phys/physics_mmm/.git already exists.
if [[ -z "${WRF_RUN_CLEAN:-}" ]]; then
    if [[ -d "${BUILD_DIR}/WRF/phys/physics_mmm/.git" ]]; then
        WRF_RUN_CLEAN=0
    else
        WRF_RUN_CLEAN=1
    fi
fi
WRF_NEST_OPTION="${WRF_NEST_OPTION:-1}"
WRF_CASE="${WRF_CASE:-em_real}"

NUM_CORES="${NUM_CORES:-4}"

echo "=== WRF ${WRF_VERSION} installer (GCC + MPICH, Lengau) ==="
echo "INSTALL_DIR    = ${INSTALL_DIR}"
echo "BUILD_DIR      = ${BUILD_DIR}"
echo "MODULE_DIR     = ${MODULE_DIR} (${MODULE_NAME})"
echo "NETCDF_MODULE  = ${NETCDF_MODULE}"
echo "WRF_CONFIG     = ${WRF_CONFIG_OPTION} (nesting=${WRF_NEST_OPTION})"
echo "WRF_RUN_CLEAN  = ${WRF_RUN_CLEAN} (1=./clean -a before configure; 0=preserve phys/physics_mmm)"
echo "NUM_CORES      = ${NUM_CORES}"
echo

[[ -d "${BUILD_DIR}/WRF" ]] || {
    echo "ERROR: ${BUILD_DIR}/WRF not found. Run download_wrf_source.sh on the DTN first."
    exit 1
}

module purge 2>/dev/null || true
module load "${NETCDF_MODULE}"
# WRF 4.7+ runs checkout_externals during the physics build; compute nodes often have no python3 in default PATH.
if ! command -v python3 &>/dev/null; then
    module load chpc/python/anaconda/3-2024.10.1 2>/dev/null \
        || module load python3 2>/dev/null \
        || true
fi
command -v python3 &>/dev/null || {
    echo "ERROR: python3 not found after modules. Load a Python 3 module before building (e.g. chpc/python/anaconda/3-2024.10.1)."
    exit 1
}

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

if [[ "${WRF_RUN_CLEAN}" == "1" ]]; then
    echo "Cleaning previous WRF build (./clean -a)..."
    ./clean -a >/dev/null 2>&1 || true
else
    echo "Skipping ./clean -a (WRF_RUN_CLEAN=0) — preserving phys/physics_mmm for offline Git checkouts."
fi

if [[ "${WRF_RUN_CLEAN}" == "0" ]]; then
    if [[ ! -d phys/physics_mmm/.git ]]; then
        echo
        echo "ERROR: phys/physics_mmm is not a git checkout (.git missing) but WRF_RUN_CLEAN=0."
        echo "On the DTN (GitHub access), run:"
        echo "  INSTALL_DIR=${INSTALL_DIR} ./checkout_wrf_externals_dtn.sh"
        echo "Optionally RUN_CLEAN_A=1 for ./clean -a on the DTN before checkout."
        exit 2
    fi
fi

echo "Running WRF ./configure (${WRF_CONFIG_OPTION}, nesting ${WRF_NEST_OPTION})..."
printf '%s\n%s\n' "${WRF_CONFIG_OPTION}" "${WRF_NEST_OPTION}" | ./configure 2>&1 | tee configure.log

[[ -f configure.wrf ]] || {
    echo "ERROR: configure.wrf missing — see configure.log. Run ./configure interactively and set WRF_CONFIG_OPTION."
    exit 2
}

# MPICH 3.3 on Lengau: plain mpif90/mpicc (do not pass -f90=/ -cc=; wrappers reject them)
sed -i 's|^DM_FC[[:space:]]*=.*|DM_FC           = mpif90|' configure.wrf
sed -i 's|^DM_CC[[:space:]]*=.*|DM_CC           = mpicc -DMPI2_SUPPORT|' configure.wrf

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

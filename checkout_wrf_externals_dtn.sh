#!/bin/bash
# ---------------------------------------------------------------------------
# WRF v4.7+ — fetch NCAR externals (e.g. MMM-physics) on a host with GitHub.
#
# Run on the CHPC DTN (dtn.chpc.ac.za): compute nodes often cannot clone from
# GitHub; ./clean -a also wipes phys/physics_mmm, so populate it here before
# qsub, and use WRF_RUN_CLEAN=0 (or rely on auto-default when .git exists).
# ---------------------------------------------------------------------------
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/home/apps/chpc/earth/WRF-4.7.1-gcc}"
BUILD_DIR="${INSTALL_DIR}/build"
WRF_DIR="${BUILD_DIR}/WRF"
RUN_CLEAN_A="${RUN_CLEAN_A:-0}"

[[ -d "${WRF_DIR}" ]] || {
    echo "ERROR: ${WRF_DIR} not found. Set INSTALL_DIR or run download_wrf_source.sh first."
    exit 1
}

# CHPC login/DTN shells often inherit Intel paths in LD_LIBRARY_PATH; that breaks
# git-remote-https (libcurl vs libnss). Purge modules and drop LD_* before git.
module purge 2>/dev/null || true
unset LD_LIBRARY_PATH

# CentOS 7 /usr/bin/git is often 1.8.3 — too old for manage_externals (needs git -C).
if [[ "$(git --version 2>/dev/null | sed -n 's/.*git version \([0-9]*\).*/\1/p')" == "1" ]]; then
    module load chpc/git/2.41.0 2>/dev/null \
        || module load chpc/git/2.38.1 2>/dev/null \
        || module load chpc/git/2.14 2>/dev/null \
        || true
fi
if git -C /tmp help 2>&1 | grep -q "Unknown option"; then
    echo "ERROR: git is too old (need -C option). On CHPC run: module load chpc/git/2.41.0"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    module load chpc/python/anaconda/3-2024.10.1 2>/dev/null \
        || module load python3 2>/dev/null \
        || true
fi
command -v python3 &>/dev/null || {
    echo "ERROR: python3 not found (load a Python module on the DTN if needed)."
    exit 1
}
command -v git &>/dev/null || {
    echo "ERROR: git not found in PATH."
    exit 1
}

cd "${WRF_DIR}"

if [[ "${RUN_CLEAN_A}" == "1" ]]; then
    echo "=== ./clean -a (full WRF clean) ==="
    ./clean -a
fi

echo "=== checkout_externals (see arch/Externals.cfg) in ${WRF_DIR} ==="
# Modules (e.g. Anaconda) may re-set LD_LIBRARY_PATH; git HTTPS needs a clean stack.
unset LD_LIBRARY_PATH
./tools/manage_externals/checkout_externals --externals ./arch/Externals.cfg

[[ -d phys/physics_mmm/.git ]] || {
    echo "ERROR: phys/physics_mmm/.git missing after checkout — see messages above."
    exit 1
}

echo "=== MMM-physics checkout OK ==="
echo "Submit your PBS job with WRF_RUN_CLEAN=0, or leave WRF_RUN_CLEAN unset if"
echo "install_wrf_lengau_gcc.sh auto-selects skip-clean (when physics_mmm/.git exists)."

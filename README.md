# WRF / WPS on CHPC Lengau — GCC + MPICH build

Scripts to build **WRF** and **WPS** on the [Centre for High Performance Computing (CHPC)](https://www.chpc.ac.za/) **Lengau** cluster using the **GNU** toolchain (**gfortran** / **gcc**) and **MPICH**, with **NetCDF** from the CHPC module stack.

This is a **separate repository** from [wrf-lengau](https://github.com/msovara/wrf-lengau) (Intel / oneAPI oriented builds). Use this repo when you want a supported **GCC** path or to avoid Intel Fortran corner cases.

**Author / organisation:** [Mthetho Sovara on GitHub](https://github.com/msovara)

## Toolchain (verified on Lengau)

| Component | CHPC module / path |
|-----------|-------------------|
| Compilers | `chpc/compmech/gcc/8.3.0` (via NetCDF module) |
| MPI | **MPICH 3.3** gcc 8.3 — loaded with NetCDF module (do **not** mix in OpenMPI for this stack) |
| NetCDF | `chpc/earth/netcdf/4.7.4/gcc-8.3.0` → install prefix **`/apps/chpc/earth/netcdf2020`** |

After `module load chpc/earth/netcdf/4.7.4/gcc-8.3.0`:

- `NETCDF` should be `/apps/chpc/earth/netcdf2020` (or use `$(nc-config --prefix)`).
- `mpif90` / `mpicc` come from MPICH and match the NetCDF build.

## Default install location (shared provisioning)

Scripts default to:

```text
/home/apps/chpc/earth/WRF-4.7.1-gcc
```

Override with `INSTALL_DIR=/path` if needed. Binaries are staged under `$INSTALL_DIR/bin/`.

Suggested environment module name after install: **`chpc/earth/wrf-lengau-gcc`** (written by `install_wrf_lengau_gcc.sh` unless you set `MODULE_DIR`).

## Quick start

### 1. Clone this repository

```bash
git clone https://github.com/msovara/wrf-lengau-gcc.git
cd wrf-lengau-gcc
```

### 2. Download source (DTN node — compute nodes have no outbound internet)

On `dtn.chpc.ac.za`:

```bash
export INSTALL_DIR=/home/apps/chpc/earth/WRF-4.7.1-gcc
cp -r wrf-lengau-gcc/* "$INSTALL_DIR/"   # or clone directly under $INSTALL_DIR
cd "$INSTALL_DIR"
chmod +x download_*.sh install_*.sh
./download_wrf_source.sh
./download_wps_source.sh
```

### 3. Build on a compute node

Use an interactive allocation or `qsub` with the provided PBS template (edit **`-P` project** and queue).

```bash
cd /home/apps/chpc/earth/WRF-4.7.1-gcc
./install_wrf_lengau_gcc.sh
./install_wps_lengau_gcc.sh
```

### 4. Use on Lengau

```bash
module load chpc/earth/netcdf/4.7.4/gcc-8.3.0
module load chpc/earth/wrf-lengau-gcc
# or: source /home/apps/chpc/earth/WRF-4.7.1-gcc/setup_wrf_lengau_gcc.sh
```

Run `wrf.exe` / `real.exe` with your PBS `mpirun` / `mpiexec` from the **same** MPICH module.

## WRF / WPS `configure` option numbers

For **WRF v4.7.1** on **Linux x86_64**, the **GNU (`gfortran`/`gcc`) distributed-memory parallel** (`dmpar`) choice is typically **option 35** in `./configure` (always confirm on first run — NCAR renumbers occasionally).

For **WPS** (current upstream `master` `configure.defaults`), **Linux x86_64 gfortran** list is usually: `serial`, `serial_NO_GRIB2`, **`dmpar`**, `dmpar_NO_GRIB2` → pick **`dmpar`** (often **3**). Override with `WPS_CONFIG_OPTION` if your menu differs.

Set before running installers if needed:

```bash
export WRF_CONFIG_OPTION=35
export WRF_NEST_OPTION=1
export WPS_CONFIG_OPTION=3
```

## Repository layout

| File | Purpose |
|------|--------|
| `download_wrf_source.sh` | Clone WRF + submodules on DTN |
| `download_wps_source.sh` | Clone WPS on DTN |
| `install_wrf_lengau_gcc.sh` | Configure + compile WRF (`em_real`) |
| `install_wps_lengau_gcc.sh` | Configure + compile WPS (after WRF) |
| `pbs_build_wrf_gcc.pbs.template` | Example PBS job |
| `DEPLOY_SCRIPTS.md` | Copy scripts to `$INSTALL_DIR` |

## References

- [WRF Users Page](https://www2.mmm.ucar.edu/wrf/users/)
- [WRF GitHub](https://github.com/wrf-model/WRF)
- [WPS GitHub](https://github.com/wrf-model/WPS)

## Licence

MIT — see [LICENSE](LICENSE).

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

**WRF v4.7.x** pulls **MMM-physics** from GitHub via **`manage_externals` / `checkout_externals`**. On Lengau, **compute nodes often cannot reach GitHub**, while **`./clean -a` deletes `phys/physics_mmm`**. Use the **DTN** to run **`checkout_wrf_externals_dtn.sh`** (or the same `checkout_externals` command by hand), then build with **`WRF_RUN_CLEAN=0`** or leave **`WRF_RUN_CLEAN` unset** after checkout—the installer **auto-skips** `./clean -a` when **`phys/physics_mmm/.git`** is already present.

Compute jobs still need **`python3`** in `PATH` for other build steps; the installers try **`module load chpc/python/anaconda/3-2024.10.1`** if `python3` is missing.

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
chmod +x download_*.sh install_*.sh checkout_wrf_externals_dtn.sh
./download_wrf_source.sh
./download_wps_source.sh
# Full WRF clean on DTN + fetch MMM-physics from GitHub. Omit RUN_CLEAN_A if ./clean -a not needed.
RUN_CLEAN_A=1 ./checkout_wrf_externals_dtn.sh
```

### 3. Build on a compute node

Use an interactive allocation or `qsub` with the provided PBS template (edit **`-P` project** and queue).

```bash
cd /home/apps/chpc/earth/WRF-4.7.1-gcc
./install_wrf_lengau_gcc.sh
./install_wps_lengau_gcc.sh
```

### 4. Use on Lengau (environment)

Install root (default):

```text
WRF_ROOT=/home/apps/chpc/earth/WRF-4.7.1-gcc
```

**Every** run or job should use the **same** software stack this build was compiled with:

```bash
module load chpc/earth/netcdf/4.7.4/gcc-8.3.0    # MPICH + gfortran + NetCDF in PATH/LD_LIBRARY_PATH
module load chpc/earth/wrf-lengau-gcc          # prepends $WRF_ROOT/bin; sets WRF_ROOT, NETCDF, etc.
```

If `module load chpc/earth/wrf-lengau-gcc` is not yet registered on your system, use the helper script (NetCDF only — add WRF `bin` yourself) or call binaries by full path:

```bash
source /home/apps/chpc/earth/WRF-4.7.1-gcc/setup_wrf_lengau_gcc.sh
export PATH="/home/apps/chpc/earth/WRF-4.7.1-gcc/bin:${PATH}"
```

**Important:** run **`wrf.exe`** and **`real.exe`** under **`mpirun` / `mpiexec` / `mpiexec.hydra`** from this **MPICH** (the one loaded with the NetCDF module above). Do **not** mix in OpenMPI or Intel MPI for this build.

This installation is **WRF-ARW `em_real`** (meteorology only), **not WRF-Chem**.

---

## User guide: running WPS and WRF on Lengau

### What gets installed where

| Location | Contents |
|----------|----------|
| `$WRF_ROOT/bin/` | `geogrid.exe`, `ungrib.exe`, `metgrid.exe`, `link_grib.csh`, `real.exe`, `wrf.exe`, `ndown.exe`, `tc.exe` |
| `$WRF_ROOT/share/wps/Variable_Tables/` | WPS Vtable files for `ungrib` (pick the file that matches your GRIB source) |
| `$WRF_ROOT/share/wrf/` | Build logs and `configure.wrf` (for reference / debugging) |

Work in a **separate directory per experiment** (e.g. `$HOME/wrf_runs/case01/`). Copy or link namelists and static data there; do not run in `$WRF_ROOT` itself.

### Recommended order of operations

1. **Prepare namelists** in your case directory: `namelist.wps` (WPS) and `namelist.input` (WRF). Align dates, domains, and projection settings between them.
2. **Static geography:** set `geog_input_path` in `namelist.wps` to your [WPS geographical input](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html) tree (often a shared read-only path on the cluster).
3. **`geogrid.exe`** — defines the model grids and writes `geo_em.d01.nc`, …
4. **GRIB data:** link or copy GRIB files into the case directory. From the same environment, run **`link_grib.csh`** (from `$WRF_ROOT/bin`) as documented in the WPS Users Guide.
5. **`ungrib.exe`** — needs a **`Vtable`** soft-linked as `Vtable` (use the appropriate file under `$WRF_ROOT/share/wps/Variable_Tables/`).
6. **`metgrid.exe`** — merges static + ungrib output into `met_em.d01.*` files for WRF.
7. **`real.exe`** — MPI; produces `wrfinput` / `wrfbdy` from `met_em`.
8. **`wrf.exe`** — MPI; the forecast integration.

Typical serial WPS steps (small domains; adjust if your site recommends MPI for WPS):

```bash
module load chpc/earth/netcdf/4.7.4/gcc-8.3.0
module load chpc/earth/wrf-lengau-gcc
cd /path/to/your/case

./geogrid.exe
./ungrib.exe
./metgrid.exe
```

Then run **`real.exe`** and **`wrf.exe`** with MPI, for example:

```bash
# Replace NP with the number of MPI ranks you requested in PBS or your allocation
mpirun -np NP ./real.exe
mpirun -np NP ./wrf.exe
```

Use the same **`mpirun`** you get after `module load chpc/earth/netcdf/4.7.4/gcc-8.3.0` (MPICH). On some systems the command is `mpiexec` or `mpiexec.hydra`; all should come from this module stack.

### Minimal PBS (WRF integration) example

Adapt **queue**, **`#PBS -P`**, walltime, and **`NP`** to your project and domain size.

```bash
#!/bin/bash
#PBS -N wrf_case01
#PBS -P YOUR_PROJECT_CODE
#PBS -q smp
#PBS -l select=1:ncpus=24:mpiprocs=24
#PBS -l walltime=12:00:00
#PBS -j oe

module purge
module load chpc/earth/netcdf/4.7.4/gcc-8.3.0
module load chpc/earth/wrf-lengau-gcc

cd "$PBS_O_WORKDIR"    # or: cd /path/to/your/case

NP=24
mpirun -np "$NP" ./real.exe
mpirun -np "$NP" ./wrf.exe
```

Run **WPS** (`geogrid`, `ungrib`, `metgrid`) either in an interactive session, a short serial job, or earlier steps in the same job script before `real.exe`, depending on your workflow and cluster policy.

### Where to learn the science / namelist details

- [WRF Users Page](https://www2.mmm.ucar.edu/wrf/users/) — tutorials, recommended namelist settings, and best practices.
- [WPS Users Guide](https://www2.mmm.ucar.edu/wrf/users/docs/user_guide_V4.4/users_guide_wps.html) — `namelist.wps`, `ungrib` Vtables, `metgrid` output.

## WRF / WPS `configure` option numbers

For **WRF v4.7.1** on **Linux x86_64**, **GNU (`gfortran`/`gcc`)** lines are **`dmpar`** vs **`dm+sm` (MPI+OpenMP)**. The default **`WRF_CONFIG_OPTION=34`** is **`dmpar`**; use **`35`** for **`dm+sm`** (always confirm with the live `./configure` menu).

For **WPS** (current upstream `master` `configure.defaults`), **Linux x86_64 gfortran** list is usually: `serial`, `serial_NO_GRIB2`, **`dmpar`**, `dmpar_NO_GRIB2` → pick **`dmpar`** (often **3**). Override with `WPS_CONFIG_OPTION` if your menu differs.

Set before running installers if needed:

```bash
export WRF_CONFIG_OPTION=34
export WRF_NEST_OPTION=1
export WPS_CONFIG_OPTION=3
```

## Repository layout

| File | Purpose |
|------|--------|
| `download_wrf_source.sh` | Clone WRF + submodules on DTN |
| `download_wps_source.sh` | Clone WPS on DTN |
| `checkout_wrf_externals_dtn.sh` | On the **DTN**: `checkout_externals` for **MMM-physics** (GitHub) |
| `install_wrf_lengau_gcc.sh` | Configure + compile WRF (`em_real`); respects **`WRF_RUN_CLEAN`** |
| `install_wps_lengau_gcc.sh` | Configure + compile WPS (after WRF) |
| `pbs_build_wrf_gcc.pbs.template` | Example PBS job |
| `DEPLOY_SCRIPTS.md` | Copy scripts to `$INSTALL_DIR` |

## References

- [WRF Users Page](https://www2.mmm.ucar.edu/wrf/users/)
- [WRF GitHub](https://github.com/wrf-model/WRF)
- [WPS GitHub](https://github.com/wrf-model/WPS)

## Licence

MIT — see [LICENSE](LICENSE).

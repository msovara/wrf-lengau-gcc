# Deploying scripts under `/home/apps/chpc/earth`

Provisioned installs should live on Lustre-backed app space, not personal `$HOME`.

## Option A — Clone on DTN then build on a compute node

```bash
# DTN
cd /home/apps/chpc/earth
git clone https://github.com/msovara/wrf-lengau-gcc.git
export INSTALL_DIR=/home/apps/chpc/earth/WRF-4.7.1-gcc
mkdir -p "$INSTALL_DIR"
cp wrf-lengau-gcc/*.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh
cd "$INSTALL_DIR"
./download_wrf_source.sh
./download_wps_source.sh
```

## Option B — Copy from your laptop

```bash
scp -r wrf-lengau-gcc msovara@dtn.chpc.ac.za:/home/apps/chpc/earth/
```

Then follow download + PBS build steps in [README.md](README.md).

## PBS

Copy `pbs_build_wrf_gcc.pbs.template` to `$INSTALL_DIR/_build_logs/pbs_build_wrf_gcc.pbs`, set `#PBS -P your_project`, and `qsub`.

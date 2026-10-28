#!/bin/bash
#SBATCH --job-name=aif-setting-full
#SBATCH --partition=day
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G

# A full pipeline run under a named setting (docs/v1_2_plan.md), output to
# scratch (no --publish), for recording a rung's revenue effect against the
# legacy run. Resources as for layer 3 (legacy_full.sbatch: peak 99 GB).
# Submit from the repo root:
#   SETTING=v1_2_reference TAX_SIMULATOR_DIR=<path> BLSMM_DIR=<path> \
#     sbatch --output=<log dir>/%x-%j.out tests/server/setting_full.sbatch
# Success = exit code 0 AND "status: succeeded" in the run's manifest.

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

: "${SETTING:?set SETTING to a setting name (config/settings/<name>.yaml)}"
: "${TAX_SIMULATOR_DIR:?set TAX_SIMULATOR_DIR to the Tax-Simulator worktree}"
: "${BLSMM_DIR:?set BLSMM_DIR to the Budget Lab Small Macro Model checkout}"
export TAX_SIMULATOR_DIR BLSMM_DIR

module load R/4.4.2-gfbf-2024a
# Use the module's CRAN bundle, not the repo's renv library (see
# run_release.sbatch).
export RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
export MC_CORES=${SLURM_CPUS_PER_TASK}

STAMP=$(date +%Y%m%d%H%M)
RUN_DIR="results/runs/${SETTING}-${STAMP}"

echo "Host: $(hostname)   Cores: ${SLURM_CPUS_PER_TASK}   Started: $(date)"
echo "SETTING=${SETTING}"
echo "TAX_SIMULATOR_DIR=${TAX_SIMULATOR_DIR}"
echo "BLSMM_DIR=${BLSMM_DIR}"
echo "Run directory: ${RUN_DIR}"

/usr/bin/time -v Rscript code/00_ai_fiscal_sim.R --multicore scenario \
  --setting "${SETTING}" --vintage "${STAMP}"

grep -q '^status: succeeded' "${RUN_DIR}/manifest.yaml"
echo "Finished: $(date)"

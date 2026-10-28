#!/bin/bash
#SBATCH --job-name=aif-legacy-full
#SBATCH --partition=day
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G

# Rung 0 reproduction, layer 3 (docs/v1_2_plan.md): a full pipeline run under
# the legacy_v1_0_1 setting, output to scratch (no --publish), then every
# result table compared against the erratum's run D (v1.0.1).
# Submit from the repo root, naming the Tax-Simulator and BLSMM builds that
# produced v1.0.1 (Tax-Simulator 256f03ea9 + the three local patches; BLSMM
# adce14d):
#   TAX_SIMULATOR_DIR=<path> BLSMM_DIR=<path> \
#     sbatch --output=<log dir>/%x-%j.out tests/server/legacy_full.sbatch
# Success = exit code 0 AND "LAYER3 PASS" in the log.

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

: "${TAX_SIMULATOR_DIR:?set TAX_SIMULATOR_DIR to the Tax-Simulator worktree}"
: "${BLSMM_DIR:?set BLSMM_DIR to the Budget Lab Small Macro Model checkout}"
export TAX_SIMULATOR_DIR BLSMM_DIR

module load R/4.4.2-gfbf-2024a
# Use the module's CRAN bundle, not the repo's renv library (see
# run_release.sbatch).
export RENV_CONFIG_AUTOLOADER_ENABLED=FALSE
export MC_CORES=${SLURM_CPUS_PER_TASK}

STAMP=$(date +%Y%m%d%H%M)
RUN_DIR="results/runs/legacy_v1_0_1-${STAMP}"
REF_DIR="results/erratum_v1.0.1/runs/D_v1.0.1/aggregates"

echo "Host: $(hostname)   Cores: ${SLURM_CPUS_PER_TASK}   Started: $(date)"
echo "TAX_SIMULATOR_DIR=${TAX_SIMULATOR_DIR}"
echo "BLSMM_DIR=${BLSMM_DIR}"
echo "Run directory: ${RUN_DIR}"

/usr/bin/time -v Rscript code/00_ai_fiscal_sim.R --multicore scenario \
  --vintage "${STAMP}"

grep -q '^status: succeeded' "${RUN_DIR}/manifest.yaml"
Rscript tests/server/compare_run_tables.R "${RUN_DIR}/tables" "${REF_DIR}"
echo "Finished: $(date)"

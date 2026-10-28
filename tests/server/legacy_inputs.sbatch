#!/bin/bash
#SBATCH --job-name=aif-legacy-inputs
#SBATCH --partition=day
#SBATCH --time=01:30:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G

# Rung 0 reproduction, layer 2: see tests/server/legacy_inputs_check.R.
# Submit from the repo root:
#   sbatch --output=<log dir>/%x-%j.out tests/server/legacy_inputs.sbatch
# Success = exit code 0 AND "LAYER2 PASS" in the log.

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:-$PWD}"

module load R/4.4.2-gfbf-2024a
# Use the module's CRAN bundle, not the repo's renv library (see
# run_release.sbatch).
export RENV_CONFIG_AUTOLOADER_ENABLED=FALSE

echo "Host: $(hostname)   Started: $(date)"
/usr/bin/time -v Rscript tests/server/legacy_inputs_check.R
echo "Finished: $(date)"

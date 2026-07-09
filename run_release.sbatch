#!/bin/bash
#SBATCH --job-name=ai-fiscal-release
#SBATCH --account=pi_nrs36
#SBATCH --partition=day
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --output=logs/slurm_release_%j.out
#SBATCH --error=logs/slurm_release_%j.err

# AI-Fiscal full release run (18-cell grid x 3 flavors = 54 Tax-Simulator cells).
# Submit from the repo root:  sbatch run_release.sbatch
# Watch:                      tail -f logs/slurm_release_<jobid>.out

set -euo pipefail

# --- R environment (Lmod; must load in the same shell as Rscript) ---
module load R/4.4.2-gfbf-2024a

# Disable the renv autoloader so both this process AND the callr subprocess
# that runs Tax-Simulator use the module's CRAN bundle (which provides
# tidyverse + the full stack). The repo's renv library is a CI artifact and
# is out-of-sync on the cluster; leaving it active drops tidyverse from
# .libPaths() and Tax-Simulator's `library(tidyverse)` fails.
export RENV_CONFIG_AUTOLOADER_ENABLED=FALSE

# --- required: Tax-Simulator working tree ---
export TAX_SIMULATOR_DIR=/nfs/roberts/project/pi_nrs36/ji252/repos/Tax-Simulator

# --- optional: BLSMM for the 2030 debt/GDP step (comment out to skip) ---
# export BLSMM_DIR=/path/to/Budget-Lab-Small-Macro-Model

# --- forward the SLURM core allocation into the Tax-Simulator subprocess ---
# The local-fork patch (Issue 3) reads MC_CORES; keep it in sync with cpus-per-task.
export MC_CORES=${SLURM_CPUS_PER_TASK}

mkdir -p logs

echo "Host:            $(hostname)"
echo "Cores allocated: ${SLURM_CPUS_PER_TASK}"
echo "TAX_SIMULATOR_DIR=${TAX_SIMULATOR_DIR}"
echo "Started:         $(date)"

# --publish: this is a final publication run, so write the Tax-Simulator
# output tree to the shared `production` root (not the scratch/testing root).
# Drop --publish for experimental submissions to keep output on scratch.
Rscript code/00_ai_fiscal_sim.R --multicore scenario --overwrite --publish

echo "Finished:        $(date)"

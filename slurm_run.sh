#!/bin/bash
#SBATCH --job-name=AI-Fiscal_release
#SBATCH --output=logs/sbatch_%j.out
#SBATCH --error=logs/sbatch_%j.err
#SBATCH --time=18:00:00
#SBATCH --mem=128G
#SBATCH --cpus-per-task=8

#-----------------------------------------------------------------------
# slurm_run.sh
#
# Reference SBATCH driver for the AI-Fiscal v0.1.0 release pipeline.
# Submits a single job that runs the full orchestrator
# (code/00_ai_fiscal_sim.R) end-to-end: build counterfactuals, run
# Tax-Simulator across all 18 cells x 3 flavors, aggregate, write the
# publishable bundle and figures, and (if BLSMM_DIR is set) run the
# optional BLSMM debt/GDP step.
#
# Usage:
#   sbatch slurm_run.sh [--data-dir PATH] [--years YYYY:YYYY] [...]
#
# Any flags supplied are forwarded to 00_ai_fiscal_sim.R. The default
# 18-cell grid runs without overrides; common flags:
#   --data-dir tests/fixtures/synthetic_tax_data   # no-PUF smoke
#   --multicore scenario                            # parallelize cells
#   --overwrite                                     # replace existing cf
#
# Required env vars (export before sbatch):
#   TAX_SIMULATOR_DIR     Path to a Tax-Simulator working tree.
#
# Optional env vars:
#   BLSMM_DIR             Path to a Budget Lab Small Macro Model
#                         clone. If unset, the BLSMM step skips
#                         gracefully and the rest of the pipeline
#                         finishes normally.
#   AI_FISCAL_SCRATCH_ROOT
#                         Used by the standalone aggregator entry
#                         point only. The orchestrator passes the
#                         resolved output_root directly and does
#                         not require this var.
#   MC_CORES              Forwarded to the Tax-Simulator subprocess
#                         for the local-fork mclapply patch.
#                         Defaults to 8.
#
# Cluster-specific: the `module load R/...` line below is the Yale
# Roberts EasyBuild module name. Adapt for your environment, or
# comment it out if R is on PATH already.
#-----------------------------------------------------------------------

set -euo pipefail

# Resolve repo root from the script's location so this works
# regardless of where it's submitted from.
REPO_DIR=$(cd "$(dirname "$0")" && pwd)

echo "=== AI-Fiscal SLURM run ==="
echo "Repository:        ${REPO_DIR}"
echo "Job ID:            ${SLURM_JOB_ID:-(not running under SLURM)}"
echo "TAX_SIMULATOR_DIR: ${TAX_SIMULATOR_DIR:-(unset; REQUIRED)}"
echo "BLSMM_DIR:         ${BLSMM_DIR:-(unset; BLSMM step will skip)}"
echo "MC_CORES:          ${MC_CORES:-8 (default)}"
echo "Forwarded flags:   $@"
echo ""

module load R/4.4.2-gfbf-2024a

cd "${REPO_DIR}"
MC_CORES="${MC_CORES:-8}" Rscript code/00_ai_fiscal_sim.R \
  --overwrite --multicore scenario "$@"

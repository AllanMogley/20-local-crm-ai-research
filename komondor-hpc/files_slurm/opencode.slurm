#!/bin/bash
#SBATCH --account=nr_szetdk
#SBATCH --job-name=opencode
#SBATCH --partition=cpu
#SBATCH --mem=8G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:20:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=wafula.allan.wanjala@hallgato.sze.h
#SBATCH --output=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/outputs_slurm/opencode/out/slurm-%j.out
#SBATCH --error=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/outputs_slurm/opencode/err/slurm-%j.err

# Stop Job incase an error occurs
set -e

# Load modules
module load apptainer

# --------------------------------------------------
# Configuration
# --------------------------------------------------

SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/apptainer-images/opencode.sif"
INSTANCE="opencode-${SLURM_JOB_ID}"

# Bind paths
OPENCODE_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/opencode"
OPENCODE_CONTAINER_DIR="/workspace/opencode"
TAU_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/tau-bench/tau2-bench"
TAU_CONTAINER_DIR="/workspace/tau2-bench"

echo "========================================"
echo "Tau2-Bench Slurm Job"
echo "========================================"
echo "Job ID:        ${SLURM_JOB_ID}"
echo "Node:          $(hostname)"
echo "SIF:           ${SIF}"
echo "Instance:      ${INSTANCE}"
echo "========================================"

# --------------------------------------------------
# Check SIF
# --------------------------------------------------

if [ ! -f "${SIF}" ]; then
    echo "ERROR: SIF does not exist:"
    echo "${SIF}"
    exit 1
fi

# --------------------------------------------------
# Start Apptainer instance
# --------------------------------------------------


apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home /workspace/opencode \
    --bind "${TAU_DIR}:${TAU_CONTAINER_DIR}" \
    --bind "${OPENCODE_DIR}:${OPENCODE_CONTAINER_DIR}" \
    --env HOME=/workspace \
    "${SIF}" \
    "${INSTANCE}"

# --------------------------------------------------
# Make sure instance is stopped when job exits
# --------------------------------------------------

cleanup() {
    echo "Stopping Apptainer instance ${INSTANCE}..."
    apptainer instance stop "${INSTANCE}" || true
}

# Send signal to run cleanup() function
trap cleanup EXIT

# --------------------------------------------------
# Show instance
# --------------------------------------------------

echo
echo "Running Apptainer instances:"
apptainer instance list

echo
echo "========================================"
echo "Instance is running"
echo "========================================"
echo
echo "Node:"
echo "  $(hostname)"
echo
echo "Job ID:"
echo "  ${SLURM_JOB_ID}"
echo
echo "Instance:"
echo "  ${INSTANCE}"
echo
echo "Connect with:"
echo
echo "  srun --jobid=${SLURM_JOB_ID} --pty bash"
echo
echo "Then:"
echo
echo "  apptainer exec instance://${INSTANCE} bash"
echo
echo "========================================"

# --------------------------------------------------
# Keep the SLURM allocation alive
# --------------------------------------------------

sleep infinity

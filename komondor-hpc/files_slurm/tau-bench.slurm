#!/bin/bash
#SBATCH --account=nr_szetdk
#SBATCH --job-name=tau-bench
#SBATCH --partition=cpu
#SBATCH --mem=2G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:30:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=afula.allan.wanjala@hallgato.sze.h
#SBATCH --output=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/outputs_slurm/tau-bench/out/slurm-%j.out
#SBATCH --error=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/outputs_slurm/tau-bench/err/slurm-%j.err

set -e

# --------------------------------------------------
# Configuration
# --------------------------------------------------

SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/apptainer-images/tau-bench.sif"
INSTANCE="tau-bench-${SLURM_JOB_ID}"
TAU_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/tau-bench/tau2-bench"
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
    --no-home \
    --writable-tmpfs \
    --bind "${TAU_DIR}:${TAU_CONTAINER_DIR}" \
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

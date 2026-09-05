#!/bin/bash
#SBATCH --job-name=tau-bench
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_a100-sxm4-40gb:1
#SBATCH --mem=32G
#SBATCH --time=00:30:00
#SBATCH --output=/home/nr_szww/nr_szetdk/allan_wanjala/slurm-%j.out
#SBATCH --error=/home/nr_szww/nr_szetdk/allan_wanjala/slurm-%j.err

set -e

# --------------------------------------------------
# Configuration
# --------------------------------------------------

SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondo-hpc/2-apptainer-images/tau-bench.sif"
INSTANCE="tau-bench-${SLURM_JOB_ID}"
WORKDIR="/home/nr_szww/nr_szetdk/allan_wanjala"

echo "========================================"
echo "Tau2-Bench Slurm Job"
echo "========================================"
echo "Job ID:        ${SLURM_JOB_ID}"
echo "Node:          $(hostname)"
echo "GPU:"
nvidia-smi
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
    --nv \
    --no-home \
    --bind "${WORKDIR}:${WORKDIR}" \
    "${SIF}" \
    "${INSTANCE}"

# --------------------------------------------------
# Make sure instance is stopped when job exits
# --------------------------------------------------

cleanup() {
    echo "Stopping Apptainer instance ${INSTANCE}..."
    apptainer instance stop "${INSTANCE}" || true
}

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

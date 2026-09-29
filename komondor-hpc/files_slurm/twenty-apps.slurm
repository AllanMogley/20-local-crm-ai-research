#!/bin/bash
#SBATCH --account=nr_szetdk
#SBATCH --job-name=twenty-apps-postgres
#SBATCH --partition=cpu
#SBATCH --mem=12G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:40:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=wafula.allan.wanjala@hallgato.sze.h
#SBATCH --output=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/outputs_slurm/twenty-apps/out/slurm-%j.out
#SBATCH --error=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/outputs_slurm/twenty-apps/err/slurm-%j.err

# Stop Job incase an error occurs
set -e

# Load modules
module load apptainer

# --------------------------------------------------
# Configuration
# --------------------------------------------------

POSTGRES_SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/apptainer-images/postgres-16.sif"
POSTGRES_INSTANCE="twenty-apps-postgres-${SLURM_JOB_ID}"

REDIS_SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/apptainer-images/redis.sif"
REDIS_INSTANCE="twenty-apps-redis-${SLURM_JOB_ID}"

# Bind paths
POSTGRES_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/postgres"
POSTGRES_CONTAINER_DIR="/var/lib/postgresql/data"

REDIS_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/redis"
REDIS_CONTAINER_DIR="/redis"

echo "========================================"
echo "Twenty-apps-postgres Slurm Job"
echo "========================================"
echo "Job ID:        ${SLURM_JOB_ID}"
echo "Node:          $(hostname)"
echo "POSTGRES_SIF:           ${POSTGRES_SIF}"
echo "Instance:      ${POSTGRES_INSTANCE}"
echo "========================================"

# --------------------------------------------------
# Check POSTGRES_SIF
# --------------------------------------------------

if [ ! -f "${POSTGRES_SIF}" ]; then
    echo "ERROR: POSTGRES_SIF does not exist:"
    echo "${POSTGRES_SIF}"
    exit 1
fi

if [ ! -f "${REDIS_SIF}" ]; then
    echo "ERROR: POSTGRES_SIF does not exist:"
    echo "${REDIS_SIF}"
    exit 1
fiX

# --------------------------------------------------
# Start Apptainer instance
# --------------------------------------------------


apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home / \
    --writable-tmpfs \
    --bind "${POSTGRES_DIR}:${POSTGRES_CONTAINER_DIR}" \
    --env POSTGRES_DB=default \
    --env POSTGRES_USER=postgres \
    --env POSTGRES_PASSWORD=05ab9d6143d1fe891059cfe83b1fb059b0d4481851df88ddb02ef24d5890ceb6 \
    "${POSTGRES_SIF}" \
    "${POSTGRES_INSTANCE}"

apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home / \
    --writable-tmpfs \
    --bind "${REDIS_DIR}:${REDIS_CONTAINER_DIR}" \
    "${REDIS_SIF}" \
    "${REDIS_INSTANCE}"

# --------------------------------------------------
# Make sure instance is stopped when job exits
# --------------------------------------------------

cleanup() {
    echo "Stopping Postgres instance ${POSTGRES_INSTANCE}..."
    apptainer instance stop "${POSTGRES_INSTANCE}" || true
}

cleanup() {
    echo "Stopping Redis instance ${REDIS_INSTANCE}..."
    apptainer instance stop "${REDIS_INSTANCE}" || true
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
echo "  ${POSTGRES_INSTANCE}"
echo
echo "Connect with:"
echo
echo "  srun --jobid=${SLURM_JOB_ID} --pty bash"
echo
echo "Then:"
echo
echo "  apptainer exec instance://${POSTGRES_INSTANCE} bash"
echo
echo "========================================"

# --------------------------------------------------
# Keep the SLURM allocation alive
# --------------------------------------------------

sleep infinity

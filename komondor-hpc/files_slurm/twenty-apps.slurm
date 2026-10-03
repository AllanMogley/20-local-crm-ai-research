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
TWENTY_SERVER_SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/apptainer-images/twenty-server.sif"
TWENTY_SERVER_INSTANCE="twenty-apps-twenty-server-${SLURM_JOB_ID}"

# Bind paths
POSTGRES_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/postgres"
POSTGRES_CONTAINER_DIR="/var/lib/postgresql/data"
REDIS_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/redis"
REDIS_CONTAINER_DIR="/redis"
TWENTY_SERVER_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/twenty-server"
TWENTY_SERVER_CONTAINER_DIR="/twenty"

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
fi

# --------------------------------------------------
# Start Apptainer instance
# --------------------------------------------------

# POSTGRES
apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home / \
    --writable-tmpfs \
    --bind "${POSTGRES_DIR}:${POSTGRES_CONTAINER_DIR}" \
    --cleanenv \
    --env-file "/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/.env" \
    "${POSTGRES_SIF}" \
    "${POSTGRES_INSTANCE}"

sleep 20

# REDIS
apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home / \
    --writable-tmpfs \
    --cleanenv \
    --bind "${REDIS_DIR}:${REDIS_CONTAINER_DIR}" \
    "${REDIS_SIF}" \
    "${REDIS_INSTANCE}"

sleep 20
# TWENTY SERVER
apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home / \
    --writable-tmpfs \
    --cleanenv \
    --env-file "/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/.env" \
    --bind "${TWENTY_SERVER_DIR}:${TWENTY_SERVER_CONTAINER_DIR}" \
    "${TWENTY_SERVER_SIF}" \
    "${TWENTY_SERVER_INSTANCE}"

    # --network-args "portmap=3000:3000/tcp" \
# --------------------------------------------------
# Make sure instance is stopped when job exits
# --------------------------------------------------

cleanup() {
    echo "Stopping Postgres instance ${POSTGRES_INSTANCE}..."
    apptainer instance stop "${POSTGRES_INSTANCE}" || true

    echo "Stopping Redis instance ${REDIS_INSTANCE}..."
    apptainer instance stop "${REDIS_INSTANCE}" || true

    echo "Stopping Twenty-server instance ${TWENTY_SERVER_INSTANCE}..."
    apptainer instance stop "${TWENTY_SERVER_INSTANCE}" || true
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
#!/bin/bash
#SBATCH --account=nr_szetdk
#SBATCH --job-name=twenty-apps-postgres
#SBATCH --partition=cpu
#SBATCH --mem=12G
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=01:30:00
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
TWENTY_WORKER_SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/apptainer-images/twenty-worker.sif"
TWENTY_WORKER_INSTANCE="twenty-apps-twenty-worker-${SLURM_JOB_ID}"

# FRPC CONFIG
FRPC_FILE="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/frpc_client/frp_0.71.0_linux_amd64/frpc"
FRPC_TOML="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/frpc_client/frpc.toml"
FRPC_ENV="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/frpc_client/.env_frpc"

# Bind paths
POSTGRES_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/postgres"
POSTGRES_CONTAINER_DIR="/var/lib/postgresql/data"
REDIS_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/redis"
REDIS_CONTAINER_DIR="/redis"
TWENTY_SERVER_DIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/twenty-apps-volumes/twenty-server"
TWENTY_SERVER_CONTAINER_DIR="/app/packages/twenty-server/.local-storage"

# --------------------------------------------------
# Cleanup must be armed before any instance starts.
# If the job is cancelled or times out while waiting for
# Postgres, the EXIT trap stops the instances; otherwise a
# stale instance and postmaster.pid block the next run.
# --------------------------------------------------

frpc_pid=""

cleanup() {
    if [ -n "${frpc_pid}" ]; then
        echo "Stopping frpc..."
        kill "${frpc_pid}" 2>/dev/null || true
    fi

    echo "Stopping Postgres instance ${POSTGRES_INSTANCE}..."
    apptainer instance stop "${POSTGRES_INSTANCE}" || true

    echo "Stopping Redis instance ${REDIS_INSTANCE}..."
    apptainer instance stop "${REDIS_INSTANCE}" || true

    echo "Stopping Twenty-server instance ${TWENTY_SERVER_INSTANCE}..."
    apptainer instance stop "${TWENTY_SERVER_INSTANCE}" || true

    echo "Stopping Twenty-worker instance ${TWENTY_WORKER_INSTANCE}..."
    apptainer instance stop "${TWENTY_WORKER_INSTANCE}" || true
}

trap cleanup EXIT

# Bounded readiness waits: fail the job instead of looping forever.
WAIT_TRIES="${WAIT_TRIES:-60}"
WAIT_SLEEP="${WAIT_SLEEP:-2}"

wait_until() {
    local name="$1"
    shift
    local i
    for ((i = 1; i <= WAIT_TRIES; i++)); do
        if "$@" >/dev/null 2>&1; then
            echo "${name} is ready."
            return 0
        fi
        echo "Waiting for ${name}... (${i}/${WAIT_TRIES})"
        sleep "${WAIT_SLEEP}"
    done
    echo "ERROR: ${name} did not become ready after ${WAIT_TRIES} attempts." >&2
    echo "Check the Slurm .out/.err logs." >&2
    echo "If Postgres failed, inspect ${POSTGRES_DIR}/postmaster.pid and" >&2
    echo "any leftover postgres process, then remove the stale pid file." >&2
    return 1
}

if [ -f "${POSTGRES_DIR}/postmaster.pid" ]; then
    echo "WARNING: ${POSTGRES_DIR}/postmaster.pid exists."
    echo "If no postgres is running, remove it before restarting this job."
fi

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
    --env-file "/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/.env_files_slurm" \
    "${POSTGRES_SIF}" \
    "${POSTGRES_INSTANCE}"

# Wait for Postgres healthy
wait_until "PostgreSQL" \
    apptainer exec --userns instance://${POSTGRES_INSTANCE} \
    pg_isready -U postgres -h 127.0.0.1 -d default

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

# Wait for Redis healthy
wait_until "Redis" \
    apptainer exec --userns instance://${REDIS_INSTANCE} \
    redis-cli -h 127.0.0.1 ping

# TWENTY SERVER
apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home /app \
    --writable-tmpfs \
    --cleanenv \
    --env-file "/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/.env_files_slurm" \
    --bind "${TWENTY_SERVER_DIR}:${TWENTY_SERVER_CONTAINER_DIR}" \
    "${TWENTY_SERVER_SIF}" \
    "${TWENTY_SERVER_INSTANCE}"

# Wait for Twenty Server healthy
wait_until "Twenty" curl -fsS http://localhost:3000

# TWENT WORKER
apptainer instance start \
    --userns \
    --no-mount home,cwd \
    --home /app \
    --writable-tmpfs \
    --cleanenv \
    --env-file "/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/.env_files_slurm" \
    --bind "${TWENTY_SERVER_DIR}:${TWENTY_SERVER_CONTAINER_DIR}" \
    "${TWENTY_WORKER_SIF}" \
    "${TWENTY_WORKER_INSTANCE}"


# START FRPC CLIENT
# Set env variables and start frpc client
set -a
source "${FRPC_ENV}"
set +a

# Generate new TOML file to fix quotes
FRPC_GENERATED="${FRPC_TOML%.toml}.generated.toml"
envsubst < "${FRPC_TOML}" > "${FRPC_GENERATED}"
echo "FRPC_FILE=${FRPC_FILE}"
echo "FRPC_GENERATED=${FRPC_GENERATED}"
# Start frpc
"${FRPC_FILE}" --config "${FRPC_GENERATED}" > frpc.log 2>&1 &
frpc_pid=$!

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
echo "  apptainer exec --userns instance://${POSTGRES_INSTANCE} bash"
echo
echo "========================================"

# --------------------------------------------------
# Keep the SLURM allocation alive
# --------------------------------------------------

sleep infinity

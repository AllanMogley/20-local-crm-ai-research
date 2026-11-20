#!/bin/bash
#SBATCH --account=nr_szetdk
#SBATCH --job-name=llama-cpp-cuda-2-models
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_a100-sxm4-40gb:1
#SBATCH --mem=24G
#SBATCH --time=01:30:00
#SBATCH --mail-type=ALL
#SBATCH --mail-user=EMAIL
#SBATCH --output=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/outputs_slurm/llama/out/slurm-%j.out
#SBATCH --error=/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/outputs_slurm/llama/err/slurm-%j.err

# Stop Job incase an error occurs
set -e

# Load modules
module load apptainer

# --------------------------------------------------
# Configuration
# --------------------------------------------------

SIF="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/apptainer-images/llama-cpp-cuda.sif"
INSTANCE="llama-${SLURM_JOB_ID}"
WORKDIR="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/models"

# MODEL DIRS
USER_MODEL="/work/Qwen/Qwen3.5-9B-UD-Q4_K_XL.gguf"      # User simulator
AGENT_MODEL="/work/Qwen/Qwen3.5-9B-UD-Q4_K_XL.gguf"  # Agent
# AGENT_MODEL="/work/Gpt-oss/gpt-oss-20b-UD-Q4_K_XL.gguf"  # Agent

# Both servers run in the same Apptainer instance on different ports.
USER_PORT=8080
AGENT_PORT=8081
USER_ALIAS="$(basename "${USER_MODEL}")"
AGENT_ALIAS="$(basename "${AGENT_MODEL}")"
CTX_SIZE="${CTX_SIZE:-32768}"

USER_PID=""
AGENT_PID=""

# --------------------------------------------------
# Make sure the servers and instance stop when the job exits
# --------------------------------------------------

cleanup() {
    echo "Stopping llama servers and Apptainer instance ${INSTANCE}..."
    if [ -n "${USER_PID}" ]; then
        kill "${USER_PID}" 2>/dev/null || true
    fi
    if [ -n "${AGENT_PID}" ]; then
        kill "${AGENT_PID}" 2>/dev/null || true
    fi
    apptainer instance stop "${INSTANCE}" || true
}
trap cleanup EXIT

echo "========================================"
echo "llama.cpp Slurm Job (user + agent)"
echo "========================================"
echo "Job ID:        ${SLURM_JOB_ID}"
echo "Node:          $(hostname)"
echo "GPU:"
nvidia-smi
echo "SIF:           ${SIF}"
echo "Instance:      ${INSTANCE}"
echo "User model:    ${USER_MODEL}"
echo "User port:     ${USER_PORT}"
echo "Agent model:   ${AGENT_MODEL}"
echo "Agent port:    ${AGENT_PORT}"
echo "Context size:  ${CTX_SIZE}"
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

# --nv -> mounts nvidia CUDA libraries
apptainer instance start \
    --userns \
    --nv \
    --no-mount home,cwd \
    --bind "${WORKDIR}:/work" \
    "${SIF}" \
    "${INSTANCE}"

# --------------------------------------------------
# Start the user model server
# --------------------------------------------------

echo
echo "Starting user model on port ${USER_PORT}..."

apptainer exec --userns instance://"${INSTANCE}" \
    llama serve \
        -m "${USER_MODEL}" \
        --alias "${USER_ALIAS}" \
        --host 0.0.0.0 \
        --port "${USER_PORT}" \
        -c "${CTX_SIZE}" \
        -np 1 \
        -ngl 999 \
        -sm none \
        --jinja &
USER_PID=$!

# --------------------------------------------------
# Start the agent model server
# --------------------------------------------------

echo "Starting agent model on port ${AGENT_PORT}..."

apptainer exec --userns instance://"${INSTANCE}" \
    llama serve \
        -m "${AGENT_MODEL}" \
        --alias "${AGENT_ALIAS}" \
        --host 0.0.0.0 \
        --port "${AGENT_PORT}" \
        -c "${CTX_SIZE}" \
        -np 1 \
        -ngl 999 \
        -sm none \
        --jinja &
AGENT_PID=$!

# --------------------------------------------------
# Wait for both servers
# --------------------------------------------------

wait_ready() {
    local name="$1"
    local port="$2"
    local pid="$3"
    local i

    for i in $(seq 1 180); do
        if ! kill -0 "${pid}" 2>/dev/null; then
            echo "ERROR: ${name} server exited during startup."
            return 1
        fi
        if curl -fsS "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
            echo "${name} server is ready on port ${port}."
            return 0
        fi
        sleep 5
    done

    echo "ERROR: ${name} server did not become ready in 15 minutes."
    return 1
}

wait_ready "user" "${USER_PORT}" "${USER_PID}"
wait_ready "agent" "${AGENT_PORT}" "${AGENT_PID}"

echo
echo "========================================"
echo "Both model servers are running"
echo "========================================"
echo
echo "Node:"
echo "  $(hostname)"
echo
echo "User model endpoint:"
echo "  http://$(hostname):${USER_PORT}/v1"
echo "  model id: openai/${USER_ALIAS}"
echo
echo "Agent model endpoint:"
echo "  http://$(hostname):${AGENT_PORT}/v1"
echo "  model id: openai/${AGENT_ALIAS}"
echo
echo "Check from the tau2 node:"
echo "  curl http://$(hostname):${USER_PORT}/v1/models"
echo "  curl http://$(hostname):${AGENT_PORT}/v1/models"
echo
echo "The job stays alive while either server is running."
echo "========================================"

# If one server dies, stop the job and clean up the other.
wait -n "${USER_PID}" "${AGENT_PID}"

#!/usr/bin/bash
FRPC_ENV="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/.env_files_slurm"
CRM_ENVIRONMENT_ENV="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/crm-environment/.crm_environment_env"
OPENCODE_JSON="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/opencode/.opencode/opencode.json"
TAU2_BENCH_ENV="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/crm-environment/tau2-bench-copy/.env"

LLAMA_SLURM="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/llama-cpp-cuda-2-models.slurm"
OPENCODE_SLURM="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/opencode.slurm"
TWENTY_SLURM="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/twenty-apps.slurm"
TAU2_SLURM="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/tau-bench.slurm"

# Ports used by the dual-model llama.cpp job.
USER_PORT=8080
AGENT_PORT=8081

# Submit LLAMA Job
LLAMA_JOB=$(sbatch --parsable "${LLAMA_SLURM}")
echo "Submitted LLAMA job: ${LLAMA_JOB}"

# Wait for LLAMA to start
while true; do
    STATE=$(squeue -h -j "${LLAMA_JOB}" -o "%T")

    if [[ "$STATE" == "RUNNING" ]]; then
        NODE=$(squeue -h -j "${LLAMA_JOB}" -o "%N")
        echo "LLAMA is running on node: ${NODE}"
        echo "${NODE}" > llama_node.txt
        break
    elif [[ -z "$STATE" ]]; then
        echo "LLAMA job ${LLAMA_JOB} is no longer in the queue."
        exit 1
    else
        echo "LLAMA job ${LLAMA_JOB} state: ${STATE}"
    fi
    sleep 10
done

# Submit the other jobs
OPENCODE_JOB=$(sbatch --parsable "${OPENCODE_SLURM}")
TWENTY_JOB=$(sbatch --parsable "${TWENTY_SLURM}")
TAU2_JOB=$(sbatch --parsable "${TAU2_SLURM}")

echo "Submitted OpenCode job: ${OPENCODE_JOB}"
echo "Submitted Twenty job: ${TWENTY_JOB}"

# Wait until both llama servers finish loading. RUNNING only means the job
# started; the models can take several minutes to become ready.
for PORT in "${USER_PORT}" "${AGENT_PORT}"; do
    echo "Waiting for llama server on ${NODE}:${PORT}..."
    READY=0
    for _ in $(seq 1 180); do
        if curl -fsS "http://${NODE}:${PORT}/health" >/dev/null 2>&1; then
            READY=1
            break
        fi
        sleep 5
    done

    if [ "${READY}" -ne 1 ]; then
        echo "ERROR: llama server on ${NODE}:${PORT} did not become ready."
        exit 1
    fi
done
echo "Both llama servers are ready."

# Publish the current llama endpoints for tau2.
sed -i '/^LLAMA_NODE=/d;/^LLAMA_USER_BASE_URL=/d;/^LLAMA_AGENT_BASE_URL=/d' "${TAU2_BENCH_ENV}"
{
    echo ""
    echo "LLAMA_NODE=${NODE}"
    echo "LLAMA_USER_BASE_URL=http://${NODE}:${USER_PORT}/v1"
    echo "LLAMA_AGENT_BASE_URL=http://${NODE}:${AGENT_PORT}/v1"
} >> "${TAU2_BENCH_ENV}"

# Set .env variables
set -a
source "${FRPC_ENV}"
set +a

# Update opencode.json to the user model on port 8080.
sed -i -E "s|(\"baseURL\"[[:space:]]*:[[:space:]]*\"http://)[^:\"]*(:[0-9]+)?|\1${NODE}:${USER_PORT}|" "${OPENCODE_JSON}"

# Update the tau2-bench user model endpoint. The agent model runs on port 8081;
# its base URL is available as LLAMA_AGENT_BASE_URL in the same .env file.
sed -i -E "/^OPENAI_BASE_URL=/s#^(OPENAI_BASE_URL=http://)[^:/]+(:[0-9]+)?#\1${NODE}:${USER_PORT}#" "${TAU2_BENCH_ENV}"

# Wait until all three are RUNNING
while true; do
    LLAMA_STATE=$(squeue -h -j "${LLAMA_JOB}" -o "%T")
    OPENCODE_STATE=$(squeue -h -j "${OPENCODE_JOB}" -o "%T")
    TWENTY_STATE=$(squeue -h -j "${TWENTY_JOB}" -o "%T")
    TAU2_STATE=$(squeue -h -j "${TAU2_JOB}" -o "%T")

    echo "LLAMA${LLAMA_STATE} OpenCode${OPENCODE_STATE} Twenty${TWENTY_STATE}"

    if [[ "$LLAMA_STATE" == "RUNNING" &&
          "$OPENCODE_STATE" == "RUNNING" &&
          "$TWENTY_STATE" == "RUNNING" &&
          "$TAU2_STATE" == "RUNNING" ]]; then
        echo "All jobs are RUNNING."

        # Get TWENTY NODE NAME
        TWENTY_NODE=$(squeue -h -j "${TWENTY_JOB}" -o "%N")
        # Update Twenty Node Name in crm-environment-env and tau2-bench files
        sed -i "s|^\(TWENTY_HOSTNAME='\)[^']*|\1${TWENTY_NODE}|" "${CRM_ENVIRONMENT_ENV}"
        sed -i "/^TWENTY_MCP_URL=/s|\(http://\)[^:/]*|\1${TWENTY_NODE}|" "${TAU2_BENCH_ENV}"
        sed -i "/^TWENTY_DB_URL=/s|\(@\)[^:]*:|\1${TWENTY_NODE}:|" "${TAU2_BENCH_ENV}"
        # Send Email
        mail -s "HPC jobs are running" "${MY_EMAIL}" <<EOF

All HPC jobs are now RUNNING.

LLAMA JOB   :   ${LLAMA_JOB}
OpenCodeJOB :   ${OPENCODE_JOB}
TwentyJOB   :   ${TWENTY_JOB}
Tau2JOB     :   ${TAU2_JOB}

LLAMA node        :   $(cat llama_node.txt)
LLAMA user model  :   http://${NODE}:${USER_PORT}/v1
LLAMA agent model :   http://${NODE}:${AGENT_PORT}/v1
OpenCode Json Updated
EOF
        break
    fi
    sleep 10
done

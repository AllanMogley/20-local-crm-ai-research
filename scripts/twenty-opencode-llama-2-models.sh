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

job_state() {
    local id="$1"
    local state
    state=$(squeue -h -j "${id}" -o "%T" 2>/dev/null | head -1)
    if [ -z "${state}" ]; then
        state=$(scontrol show job "${id}" 2>/dev/null |
            sed -n 's/.*JobState=\([^ ]*\).*/\1/p' | head -1)
    fi
    printf '%s' "${state}"
}

job_node() {
    local id="$1"
    local node
    node=$(squeue -h -j "${id}" -o "%N" 2>/dev/null | head -1)
    if [ -z "${node}" ]; then
        node=$(scontrol show job "${id}" 2>/dev/null |
            sed -n 's/.* NodeList=\([^ ]*\).*/\1/p' | head -1)
    fi
    if [ "${node}" = "(null)" ]; then
        node=""
    fi
    printf '%s' "${node}"
}

# Submit LLAMA Job
LLAMA_JOB=$(sbatch --parsable "${LLAMA_SLURM}")
echo "Submitted LLAMA job: ${LLAMA_JOB}"

# Wait for LLAMA to start
while true; do
    STATE=$(job_state "${LLAMA_JOB}")

    if [ "${STATE}" = "RUNNING" ]; then
        NODE=$(job_node "${LLAMA_JOB}")
        if [ -z "${NODE}" ]; then
            echo "ERROR: LLAMA job is running but its node is unknown."
            exit 1
        fi
        echo "LLAMA is running on node: ${NODE}"
        echo "${NODE}" > llama_node.txt
        break
    elif [ -z "${STATE}" ] || [ "${STATE}" = "CANCELLED" ] ||
         [ "${STATE}" = "FAILED" ] || [ "${STATE}" = "COMPLETED" ] ||
         [ "${STATE}" = "TIMEOUT" ] || [ "${STATE}" = "NODE_FAIL" ] ||
         [ "${STATE}" = "OUT_OF_MEMORY" ] || [ "${STATE}" = "PREEMPTED" ]; then
        echo "LLAMA job ${LLAMA_JOB} is not running (state: ${STATE:-gone})."
        echo "Check: sacct -j ${LLAMA_JOB} --format=JobID,JobName%24,State,ExitCode"
        exit 1
    else
        echo "LLAMA job ${LLAMA_JOB} state: ${STATE}"
    fi
    sleep 10
done

# Update the llama URLs immediately after the node is known. These no longer
# depend on the /health checks below.
sed -i '/^LLAMA_NODE=/d;/^LLAMA_USER_BASE_URL=/d;/^LLAMA_AGENT_BASE_URL=/d' "${TAU2_BENCH_ENV}"
{
    echo ""
    echo "LLAMA_NODE=${NODE}"
    echo "LLAMA_USER_BASE_URL=http://${NODE}:${USER_PORT}/v1"
    echo "LLAMA_AGENT_BASE_URL=http://${NODE}:${AGENT_PORT}/v1"
} >> "${TAU2_BENCH_ENV}"

sed -i -E "/^OPENAI_BASE_URL=/s#^(OPENAI_BASE_URL=http://)[^:/]+(:[0-9]+)?(/v1)?.*#\1${NODE}:${USER_PORT}/v1#" "${TAU2_BENCH_ENV}"

# Update opencode.json to the user model on port 8080.
sed -i -E "s|(\"baseURL\"[[:space:]]*:[[:space:]]*\"http://)[^:\"]*(:[0-9]+)?|\1${NODE}:${USER_PORT}|" "${OPENCODE_JSON}"

echo "LLAMA endpoints written to ${TAU2_BENCH_ENV}:"
grep -E '^(OPENAI_BASE_URL|LLAMA_NODE|LLAMA_USER_BASE_URL|LLAMA_AGENT_BASE_URL)=' "${TAU2_BENCH_ENV}" || true

if ! grep -q "^OPENAI_BASE_URL=http://${NODE}:${USER_PORT}/v1$" "${TAU2_BENCH_ENV}"; then
    echo "ERROR: OPENAI_BASE_URL was not updated. Current line:"
    grep '^OPENAI_BASE_URL=' "${TAU2_BENCH_ENV}" | cat -A
    exit 1
fi

# Submit the other jobs
OPENCODE_JOB=$(sbatch --parsable "${OPENCODE_SLURM}")
TWENTY_JOB=$(sbatch --parsable "${TWENTY_SLURM}")
TAU2_JOB=$(sbatch --parsable "${TAU2_SLURM}")

echo "Submitted OpenCode job: ${OPENCODE_JOB}"
echo "Submitted Twenty job: ${TWENTY_JOB}"

# Wait until both llama servers finish loading. RUNNING only means the job
# started; the models can take several minutes to become ready.
LLAMA_READY=1
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
        echo "WARNING: llama server on ${NODE}:${PORT} did not become ready."
        LLAMA_READY=0
    fi
done
if [ "${LLAMA_READY}" -eq 1 ]; then
    echo "Both llama servers are ready."
fi

# Set .env variables
set -a
source "${FRPC_ENV}"
set +a

# Wait for Twenty and update its host as soon as it is RUNNING. If the job
# finished, fall back to scontrol so the node is still recorded.
TWENTY_NODE=""
TWENTY_STATE=""
while true; do
    TWENTY_STATE=$(job_state "${TWENTY_JOB}")
    TWENTY_NODE=$(job_node "${TWENTY_JOB}")

    if [ "${TWENTY_STATE}" = "RUNNING" ] && [ -n "${TWENTY_NODE}" ]; then
        echo "Twenty is running on node: ${TWENTY_NODE}"
        break
    elif [ -n "${TWENTY_NODE}" ]; then
        echo "WARNING: Twenty job state is ${TWENTY_STATE:-gone}; using node ${TWENTY_NODE}."
        break
    elif [ -z "${TWENTY_STATE}" ] || [ "${TWENTY_STATE}" = "CANCELLED" ] ||
         [ "${TWENTY_STATE}" = "FAILED" ] || [ "${TWENTY_STATE}" = "COMPLETED" ] ||
         [ "${TWENTY_STATE}" = "TIMEOUT" ] || [ "${TWENTY_STATE}" = "NODE_FAIL" ] ||
         [ "${TWENTY_STATE}" = "OUT_OF_MEMORY" ] || [ "${TWENTY_STATE}" = "PREEMPTED" ]; then
        echo "ERROR: Twenty job ${TWENTY_JOB} is not running (state: ${TWENTY_STATE:-gone})."
        echo "Check: sacct -j ${TWENTY_JOB} --format=JobID,JobName%24,State,ExitCode,NodeList"
        exit 1
    else
        echo "Twenty job ${TWENTY_JOB} state: ${TWENTY_STATE}"
    fi
    sleep 10
done

# Update Twenty Node Name in crm-environment-env and tau2-bench files.
sed -i "s|^\(TWENTY_HOSTNAME='\)[^']*|\1${TWENTY_NODE}|" "${CRM_ENVIRONMENT_ENV}"
sed -i "/^TWENTY_MCP_URL=/s|\(http://\)[^:/]*|\1${TWENTY_NODE}|" "${TAU2_BENCH_ENV}"
sed -i "/^TWENTY_DB_URL=/s|\(@\)[^:]*:|\1${TWENTY_NODE}:|" "${TAU2_BENCH_ENV}"

echo "Twenty endpoints written:"
grep -E '^(TWENTY_MCP_URL|TWENTY_DB_URL)=' "${TAU2_BENCH_ENV}" || true
grep '^TWENTY_HOSTNAME=' "${CRM_ENVIRONMENT_ENV}" || true

if ! grep -q "^TWENTY_MCP_URL=http://${TWENTY_NODE}:" "${TAU2_BENCH_ENV}"; then
    echo "ERROR: TWENTY_MCP_URL was not updated. Current line:"
    grep '^TWENTY_MCP_URL=' "${TAU2_BENCH_ENV}" | cat -A
    exit 1
fi
if ! grep -q "^TWENTY_DB_URL=.*@${TWENTY_NODE}:" "${TAU2_BENCH_ENV}"; then
    echo "ERROR: TWENTY_DB_URL was not updated. Current line:"
    grep '^TWENTY_DB_URL=' "${TAU2_BENCH_ENV}" | cat -A
    exit 1
fi

# Report the other job states once. Do not loop forever on finished jobs.
LLAMA_STATE=$(job_state "${LLAMA_JOB}")
OPENCODE_STATE=$(job_state "${OPENCODE_JOB}")
TAU2_STATE=$(job_state "${TAU2_JOB}")

echo "LLAMA${LLAMA_STATE} OpenCode${OPENCODE_STATE} Twenty${TWENTY_STATE} Tau2${TAU2_STATE}"

if [[ "$LLAMA_STATE" == "RUNNING" &&
      "$OPENCODE_STATE" == "RUNNING" &&
      "$TWENTY_STATE" == "RUNNING" &&
      "$TAU2_STATE" == "RUNNING" ]]; then
    echo "All jobs are RUNNING."

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
Twenty node       :   ${TWENTY_NODE}
OpenCode Json Updated
EOF
else
    echo "WARNING: not all jobs are RUNNING; check squeue/sacct."
fi
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

# States after which a job will never come back.
TERMINAL_STATES=" COMPLETED FAILED CANCELLED TIMEOUT NODE_FAIL OUT_OF_MEMORY PREEMPTED BOOT_FAIL DEADLINE REVOKED SPECIAL_EXIT "

# Submit a job and return only its numeric ID. sbatch's own messages
# (e.g. "also queued in cpu-short") still go to the terminal. Some sites
# return "<id>;<cluster>" from --parsable, so strip anything after ';'.
submit_job() {
    local file="$1" raw id
    raw=$(sbatch --parsable "${file}") || {
        echo "ERROR: sbatch failed for ${file}" >&2
        return 1
    }
    id=$(printf '%s\n' "${raw}" | sed -nE 's/^([0-9]+).*/\1/p' | tail -1)
    if [ -z "${id}" ]; then
        echo "ERROR: sbatch returned no job id for ${file} (got '${raw}')." >&2
        return 1
    fi
    printf '%s' "${id}"
}

# Query one field of a job. squeue only knows jobs that are still in the
# queue, so fall back to scontrol and then sacct for finished jobs. All
# Slurm errors are silenced: "slurm_load_jobs error: Invalid job id
# specified" simply means the job is no longer in the queue.
job_field() {
    local id="$1" fmt="$2" val=""
    val=$(squeue -h -j "${id}" -o "${fmt}" 2>/dev/null | head -1)
    if [ -z "${val}" ] && command -v scontrol >/dev/null 2>&1; then
        if [ "${fmt}" = "%T" ]; then
            val=$(scontrol show job "${id}" 2>/dev/null |
                sed -n 's/.*JobState=\([^ ]*\).*/\1/p' | head -1)
        else
            val=$(scontrol show job "${id}" 2>/dev/null |
                sed -n 's/.* NodeList=\([^ ]*\).*/\1/p' | head -1)
        fi
    fi
    if [ -z "${val}" ] && command -v sacct >/dev/null 2>&1; then
        if [ "${fmt}" = "%T" ]; then
            val=$(sacct -n -X -j "${id}" --format=State 2>/dev/null |
                awk '{print $1}' | head -1)
        else
            val=$(sacct -n -X -j "${id}" --format=NodeList 2>/dev/null |
                awk '{print $1}' | head -1)
        fi
    fi
    case "${val}" in
        "(null)"|"None"|"None assigned"|"n/a"|"") val="" ;;
    esac
    if [ "${fmt}" = "%T" ]; then
        # Ignore anything that is not a plain Slurm state name.
        [[ "${val}" =~ ^[A-Z][A-Z_]*$ ]] || val=""
    else
        [[ "${val}" =~ ^[A-Za-z0-9._-]+$ ]] || val=""
    fi
    printf '%s' "${val}"
}

job_state() { job_field "$1" "%T"; }
job_node()  { job_field "$1" "%N"; }

# Block until a job is RUNNING and has a node. Exits with an error if the
# job finishes or disappears from Slurm. The result node is stored in the
# variable named by $3.
wait_for_running() {
    local id="$1" name="$2" outvar="$3"
    local state node misses=0
    while true; do
        state=$(job_state "${id}")
        node=$(job_node "${id}")

        if [ "${state}" = "RUNNING" ] && [ -n "${node}" ]; then
            printf -v "${outvar}" '%s' "${node}"
            return 0
        fi

        case "${TERMINAL_STATES}" in
            *" ${state} "*)
                echo "ERROR: ${name} job ${id} ended in state ${state}." >&2
                echo "Check: sacct -j ${id} --format=JobID,JobName%24,State,ExitCode,NodeList" >&2
                return 1
                ;;
        esac

        if [ -z "${state}" ]; then
            misses=$((misses + 1))
            if [ "${misses}" -ge 3 ]; then
                echo "ERROR: ${name} job ${id} is unknown to Slurm (finished or purged)." >&2
                echo "Check: sacct -j ${id} --format=JobID,JobName%24,State,ExitCode,NodeList" >&2
                return 1
            fi
        else
            misses=0
            printf '%s job %s state: %s\n' "${name}" "${id}" "${state}"
        fi
        sleep 10
    done
}

# Submit LLAMA job
LLAMA_JOB=$(submit_job "${LLAMA_SLURM}") || exit 1
echo "Submitted LLAMA job: ${LLAMA_JOB}"

# Wait for LLAMA to start
wait_for_running "${LLAMA_JOB}" LLAMA NODE || exit 1
echo "LLAMA is running on node: ${NODE}"
echo "${NODE}" > llama_node.txt

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
OPENCODE_JOB=$(submit_job "${OPENCODE_SLURM}") || exit 1
TWENTY_JOB=$(submit_job "${TWENTY_SLURM}") || exit 1
TAU2_JOB=$(submit_job "${TAU2_SLURM}") || exit 1

echo "Submitted OpenCode job: ${OPENCODE_JOB}"
echo "Submitted Twenty job: ${TWENTY_JOB}"
echo "Submitted Tau2 job: ${TAU2_JOB}"

# Wait until both llama servers finish loading. RUNNING only means the job
# started; the models can take several minutes to become ready.
LLAMA_READY=1
for PORT in "${USER_PORT}" "${AGENT_PORT}"; do
    echo "Waiting for llama server on ${NODE}:${PORT}..."
    READY=0
    MISSES=0
    for i in $(seq 1 180); do
        if curl -fsS --connect-timeout 3 --max-time 5 \
            "http://${NODE}:${PORT}/health" >/dev/null 2>&1; then
            READY=1
            break
        fi

        # Make sure the llama job is still alive while the model loads.
        STATE=$(job_state "${LLAMA_JOB}")
        case "${TERMINAL_STATES}" in
            *" ${STATE} "*)
                echo "ERROR: LLAMA job ${LLAMA_JOB} ended in state ${STATE} while loading."
                exit 1
                ;;
        esac
        if [ -z "${STATE}" ]; then
            MISSES=$((MISSES + 1))
            if [ "${MISSES}" -ge 3 ]; then
                echo "ERROR: LLAMA job ${LLAMA_JOB} is gone (cancelled or purged) while loading."
                exit 1
            fi
        else
            MISSES=0
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

# Wait for Twenty to be RUNNING. wait_for_running fails instead of looping
# forever if the job dies or is purged from Slurm.
wait_for_running "${TWENTY_JOB}" Twenty TWENTY_NODE || exit 1
echo "Twenty is running on node: ${TWENTY_NODE}"

# Replace the host in a KEY=<scheme>://host[:port][/path] line. Tolerates an
# optional "export ", surrounding quotes, spaces, https and CRLF.
set_url_host() {
    local key="$1" host="$2" file="$3"
    if ! grep -qE "^[[:space:]]*(export[[:space:]]+)?${key}=" "${file}"; then
        echo "WARNING: ${key} not found in ${file}" >&2
        return 1
    fi
    sed -i -E "/^[[:space:]]*(export[[:space:]]+)?${key}=/s#(://)[^:/\"']+#\1${host}#" "${file}"
}

# Replace the host in a KEY=...://user:pass@host[:port]/db line. The greedy
# ".*@" targets the last @, so passwords containing @ are preserved.
set_db_host() {
    local key="$1" host="$2" file="$3"
    if ! grep -qE "^[[:space:]]*(export[[:space:]]+)?${key}=" "${file}"; then
        echo "WARNING: ${key} not found in ${file}" >&2
        return 1
    fi
    sed -i -E "/^[[:space:]]*(export[[:space:]]+)?${key}=/s#(.*@)[^:@/\"']+#\1${host}#" "${file}"
}

# Update Twenty Node Name in crm-environment-env and tau2-bench files.
sed -i 's/\r$//' "${TAU2_BENCH_ENV}"
sed -i "s|^\(TWENTY_HOSTNAME='\)[^']*|\1${TWENTY_NODE}|" "${CRM_ENVIRONMENT_ENV}"
set_url_host TWENTY_MCP_URL "${TWENTY_NODE}" "${TAU2_BENCH_ENV}"
set_db_host TWENTY_DB_URL "${TWENTY_NODE}" "${TAU2_BENCH_ENV}"

echo "Twenty endpoints written:"
grep -E '^[[:space:]]*(export[[:space:]]+)?(TWENTY_MCP_URL|TWENTY_DB_URL)=' "${TAU2_BENCH_ENV}" || true
grep '^TWENTY_HOSTNAME=' "${CRM_ENVIRONMENT_ENV}" || true

if ! grep -qE "^[[:space:]]*(export[[:space:]]+)?TWENTY_MCP_URL=[\"']?https?://${TWENTY_NODE}[:/\"']" "${TAU2_BENCH_ENV}"; then
    echo "ERROR: TWENTY_MCP_URL was not updated. Current line:"
    grep -E 'TWENTY_MCP_URL=' "${TAU2_BENCH_ENV}" | cat -A
    exit 1
fi
if ! grep -qE "^[[:space:]]*(export[[:space:]]+)?TWENTY_DB_URL=.*@${TWENTY_NODE}[:/\"']" "${TAU2_BENCH_ENV}"; then
    echo "ERROR: TWENTY_DB_URL was not updated. Current line:"
    grep -E 'TWENTY_DB_URL=' "${TAU2_BENCH_ENV}" | cat -A
    exit 1
fi

# Report the other job states once. Do not loop forever on finished jobs.
LLAMA_STATE=$(job_state "${LLAMA_JOB}")
OPENCODE_STATE=$(job_state "${OPENCODE_JOB}")
TAU2_STATE=$(job_state "${TAU2_JOB}")
TWENTY_STATE=$(job_state "${TWENTY_JOB}")

echo "LLAMA=${LLAMA_STATE:-unknown} OpenCode=${OPENCODE_STATE:-unknown} Twenty=${TWENTY_STATE:-unknown} Tau2=${TAU2_STATE:-unknown}"

if [[ "${LLAMA_STATE}" == "RUNNING" &&
      "${OPENCODE_STATE}" == "RUNNING" &&
      "${TWENTY_STATE}" == "RUNNING" &&
      "${TAU2_STATE}" == "RUNNING" ]]; then
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
    echo "Check: sacct -j ${LLAMA_JOB},${OPENCODE_JOB},${TWENTY_JOB},${TAU2_JOB} --format=JobID,JobName%24,State,ExitCode,NodeList"
fi


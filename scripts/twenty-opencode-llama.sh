#!/usr/bin/bash
FRPC_ENV="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/.env_files_slurm"
CRM_ENVIRONMENT_ENV="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/crm-environment/.crm_environment_env"
OPENCODE_JSON="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/opencode/.opencode/opencode.json"

LLAMA_SLURM="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/llama-cpp-cuda.slurm"
OPENCODE_SLURM="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/opencode.slurm"
TWENTY_SLURM="/home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/twenty-apps.slurm"

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

echo "Submitted OpenCode job: ${OPENCODE_JOB}"
echo "Submitted Twenty job: ${TWENTY_JOB}"

# Set .env variables
set -a
source "${FRPC_ENV}"
set +a

# Update opencode.json
sed -i "s|\(\"baseURL\"[[:space:]]*:[[:space:]]*\"http://\)[^:\"]*:8080|\1${NODE}:8080|" "${OPENCODE_JSON}"

# Wait until all three are RUNNING
while true; do
    LLAMA_STATE=$(squeue -h -j "${LLAMA_JOB}" -o "%T")
    OPENCODE_STATE=$(squeue -h -j "${OPENCODE_JOB}" -o "%T")
    TWENTY_STATE=$(squeue -h -j "${TWENTY_JOB}" -o "%T")

    echo "LLAMA${LLAMA_STATE} OpenCode${OPENCODE_STATE} Twenty${TWENTY_STATE}"

    if [[ "$LLAMA_STATE" == "RUNNING" &&
          "$OPENCODE_STATE" == "RUNNING" &&
          "$TWENTY_STATE" == "RUNNING" ]]; then
        echo "All jobs are RUNNING."
        # Get TWENTY NODE NAME
        TWENTY_NODE=$(squeue -h -j "${TWENTY_JOB}" -o "%N")
        # Update Twenty Node Name in crm-environment-env file
        sed -i "s|^\(TWENTY_HOSTNAME='\)[^']*|\1${TWENTY_NODE}|" "${CRM_ENVIRONMENT_ENV}"
        # Send Email
        mail -s "HPC jobs are running" "${MY_EMAIL}" <<EOF

All HPC jobs are now RUNNING.

LLAMA JOB   :   ${LLAMA_JOB}
OpenCodeJOB :   ${OPENCODE_JOB}
TwentyJOB   :   ${TWENTY_JOB}

LLAMA node: $(cat llama_node.txt)
OpenCode Json Updated
EOF
        break
    fi
    sleep 10
done

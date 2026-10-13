#!/usr/bin/bash
sbatch /home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/llama-cpp-cuda.slurm
sbatch /home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/opencode.slurm


LLAMA_JOB=$(sbatch --parsable \
    /home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/llama-cpp-cuda.slurm)
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
OPENCODE_JOB=$(sbatch --parsable \
    /home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/opencode.slurm)

echo "Submitted OpenCode job: ${OPENCODE_JOB}"

# Wait until all three are RUNNING
while true; do
    LLAMA_STATE=$(squeue -h -j "${LLAMA_JOB}" -o "%T")
    OPENCODE_STATE=$(squeue -h -j "${OPENCODE_JOB}" -o "%T")

    echo "LLAMA=${LLAMA_STATE} OpenCode=${OPENCODE_STATE}

    if [[ "$LLAMA_STATE" == "RUNNING" &&
          "$OPENCODE_STATE" == "RUNNING"]]; then

        echo "All jobs are RUNNING."

        mail -s "HPC jobs are running" "${MY_EMAIL}" <<EOF
All HPC jobs are now RUNNING.

LLAMA:    ${LLAMA_JOB}
OpenCode: ${OPENCODE_JOB}
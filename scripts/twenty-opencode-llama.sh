#!/usr/bin/bash
sbatch /home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/llama-cpp-cuda.slurm

# Find the first pending/running llama job
JOB_ID=$(squeue -h -u nr_szww -o "%A %j" | awk '$2 ~ /^llama-/ {print $1; exit}')

echo "Watching job $JOB_ID..."

while true; do
    STATE=$(squeue -h -j "$JOB_ID" -o "%T")

    if [[ "$STATE" == "RUNNING" ]]; then
        NODE=$(squeue -h -j "$JOB_ID" -o "%N")

        echo "LLAMA is running on node: $NODE"

        # Store the node name
        echo "$NODE" > llama_node.txt

        # Submit other jobs
        sbatch /home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/opencode.slurm
        sbatch /home/nr_szww/nr_szetdk/allan_wanjala/komondor-hpc/komondor-hpc/files_slurm/twenty-apps.slurm

        break
    elif [[ -z "$STATE" ]]; then
        echo "Job $JOB_ID is no longer in the queue."
        exit 1
    else
        echo "Job $JOB_ID state: $STATE"
    fi

    sleep 10
done




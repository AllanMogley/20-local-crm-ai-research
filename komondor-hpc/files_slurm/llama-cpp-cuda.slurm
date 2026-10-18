#!/bin/bash
#SBATCH --account=nr_szetdk
#SBATCH --job-name=llama-cpp-cuda
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_a100-sxm4-40gb:1
#SBATCH --mem=32G
#SBATCH --time=00:40:00
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
# MODEL_DIR="/work/Kimi/Kimi-Linear-48B-A3B-Instruct-Q8_0.gguf" # Kimi-Linear
# MODEL_DIR="/work/Coding-models/Qwen3-Coder-Next-Q4_K_M.gguf" # QwenCoder

echo "========================================"
echo "Ollama Slurm Job"
echo "========================================"
echo "Job ID:        ${SLURM_JOB_ID}"
echo "Node:          $(hostname)"
echo "GPU:"
nvidia-smi
echo "SIF:           ${SIF}"
echo "Instance:      ${INSTANCE}"
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

apptainer exec --userns instance://"${INSTANCE}" bash -c 'llama serve -m /work/models/Qwen/Qwen3.8-27B-UD-IQ2_XXS.gguf -rea on --host 0.0.0.0'

# apptainer exec --userns instance://"${INSTANCE}" bash -c "
#     llama serve \
#         -m '${MODEL_DIR}' \
#         --split-mode layer \
#         --tensor-split 1,1 \
#         -ngl 999 \
#         --jinja \
#         --host 0.0.0.0"
        # -rea on \

# --------------------------------------------------
# Make sure instance is stopped when job exits
# --------------------------------------------------

cleanup() {
    echo "Stopping Apptainer instance ${INSTANCE}..."
    apptainer instance stop "${INSTANCE}" || true
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
echo "  ${INSTANCE}"
echo
echo "Connect with:"
echo
echo "  srun --jobid=${SLURM_JOB_ID} --pty bash"
echo
echo "Then:"
echo
echo "  apptainer exec instance://${INSTANCE} bash"
echo
echo "========================================"

# --------------------------------------------------
# Keep the SLURM allocation alive
# --------------------------------------------------

sleep infinity

# LLM Quantization & Local Inference Papers

**Total: 12 papers**
**Source: arXiv (open access)**
**Theme: LLM quantization, local inference, llama.cpp/GGUF, CPU/GPU, KV cache, personal-PC hardware**

| # | Title | arXiv ID | Focus |
|---|-------|----------|-------|
| 1 | Which Quantization Should I Use? A Unified Evaluation of llama.cpp Quantization on Llama-3.1-8B-Instruct | 2601.14277 | llama.cpp, K-quant (3-8 bit), perplexity, CPU throughput, Llama-3.1-8B |
| 2 | GGUF-Metadata Prediction of Single-Sequence llama.cpp Throughput Across Three Systems | 2609.14864 | GGUF, llama.cpp, roofline throughput, Apple M4 Max + RTX 5080 |
| 3 | Production-Grade Local LLM Inference on Apple Silicon | 2511.05502 | MLX/MLC-LLM/Ollama/llama.cpp/MPS, Qwen-2.5, TTFT, KV cache |
| 4 | A Comprehensive Evaluation of Quantization Strategies for Large Language Models | 2402.16775 | quantization quality, perplexity vs accuracy, 4-bit, memory/speed tradeoff |
| 5 | The Illusion of Equivalency: Statistical Characterization of Quantization Effects in LLMs | 2607.08734 | quantization quality (8-bit to 2-bit), attention-weight sensitivity |
| 6 | Quantization Thresholds Replicate, Failure Modes Do Not (GGUF Q8_0 to Q2_K) | 2609.32042 | GGUF Q2_K-Q8_0, 7B/11B models, agentic tool-use degradation |
| 7 | Challenging GPU Dominance: When CPUs Outperform for On-Device LLM Inference | 2505.06461 | CPU vs GPU, llama.cpp, tokens/sec, memory bandwidth |
| 8 | Automated Tensor Scheduling for Hybrid CPU-GPU LLM Inference on Consumer Devices | 2607.10183 | ATSInfer, hybrid CPU/GPU offloading, PCIe, prefill/decode throughput |
| 9 | SpecOffload: Unlocking Latent GPU Capacity for LLM Inference on Resource-Constrained Devices | 2505.10259 | CPU/GPU offloading, GPU core utilization, throughput |
| 10 | ScoutAttention: Efficient KV Cache Offloading via Layer-Ahead CPU Pre-computation | 2603.27138 | KV cache offloading, GPU-CPU co-attention, long context |
| 11 | HeadInfer: Memory-Efficient LLM Inference by Head-wise Offloading | 2502.12574 | KV cache, Llama-3-8B, RTX 4090 (24GB), RAM/VRAM reduction |
| 12 | More Accurate or More Efficient? Locally Deployed Compact Open-Weight LLMs | 2608.22048 | Gemma3:4b, Phi3:3.8b, Qwen3:4b (4B-class), per-watt, local deployment |

## Topic Coverage

- **llama.cpp / GGUF / K-quant (Q2_K-Q8_0)**: Papers #1, #2, #3, #6
- **4B-20B parameter models**: Papers #1 (8B), #3 (Qwen-2.5), #6 (7B/11B), #11 (8B), #12 (4B-class)
- **Local inference on personal-PC hardware**: Papers #2, #3, #11, #12
- **CPU inference / CPU vs GPU**: Papers #7, #8, #10
- **GPU acceleration / hybrid CPU-GPU offloading**: Papers #7, #8, #9, #10
- **KV cache optimization**: Papers #10, #11, #3
- **Quantization quality / perplexity**: Papers #1, #4, #5, #6
- **Tokens per second / inference performance**: Papers #2, #7, #8
- **RAM / VRAM requirements**: Papers #11, #8, #9

**All papers are open access and available from arXiv.org**

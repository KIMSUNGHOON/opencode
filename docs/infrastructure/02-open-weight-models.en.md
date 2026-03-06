# Guide to Using Large Open Weight Models

## Overview

This document analyzes the benefits, configuration methods, and optimization strategies for using large open weight models such as DeepSeek-V3, Kimi-K2, Llama 3.3, and Qwen 2.5 with OpenCode.

---

## Table of Contents

1. [Open Weight Model Overview](#1-open-weight-model-overview)
2. [Key Model Comparison Analysis](#2-key-model-comparison-analysis)
3. [OpenCode Integration Benefits](#3-opencode-integration-benefits)
4. [Serving Infrastructure Configuration](#4-serving-infrastructure-configuration)
5. [Per-Model Configuration Guide](#5-per-model-configuration-guide)
6. [Performance Optimization](#6-performance-optimization)
7. [Use Cases and Recommendations](#7-use-cases-and-recommendations)
8. [Cost Analysis](#8-cost-analysis)

---

## 1. Open Weight Model Overview

### 1.1 Open Weight vs Proprietary

| Aspect | Open Weight | Proprietary (Claude, GPT) |
|------|-------------|---------------------------|
| **Cost** | Infrastructure cost only | API usage cost |
| **Data Privacy** | Full control | External transmission |
| **Customization** | Fine-tuning possible | Limited |
| **Offline Use** | Possible | Not possible |
| **Latency** | Local = low | Network dependent |
| **Scalability** | Infrastructure dependent | Auto-scaling |

### 1.2 Current Major Open Weight Models

```
┌─────────────────────────────────────────────────────────────────┐
│                   Open Weight Model Landscape                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Frontier Class (600B+)                                         │
│  ├── DeepSeek-V3 (671B MoE, 37B active)                        │
│  ├── Kimi-K2 (1T+ MoE)                                         │
│  └── Llama 4 (rumored)                                         │
│                                                                  │
│  Large Class (70B-200B)                                         │
│  ├── Llama 3.3 70B                                             │
│  ├── Qwen 2.5 72B                                              │
│  ├── Mixtral 8x22B (MoE)                                       │
│  └── DeepSeek-V2 236B (MoE)                                    │
│                                                                  │
│  Medium Class (7B-30B)                                          │
│  ├── Llama 3.2 8B                                              │
│  ├── Qwen 2.5 14B/32B                                          │
│  ├── Mistral 7B/12B                                            │
│  └── Phi-3 14B                                                 │
│                                                                  │
│  Small Class (<7B)                                              │
│  ├── Llama 3.2 3B                                              │
│  ├── Qwen 2.5 3B/7B                                            │
│  └── Phi-3.5 Mini                                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Key Model Comparison Analysis

### 2.1 DeepSeek-V3 / V3.1

**Model Information:**
- Parameters: 671B (MoE, 37B active)
- Context: 128K tokens
- License: DeepSeek License (commercial use permitted)

**Strengths:**
- Excellent code generation capability (GPT-4 level)
- Strong math/logical reasoning
- Chinese/English bilingual
- Efficient inference via MoE

**OpenCode Usage:**
```json
{
  "provider": {
    "deepseek": {
      "name": "DeepSeek-V3",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:8000/v1"
      },
      "models": {
        "deepseek-v3": {
          "name": "DeepSeek-V3",
          "id": "deepseek-v3",
          "tool_call": true,
          "temperature": true,
          "reasoning": false,
          "limit": {
            "context": 128000,
            "output": 8192
          }
        }
      }
    }
  }
}
```

**Recommended Use Cases:**
- Complex code refactoring
- Algorithm design
- Technical documentation writing
- Multilingual projects

### 2.2 Kimi-K2 (Moonshot)

**Model Information:**
- Parameters: 1T+ (estimated MoE)
- Context: 200K+ tokens
- Feature: Specialized for long context

**Strengths:**
- Ultra-long context processing
- Document analysis capability
- Multilingual support

**OpenCode Usage:**
```json
{
  "provider": {
    "kimi": {
      "name": "Kimi-K2",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "models": {
        "kimi-k2": {
          "name": "Kimi-K2",
          "id": "kimi-k2",
          "tool_call": true,
          "limit": {
            "context": 200000,
            "output": 16384
          }
        }
      }
    }
  }
}
```

**Recommended Use Cases:**
- Large-scale codebase analysis
- Long document processing
- Maintaining full project context

### 2.3 Llama 3.3 70B

**Model Information:**
- Parameters: 70B
- Context: 128K tokens
- License: Llama 3.3 License (commercial use permitted)

**Strengths:**
- Stable performance
- Broad ecosystem support
- Various quantization options
- Tool calling support

**OpenCode Usage:**
```json
{
  "provider": {
    "llama": {
      "name": "Llama 3.3",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "models": {
        "llama-3.3-70b": {
          "name": "Llama 3.3 70B",
          "id": "meta-llama/Llama-3.3-70B-Instruct",
          "tool_call": true,
          "temperature": true,
          "limit": {
            "context": 128000,
            "output": 4096
          }
        }
      }
    }
  }
}
```

### 2.4 Qwen 2.5 72B

**Model Information:**
- Parameters: 72B
- Context: 128K tokens
- License: Qwen License (commercial use permitted)

**Strengths:**
- Specialized in code generation
- Excellent math capability
- Multilingual (especially Asian languages)

**OpenCode Usage:**
```json
{
  "provider": {
    "qwen": {
      "name": "Qwen 2.5",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "models": {
        "qwen-2.5-72b": {
          "name": "Qwen 2.5 72B",
          "id": "Qwen/Qwen2.5-72B-Instruct",
          "tool_call": true,
          "temperature": true,
          "limit": {
            "context": 128000,
            "output": 8192
          }
        }
      }
    }
  }
}
```

### 2.5 Model Comparison Summary

| Model | Size | Context | Code | Reasoning | Tool Call | Key Strength |
|------|------|---------|------|------|-----------|--------|
| DeepSeek-V3 | 671B MoE | 128K | ★★★★★ | ★★★★★ | ✅ | Efficient MoE |
| Kimi-K2 | 1T+ MoE | 200K+ | ★★★★☆ | ★★★★☆ | ✅ | Ultra-long context |
| Llama 3.3 70B | 70B | 128K | ★★★★☆ | ★★★★☆ | ✅ | Stability |
| Qwen 2.5 72B | 72B | 128K | ★★★★★ | ★★★★☆ | ✅ | Code specialized |

---

## 3. OpenCode Integration Benefits

### 3.1 Cost Efficiency

**API Cost Comparison (per 1 million tokens):**

| Provider | Input | Output | Estimated Monthly Cost* |
|--------|------|------|--------------|
| Claude Opus | $15 | $75 | ~$1,000+ |
| GPT-4 | $30 | $60 | ~$1,000+ |
| Local DeepSeek-V3 | $0 | $0 | Infrastructure only |
| Local Llama 3.3 | $0 | $0 | Infrastructure only |

*Based on typical development workloads

**Infrastructure Cost Examples:**
```
GPU Server (A100 80GB x 4)
- Cloud: ~$10-15/hour
- Monthly: ~$7,000-11,000
- Cost per person reduced when shared across team

GPU Server (RTX 4090 x 2, Local)
- Initial investment: ~$4,000-5,000
- Electricity/maintenance: ~$100-200/month
- ROI within 2-3 months
```

### 3.2 Data Privacy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Data Flow Comparison                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  API Service:                                                    │
│  ┌────────┐     ┌────────────┐     ┌────────────┐              │
│  │ Code   │────▶│  Internet   │────▶│ External   │              │
│  │ Data   │◀────│ (Encrypted) │◀────│ Server     │              │
│  └────────┘     └────────────┘     └────────────┘              │
│       ⚠️ Sensitive data may be exposed externally                │
│                                                                  │
│  Local Serving:                                                  │
│  ┌────────┐     ┌────────────┐                                  │
│  │ Code   │────▶│ Local GPU   │                                  │
│  │ Data   │◀────│ Server      │                                  │
│  └────────┘     └────────────┘                                  │
│       ✅ Data processed locally only                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Privacy Benefits:**
- No external exposure of source code
- Easy regulatory compliance (GDPR, HIPAA, etc.)
- Internal policy compliance
- Easy audit trail

### 3.3 Customization

**Fine-tuning Possibilities:**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Customization Options                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Prompt Engineering                                           │
│     └── System prompt optimization                               │
│                                                                  │
│  2. LoRA Fine-tuning                                             │
│     └── Adaptation to specific domains/styles                    │
│     └── Learning code style guides                               │
│     └── Learning company conventions                             │
│                                                                  │
│  3. Full Fine-tuning                                             │
│     └── Large-scale custom datasets                              │
│     └── Specialized languages/frameworks                         │
│                                                                  │
│  4. Retrieval Augmentation (RAG)                                 │
│     └── Internal documentation integration                      │
│     └── Codebase context                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Offline Use

```json
{
  "provider": {
    "local-offline": {
      "name": "Offline Model",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "options": {
        "apiKey": "offline",
        "timeout": false
      }
    }
  }
}
```

**Offline Use Cases:**
- Secure environments (air-gapped)
- Unstable networks
- Working on the go
- Regulated environments

### 3.5 Latency Improvement

| Scenario | API Service | Local Serving |
|----------|-----------|----------|
| First token | 500ms-2s | 100-500ms |
| Tokens/sec | 30-100 | 50-200+ |
| Network variability | Yes | None |

---

## 4. Serving Infrastructure Configuration

### 4.1 sglang

**Features:**
- High-performance inference engine
- Fast KV cache with RadixAttention
- OpenAI-compatible API

**Installation and Execution:**
```bash
# Installation
pip install sglang[all]

# Start server
python -m sglang.launch_server \
  --model deepseek-ai/DeepSeek-V3 \
  --port 30000 \
  --tp 4 \
  --trust-remote-code
```

**OpenCode Integration:**
```json
{
  "provider": {
    "sglang": {
      "api": "http://localhost:30000/v1",
      "options": {
        "apiKey": "dummy"
      }
    }
  }
}
```

### 4.2 vLLM

**Features:**
- PagedAttention
- High throughput
- Wide model support

**Installation and Execution:**
```bash
# Installation
pip install vllm

# Start server
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.3-70B-Instruct \
  --tensor-parallel-size 4 \
  --port 8000
```

### 4.3 Ollama

**Features:**
- Easy installation
- Automatic quantization
- macOS/Windows support

**Installation and Execution:**
```bash
# Installation
curl -fsSL https://ollama.com/install.sh | sh

# Download and run model
ollama run llama3.3:70b
```

**OpenCode Integration:**
```json
{
  "provider": {
    "ollama": {
      "api": "http://localhost:11434/v1",
      "options": {
        "apiKey": "ollama"
      }
    }
  }
}
```

### 4.4 Hardware Requirements

| Model | FP16 VRAM | INT8 VRAM | INT4 VRAM |
|------|-----------|-----------|-----------|
| DeepSeek-V3 (active) | ~75GB | ~40GB | ~20GB |
| Llama 3.3 70B | ~140GB | ~70GB | ~35GB |
| Qwen 2.5 72B | ~144GB | ~72GB | ~36GB |
| Llama 3.2 8B | ~16GB | ~8GB | ~4GB |

**Recommended Configurations:**

| Scenario | GPU | Model |
|----------|-----|------|
| Individual development | RTX 4090 24GB | Llama 3.2 8B (FP16), 70B (INT4) |
| Team server | A100 80GB x 2 | Llama 3.3 70B (FP16) |
| Enterprise | A100 80GB x 4+ | DeepSeek-V3, Kimi-K2 |

---

## 5. Per-Model Configuration Guide

### 5.1 DeepSeek-V3 Full Configuration

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "deepseek/deepseek-v3",
  "small_model": "deepseek/deepseek-v3",

  "provider": {
    "deepseek": {
      "name": "DeepSeek-V3 Local",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:30000/v1",
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:30000/v1",
        "timeout": 300000
      },
      "models": {
        "deepseek-v3": {
          "name": "DeepSeek-V3",
          "id": "deepseek-v3",
          "tool_call": true,
          "temperature": true,
          "reasoning": false,
          "attachment": false,
          "modalities": {
            "input": ["text"],
            "output": ["text"]
          },
          "limit": {
            "context": 128000,
            "output": 8192
          },
          "cost": {
            "input": 0,
            "output": 0
          }
        }
      }
    }
  },

  "agent": {
    "build": {
      "model": "deepseek/deepseek-v3",
      "temperature": 0.7
    },
    "plan": {
      "model": "deepseek/deepseek-v3",
      "temperature": 0.3
    },
    "general": {
      "model": "deepseek/deepseek-v3"
    },
    "explore": {
      "model": "deepseek/deepseek-v3"
    }
  }
}
```

### 5.2 Kimi-K2 Long Context Configuration

```json
{
  "model": "kimi/kimi-k2",

  "provider": {
    "kimi": {
      "name": "Kimi-K2 Local",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "options": {
        "apiKey": "dummy",
        "timeout": 600000
      },
      "models": {
        "kimi-k2": {
          "name": "Kimi-K2",
          "id": "kimi-k2",
          "tool_call": true,
          "temperature": true,
          "limit": {
            "context": 200000,
            "output": 16384
          }
        }
      }
    }
  },

  "experimental": {
    "mcp_timeout": 60000
  }
}
```

### 5.3 Multi-Model Configuration

```json
{
  "model": "deepseek/deepseek-v3",
  "small_model": "ollama/llama3.2:8b",

  "provider": {
    "deepseek": {
      "name": "DeepSeek-V3",
      "api": "http://gpu-server:30000/v1",
      "models": {
        "deepseek-v3": {
          "id": "deepseek-v3",
          "limit": { "context": 128000, "output": 8192 }
        }
      }
    },
    "ollama": {
      "name": "Ollama Local",
      "api": "http://localhost:11434/v1",
      "options": { "apiKey": "ollama" },
      "models": {
        "llama3.2:8b": {
          "id": "llama3.2:8b",
          "limit": { "context": 128000, "output": 4096 }
        }
      }
    }
  },

  "agent": {
    "build": { "model": "deepseek/deepseek-v3" },
    "explore": { "model": "ollama/llama3.2:8b" },
    "title": { "model": "ollama/llama3.2:8b" }
  }
}
```

---

## 6. Performance Optimization

### 6.1 Quantization Strategy

| Quantization | Quality | Speed | VRAM | Recommendation |
|--------|------|------|------|------|
| FP16 | ★★★★★ | ★★★☆☆ | 100% | Production |
| INT8 | ★★★★☆ | ★★★★☆ | 50% | Balanced |
| INT4 | ★★★☆☆ | ★★★★★ | 25% | Resource constrained |
| GGUF Q4 | ★★★☆☆ | ★★★★☆ | 25% | Ollama |

### 6.2 Batch Processing Optimization

```bash
# sglang batch configuration
python -m sglang.launch_server \
  --model deepseek-ai/DeepSeek-V3 \
  --max-running-requests 8 \
  --max-num-reqs 32
```

### 6.3 KV Cache Optimization

```bash
# vLLM KV cache configuration
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.3-70B-Instruct \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768
```

### 6.4 OpenCode-Side Optimization

```json
{
  "experimental": {
    "mcp_timeout": 30000,
    "chatMaxRetries": 3
  },
  "compaction": {
    "auto": true,
    "prune": true
  }
}
```

---

## 7. Use Cases and Recommendations

### 7.1 Recommended Models by Scenario

| Scenario | Recommended Model | Reason |
|----------|----------|------|
| General coding | Llama 3.3 70B | Stability, speed |
| Complex refactoring | DeepSeek-V3 | Reasoning capability |
| Large-scale codebase | Kimi-K2 | Long context |
| Quick tasks | Llama 3.2 8B | Speed |
| Code generation | Qwen 2.5 72B | Code specialized |

### 7.2 Recommended Settings by Agent

```json
{
  "agent": {
    "build": {
      "model": "deepseek/deepseek-v3",
      "temperature": 0.7,
      "steps": 100
    },
    "plan": {
      "model": "deepseek/deepseek-v3",
      "temperature": 0.3
    },
    "explore": {
      "model": "ollama/llama3.2:8b",
      "temperature": 0.1
    },
    "title": {
      "model": "ollama/llama3.2:8b",
      "temperature": 0.5
    },
    "summary": {
      "model": "ollama/llama3.2:8b"
    }
  }
}
```

### 7.3 Hybrid Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hybrid Model Strategy                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Complex tasks (build, plan)                                     │
│  └── DeepSeek-V3 / Kimi-K2 (large models)                       │
│      └── Complex reasoning                                       │
│      └── Code generation/modification                            │
│      └── Architecture design                                     │
│                                                                  │
│  Simple tasks (explore, title, summary)                          │
│  └── Llama 3.2 8B / Qwen 2.5 7B (small models)                  │
│      └── File exploration                                        │
│      └── Title generation                                        │
│      └── Summarization                                           │
│                                                                  │
│  Benefits:                                                       │
│  - Cost efficiency                                               │
│  - Response speed optimization                                   │
│  - Efficient GPU resource usage                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Cost Analysis

### 8.1 TCO (Total Cost of Ownership) Comparison

**Scenario: 5-person development team, 8 hours/day usage**

| Item | API Service | Local Serving |
|------|-----------|----------|
| Monthly API cost | $5,000-10,000 | $0 |
| Server cost | $0 | $1,500-3,000 |
| Management cost | Low | Medium |
| Total monthly cost | $5,000-10,000 | $1,500-3,000 |
| Annual cost | $60,000-120,000 | $18,000-36,000 |

**Break-even Point (when purchasing local server):**
```
Server cost: $30,000 (A100 x 2)
Monthly savings: $3,500-7,000
ROI: 4-9 months
```

### 8.2 Cloud vs On-Premises

| Option | Initial Cost | Monthly Cost | Scalability | Management |
|------|----------|---------|--------|------|
| Cloud GPU | $0 | $5,000-15,000 | High | Low |
| On-premises | $30,000-100,000 | $500-1,000 | Limited | High |
| Hybrid | $15,000-50,000 | $1,000-5,000 | Medium | Medium |

### 8.3 Recommended Strategy

```
Recommendations by team size:

1-3 people (individual/small)
└── Ollama + RTX 4090
└── Or API service (low usage)

4-10 people (small-medium)
└── vLLM/sglang + A100 x 2
└── Or cloud GPU (on-demand)

10+ people (large)
└── On-premises cluster
└── Or dedicated cloud instances
```

---

## Conclusion

### Key Benefits of Using Open Weight Models

1. **Cost Reduction**: 70-80% cost savings possible in the long term
2. **Data Security**: Sensitive code is not transmitted externally
3. **Customization**: Optimization tailored to team/project characteristics
4. **Stability**: Eliminates network dependency, consistent performance

### Getting Started Recommendations

1. **First Step**: Start with Ollama + Llama 3.2 8B
2. **Scale Up**: Move to vLLM + Llama 3.3 70B as the team grows
3. **Optimize**: Introduce DeepSeek-V3 or Kimi-K2 after analyzing usage patterns
4. **Hybrid**: Separate models based on task complexity

### Important Notes

- Verify tool calling support is essential
- Ensure sufficient VRAM
- Choose appropriate quantization level
- Manage regular model updates

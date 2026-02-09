# 대형 Open Weight 모델 활용 가이드

## 개요

이 문서는 DeepSeek-V3, Kimi-K2, Llama 3.3, Qwen 2.5 등 대형 Open Weight 모델을 OpenCode와 함께 사용할 때의 이점, 설정 방법, 최적화 전략을 분석합니다.

---

## 목차

1. [Open Weight 모델 개요](#1-open-weight-모델-개요)
2. [주요 모델 비교 분석](#2-주요-모델-비교-분석)
3. [OpenCode 통합 이점](#3-opencode-통합-이점)
4. [서빙 인프라 구성](#4-서빙-인프라-구성)
5. [모델별 설정 가이드](#5-모델별-설정-가이드)
6. [성능 최적화](#6-성능-최적화)
7. [사용 사례 및 권장사항](#7-사용-사례-및-권장사항)
8. [비용 분석](#8-비용-분석)

---

## 1. Open Weight 모델 개요

### 1.1 Open Weight vs Proprietary

| 측면 | Open Weight | Proprietary (Claude, GPT) |
|------|-------------|---------------------------|
| **비용** | 인프라 비용만 | API 사용량 비용 |
| **데이터 프라이버시** | 완전한 제어 | 외부 전송 |
| **커스터마이징** | Fine-tuning 가능 | 제한적 |
| **오프라인 사용** | 가능 | 불가능 |
| **지연 시간** | 로컬 = 낮음 | 네트워크 의존 |
| **확장성** | 인프라 의존 | 자동 확장 |

### 1.2 현재 주요 Open Weight 모델

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

## 2. 주요 모델 비교 분석

### 2.1 DeepSeek-V3 / V3.1

**모델 정보:**
- 파라미터: 671B (MoE, 37B active)
- Context: 128K tokens
- 라이선스: DeepSeek License (상업적 사용 가능)

**강점:**
- 코드 생성 능력 우수 (GPT-4 수준)
- 수학/논리 추론 강함
- 중국어/영어 이중 언어
- MoE로 효율적 추론

**OpenCode 활용:**
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

**권장 사용 사례:**
- 복잡한 코드 리팩토링
- 알고리즘 설계
- 기술 문서 작성
- 다국어 프로젝트

### 2.2 Kimi-K2 (Moonshot)

**모델 정보:**
- 파라미터: 1T+ (MoE 추정)
- Context: 200K+ tokens
- 특징: 긴 컨텍스트 특화

**강점:**
- 초장문 컨텍스트 처리
- 문서 분석 능력
- 다국어 지원

**OpenCode 활용:**
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

**권장 사용 사례:**
- 대규모 코드베이스 분석
- 긴 문서 처리
- 전체 프로젝트 컨텍스트 유지

### 2.3 Llama 3.3 70B

**모델 정보:**
- 파라미터: 70B
- Context: 128K tokens
- 라이선스: Llama 3.3 License (상업적 사용 가능)

**강점:**
- 안정적인 성능
- 넓은 생태계 지원
- 다양한 양자화 옵션
- Tool calling 지원

**OpenCode 활용:**
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

**모델 정보:**
- 파라미터: 72B
- Context: 128K tokens
- 라이선스: Qwen License (상업적 사용 가능)

**강점:**
- 코드 생성 특화
- 수학 능력 우수
- 다국어 (특히 아시아 언어)

**OpenCode 활용:**
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

### 2.5 모델 비교 요약

| 모델 | 크기 | Context | 코드 | 추론 | Tool Call | 특장점 |
|------|------|---------|------|------|-----------|--------|
| DeepSeek-V3 | 671B MoE | 128K | ★★★★★ | ★★★★★ | ✅ | 효율적 MoE |
| Kimi-K2 | 1T+ MoE | 200K+ | ★★★★☆ | ★★★★☆ | ✅ | 초장문 |
| Llama 3.3 70B | 70B | 128K | ★★★★☆ | ★★★★☆ | ✅ | 안정성 |
| Qwen 2.5 72B | 72B | 128K | ★★★★★ | ★★★★☆ | ✅ | 코드 특화 |

---

## 3. OpenCode 통합 이점

### 3.1 비용 효율성

**API 비용 비교 (100만 토큰 기준):**

| 제공자 | 입력 | 출력 | 월 예상 비용* |
|--------|------|------|--------------|
| Claude Opus | $15 | $75 | ~$1,000+ |
| GPT-4 | $30 | $60 | ~$1,000+ |
| 로컬 DeepSeek-V3 | $0 | $0 | 인프라만 |
| 로컬 Llama 3.3 | $0 | $0 | 인프라만 |

*일반적인 개발 작업 기준

**인프라 비용 예시:**
```
GPU 서버 (A100 80GB x 4)
- 클라우드: ~$10-15/시간
- 월간: ~$7,000-11,000
- 팀 공유 시 인당 비용 절감

GPU 서버 (RTX 4090 x 2, 로컬)
- 초기 투자: ~$4,000-5,000
- 전기/유지: ~$100-200/월
- 2-3개월 내 ROI
```

### 3.2 데이터 프라이버시

```
┌─────────────────────────────────────────────────────────────────┐
│                    Data Flow Comparison                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  API 서비스:                                                     │
│  ┌────────┐     ┌────────────┐     ┌────────────┐              │
│  │ 코드   │────▶│  인터넷    │────▶│ 외부 서버  │              │
│  │ 데이터 │◀────│  (암호화)  │◀────│ (처리)     │              │
│  └────────┘     └────────────┘     └────────────┘              │
│       ⚠️ 민감 데이터 외부 노출 가능                              │
│                                                                  │
│  로컬 서빙:                                                      │
│  ┌────────┐     ┌────────────┐                                  │
│  │ 코드   │────▶│ 로컬 GPU   │                                  │
│  │ 데이터 │◀────│ 서버       │                                  │
│  └────────┘     └────────────┘                                  │
│       ✅ 데이터가 로컬에서만 처리                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**프라이버시 이점:**
- 소스 코드 외부 노출 없음
- 규정 준수 용이 (GDPR, HIPAA 등)
- 내부 정책 준수
- 감사 추적 용이

### 3.3 커스터마이징

**Fine-tuning 가능성:**
```
┌─────────────────────────────────────────────────────────────────┐
│                    Customization Options                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Prompt Engineering                                           │
│     └── 시스템 프롬프트 최적화                                   │
│                                                                  │
│  2. LoRA Fine-tuning                                             │
│     └── 특정 도메인/스타일 적응                                  │
│     └── 코드 스타일 가이드 학습                                  │
│     └── 회사 컨벤션 학습                                         │
│                                                                  │
│  3. Full Fine-tuning                                             │
│     └── 대규모 커스텀 데이터셋                                   │
│     └── 특수 언어/프레임워크                                     │
│                                                                  │
│  4. Retrieval Augmentation (RAG)                                 │
│     └── 내부 문서 연동                                           │
│     └── 코드베이스 컨텍스트                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 오프라인 사용

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

**오프라인 사용 사례:**
- 보안 환경 (에어갭)
- 불안정한 네트워크
- 이동 중 작업
- 규정된 환경

### 3.5 지연 시간 개선

| 시나리오 | API 서비스 | 로컬 서빙 |
|----------|-----------|----------|
| 첫 토큰 | 500ms-2s | 100-500ms |
| 토큰/초 | 30-100 | 50-200+ |
| 네트워크 변동 | 있음 | 없음 |

---

## 4. 서빙 인프라 구성

### 4.1 sglang

**특징:**
- 고성능 추론 엔진
- RadixAttention으로 빠른 KV 캐시
- OpenAI 호환 API

**설치 및 실행:**
```bash
# 설치
pip install sglang[all]

# 서버 시작
python -m sglang.launch_server \
  --model deepseek-ai/DeepSeek-V3 \
  --port 30000 \
  --tp 4 \
  --trust-remote-code
```

**OpenCode 연동:**
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

**특징:**
- PagedAttention
- 높은 처리량
- 다양한 모델 지원

**설치 및 실행:**
```bash
# 설치
pip install vllm

# 서버 시작
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.3-70B-Instruct \
  --tensor-parallel-size 4 \
  --port 8000
```

### 4.3 Ollama

**특징:**
- 간편한 설치
- 자동 양자화
- macOS/Windows 지원

**설치 및 실행:**
```bash
# 설치
curl -fsSL https://ollama.com/install.sh | sh

# 모델 다운로드 및 실행
ollama run llama3.3:70b
```

**OpenCode 연동:**
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

### 4.4 하드웨어 요구사항

| 모델 | FP16 VRAM | INT8 VRAM | INT4 VRAM |
|------|-----------|-----------|-----------|
| DeepSeek-V3 (active) | ~75GB | ~40GB | ~20GB |
| Llama 3.3 70B | ~140GB | ~70GB | ~35GB |
| Qwen 2.5 72B | ~144GB | ~72GB | ~36GB |
| Llama 3.2 8B | ~16GB | ~8GB | ~4GB |

**권장 구성:**

| 시나리오 | GPU | 모델 |
|----------|-----|------|
| 개인 개발 | RTX 4090 24GB | Llama 3.2 8B (FP16), 70B (INT4) |
| 팀 서버 | A100 80GB x 2 | Llama 3.3 70B (FP16) |
| 엔터프라이즈 | A100 80GB x 4+ | DeepSeek-V3, Kimi-K2 |

---

## 5. 모델별 설정 가이드

### 5.1 DeepSeek-V3 전체 설정

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

### 5.2 Kimi-K2 긴 컨텍스트 설정

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

### 5.3 멀티 모델 설정

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

## 6. 성능 최적화

### 6.1 양자화 전략

| 양자화 | 품질 | 속도 | VRAM | 권장 |
|--------|------|------|------|------|
| FP16 | ★★★★★ | ★★★☆☆ | 100% | 프로덕션 |
| INT8 | ★★★★☆ | ★★★★☆ | 50% | 균형 |
| INT4 | ★★★☆☆ | ★★★★★ | 25% | 리소스 제한 |
| GGUF Q4 | ★★★☆☆ | ★★★★☆ | 25% | Ollama |

### 6.2 배치 처리 최적화

```bash
# sglang 배치 설정
python -m sglang.launch_server \
  --model deepseek-ai/DeepSeek-V3 \
  --max-running-requests 8 \
  --max-num-reqs 32
```

### 6.3 KV 캐시 최적화

```bash
# vLLM KV 캐시 설정
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.3-70B-Instruct \
  --gpu-memory-utilization 0.9 \
  --max-model-len 32768
```

### 6.4 OpenCode 측 최적화

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

## 7. 사용 사례 및 권장사항

### 7.1 시나리오별 권장 모델

| 시나리오 | 권장 모델 | 이유 |
|----------|----------|------|
| 일반 코딩 | Llama 3.3 70B | 안정성, 속도 |
| 복잡한 리팩토링 | DeepSeek-V3 | 추론 능력 |
| 대규모 코드베이스 | Kimi-K2 | 긴 컨텍스트 |
| 빠른 작업 | Llama 3.2 8B | 속도 |
| 코드 생성 | Qwen 2.5 72B | 코드 특화 |

### 7.2 에이전트별 권장 설정

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

### 7.3 하이브리드 전략

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hybrid Model Strategy                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  복잡한 작업 (build, plan)                                       │
│  └── DeepSeek-V3 / Kimi-K2 (대형 모델)                          │
│      └── 복잡한 추론                                             │
│      └── 코드 생성/수정                                          │
│      └── 아키텍처 설계                                           │
│                                                                  │
│  단순한 작업 (explore, title, summary)                           │
│  └── Llama 3.2 8B / Qwen 2.5 7B (소형 모델)                     │
│      └── 파일 탐색                                               │
│      └── 제목 생성                                               │
│      └── 요약                                                    │
│                                                                  │
│  이점:                                                           │
│  - 비용 효율성                                                   │
│  - 응답 속도 최적화                                              │
│  - GPU 리소스 효율적 사용                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. 비용 분석

### 8.1 TCO (Total Cost of Ownership) 비교

**시나리오: 5인 개발팀, 일 8시간 사용**

| 항목 | API 서비스 | 로컬 서빙 |
|------|-----------|----------|
| 월 API 비용 | $5,000-10,000 | $0 |
| 서버 비용 | $0 | $1,500-3,000 |
| 관리 비용 | 낮음 | 중간 |
| 총 월 비용 | $5,000-10,000 | $1,500-3,000 |
| 연간 비용 | $60,000-120,000 | $18,000-36,000 |

**손익분기점 (로컬 서버 구매 시):**
```
서버 비용: $30,000 (A100 x 2)
월 절감: $3,500-7,000
ROI: 4-9개월
```

### 8.2 클라우드 vs 온프레미스

| 옵션 | 초기 비용 | 월 비용 | 확장성 | 관리 |
|------|----------|---------|--------|------|
| 클라우드 GPU | $0 | $5,000-15,000 | 높음 | 낮음 |
| 온프레미스 | $30,000-100,000 | $500-1,000 | 제한적 | 높음 |
| 하이브리드 | $15,000-50,000 | $1,000-5,000 | 중간 | 중간 |

### 8.3 권장 전략

```
팀 규모별 권장:

1-3명 (개인/소규모)
└── Ollama + RTX 4090
└── 또는 API 서비스 (저사용량)

4-10명 (중소규모)
└── vLLM/sglang + A100 x 2
└── 또는 클라우드 GPU (온디맨드)

10명+ (대규모)
└── 온프레미스 클러스터
└── 또는 클라우드 전용 인스턴스
```

---

## 결론

### Open Weight 모델 사용의 핵심 이점

1. **비용 절감**: 장기적으로 70-80% 비용 절감 가능
2. **데이터 보안**: 민감한 코드가 외부로 전송되지 않음
3. **커스터마이징**: 팀/프로젝트 특성에 맞는 최적화 가능
4. **안정성**: 네트워크 의존성 제거, 일관된 성능

### 시작 권장 사항

1. **첫 단계**: Ollama + Llama 3.2 8B로 시작
2. **확장**: 팀 성장 시 vLLM + Llama 3.3 70B
3. **최적화**: 사용 패턴 분석 후 DeepSeek-V3 또는 Kimi-K2 도입
4. **하이브리드**: 작업 복잡도에 따른 모델 분리

### 주의 사항

- Tool calling 지원 여부 확인 필수
- 충분한 VRAM 확보
- 적절한 양자화 수준 선택
- 정기적인 모델 업데이트 관리

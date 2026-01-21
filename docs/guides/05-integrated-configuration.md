# 전체 설정 통합 가이드

## 개요

이 문서는 로컬 LLM 서버(sglang + GPT-OSS-120B 등)를 사용하는 환경에서 OpenCode를 완전히 설정하는 방법을 통합적으로 설명합니다.

---

## 목차

1. [환경 구성 개요](#1-환경-구성-개요)
2. [기본 설정](#2-기본-설정)
3. [Provider 설정](#3-provider-설정)
4. [Agent 설정](#4-agent-설정)
5. [MCP 설정](#5-mcp-설정)
6. [권한 설정](#6-권한-설정)
7. [Command 설정](#7-command-설정)
8. [고급 설정](#8-고급-설정)
9. [전체 설정 예시](#9-전체-설정-예시)
10. [검증 및 테스트](#10-검증-및-테스트)

---

## 1. 환경 구성 개요

### 1.1 아키텍처

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Local Development Environment                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐         ┌─────────────────────────────────┐   │
│  │   Local LLM     │         │          OpenCode               │   │
│  │   Server        │◄───────▶│                                 │   │
│  │  (sglang)       │   API   │  ┌─────────────────────────┐   │   │
│  │                 │         │  │      Primary Agents      │   │   │
│  │  GPT-OSS-120B   │         │  │  ┌─────┐    ┌─────┐     │   │   │
│  │  DeepSeek-V3    │         │  │  │build│    │plan │     │   │   │
│  │  Kimi-K2        │         │  │  └─────┘    └─────┘     │   │   │
│  └─────────────────┘         │  └─────────────────────────┘   │   │
│          │                   │                                 │   │
│          │                   │  ┌─────────────────────────┐   │   │
│          │                   │  │       Sub Agents         │   │   │
│          │                   │  │  ┌───────┐ ┌─────────┐  │   │   │
│          │                   │  │  │general│ │ explore │  │   │   │
│          │                   │  │  └───────┘ └─────────┘  │   │   │
│          │                   │  │  ┌───────┐ ┌─────────┐  │   │   │
│          │                   │  │  │custom1│ │ custom2 │  │   │   │
│          │                   │  │  └───────┘ └─────────┘  │   │   │
│          │                   │  └─────────────────────────┘   │   │
│          │                   │                                 │   │
│          │                   │  ┌─────────────────────────┐   │   │
│          │                   │  │      MCP Servers         │   │   │
│          └───────────────────┼─▶│  GitHub │ Git │ FS      │   │   │
│                              │  └─────────────────────────┘   │   │
│                              └─────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 설정 파일 구조

```
project/
├── opencode.json              # 프로젝트 설정 (최우선)
├── opencode.jsonc             # JSONC 형식 지원
└── .opencode/
    ├── opencode.json          # .opencode 디렉토리 설정
    ├── agent/                 # Custom Agent 정의
    │   ├── code-reviewer.md
    │   ├── git-analyzer.md
    │   └── ...
    ├── command/               # Custom Command 정의
    │   ├── commit.md
    │   ├── review.md
    │   └── ...
    └── plugin/                # Custom Plugin
        └── my-plugin.ts

~/.config/opencode/            # 글로벌 설정
├── opencode.json
├── opencode.jsonc
└── .opencode/
    ├── agent/
    ├── command/
    └── plugin/
```

### 1.3 설정 우선순위

1. 환경 변수 (`OPENCODE_*`)
2. CLI 플래그
3. 프로젝트 `opencode.json`
4. 프로젝트 `.opencode/opencode.json`
5. 글로벌 `~/.config/opencode/opencode.json`
6. 원격 well-known 설정

---

## 2. 기본 설정

### 2.1 최소 설정

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "sglang/gpt-oss-120b"
}
```

### 2.2 권장 기본 설정

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "sglang/gpt-oss-120b",
  "small_model": "sglang/gpt-oss-120b",
  "logLevel": "info",
  "theme": "default",
  "autoupdate": false,
  "share": "disabled"
}
```

### 2.3 설정 옵션 설명

| 옵션 | 타입 | 설명 |
|------|------|------|
| `$schema` | string | JSON 스키마 URL |
| `model` | string | 기본 모델 (provider/model) |
| `small_model` | string | 작은 작업용 모델 |
| `logLevel` | enum | 로그 레벨 (debug/info/warn/error) |
| `theme` | string | UI 테마 |
| `autoupdate` | boolean/notify | 자동 업데이트 |
| `share` | enum | 세션 공유 (manual/auto/disabled) |
| `username` | string | 사용자명 |
| `default_agent` | string | 기본 에이전트 |

---

## 3. Provider 설정

### 3.1 로컬 LLM 서버 설정

#### sglang 서버

```json
{
  "provider": {
    "sglang": {
      "name": "Local SGLang Server",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:30000/v1",
      "env": [],
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:30000/v1"
      },
      "models": {
        "gpt-oss-120b": {
          "name": "GPT-OSS-120B",
          "id": "gpt-oss-120b",
          "tool_call": true,
          "temperature": true,
          "reasoning": false,
          "attachment": false,
          "modalities": {
            "input": ["text"],
            "output": ["text"]
          },
          "limit": {
            "context": 131072,
            "output": 8192
          },
          "cost": {
            "input": 0,
            "output": 0
          }
        }
      }
    }
  }
}
```

#### vLLM 서버

```json
{
  "provider": {
    "vllm": {
      "name": "Local vLLM Server",
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

#### Ollama 서버

```json
{
  "provider": {
    "ollama": {
      "name": "Ollama",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:11434/v1",
      "options": {
        "apiKey": "ollama",
        "baseURL": "http://localhost:11434/v1"
      },
      "models": {
        "llama3.3": {
          "name": "Llama 3.3 70B",
          "id": "llama3.3:70b",
          "tool_call": true,
          "temperature": true
        }
      }
    }
  }
}
```

### 3.2 모델 상세 설정

```json
{
  "models": {
    "model-id": {
      "name": "표시 이름",
      "id": "API 호출 시 사용할 ID",
      "tool_call": true,
      "temperature": true,
      "reasoning": false,
      "attachment": false,
      "interleaved": false,
      "modalities": {
        "input": ["text", "image"],
        "output": ["text"]
      },
      "limit": {
        "context": 128000,
        "input": 100000,
        "output": 8192
      },
      "cost": {
        "input": 0,
        "output": 0,
        "cache_read": 0,
        "cache_write": 0
      },
      "options": {},
      "headers": {}
    }
  }
}
```

### 3.3 Provider 옵션

| 옵션 | 타입 | 설명 |
|------|------|------|
| `apiKey` | string | API 키 |
| `baseURL` | string | API 엔드포인트 |
| `timeout` | number/false | 타임아웃 (ms) |
| `includeUsage` | boolean | 사용량 정보 포함 |

---

## 4. Agent 설정

### 4.1 내장 Agent 커스터마이징

```json
{
  "agent": {
    "build": {
      "model": "sglang/gpt-oss-120b",
      "temperature": 0.7,
      "steps": 100
    },
    "plan": {
      "model": "sglang/gpt-oss-120b",
      "temperature": 0.5
    },
    "general": {
      "model": "sglang/gpt-oss-120b"
    },
    "explore": {
      "model": "sglang/gpt-oss-120b"
    },
    "title": {
      "model": "sglang/gpt-oss-120b",
      "temperature": 0.5
    },
    "summary": {
      "model": "sglang/gpt-oss-120b"
    },
    "compaction": {
      "model": "sglang/gpt-oss-120b"
    }
  }
}
```

### 4.2 Custom Agent JSON 설정

```json
{
  "agent": {
    "code-reviewer": {
      "description": "코드 리뷰 전문가",
      "mode": "subagent",
      "model": "sglang/gpt-oss-120b",
      "temperature": 0.3,
      "color": "#4CAF50",
      "prompt": "당신은 시니어 개발자로서 코드 리뷰를 수행합니다...",
      "permission": {
        "read": "allow",
        "edit": "deny",
        "bash": "deny"
      }
    }
  }
}
```

### 4.3 Agent 비활성화

```json
{
  "agent": {
    "explore": {
      "disable": true
    }
  }
}
```

---

## 5. MCP 설정

### 5.1 로컬 MCP 서버

```json
{
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": [
        "npx", "-y",
        "@modelcontextprotocol/server-filesystem",
        "/home/user/projects"
      ],
      "enabled": true,
      "timeout": 30000
    },
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_TOKEN": "{env:GITHUB_TOKEN}"
      }
    },
    "git": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-git"]
    }
  }
}
```

### 5.2 원격 MCP 서버

```json
{
  "mcp": {
    "remote-api": {
      "type": "remote",
      "url": "https://mcp.example.com/sse",
      "headers": {
        "Authorization": "Bearer {env:API_TOKEN}"
      },
      "oauth": false,
      "timeout": 60000
    }
  }
}
```

### 5.3 MCP 비활성화

```json
{
  "mcp": {
    "github": {
      "enabled": false
    }
  }
}
```

---

## 6. 권한 설정

### 6.1 글로벌 권한

```json
{
  "permission": {
    "read": "allow",
    "edit": "allow",
    "glob": "allow",
    "grep": "allow",
    "list": "allow",
    "bash": "ask",
    "task": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "codesearch": "allow",
    "todowrite": "allow",
    "todoread": "allow",
    "question": "allow",
    "external_directory": "ask",
    "lsp": "allow",
    "doom_loop": "ask"
  }
}
```

### 6.2 패턴 기반 권한

```json
{
  "permission": {
    "read": {
      "*": "allow",
      "*.env": "deny",
      "*.env.*": "deny",
      "*.env.example": "allow",
      ".git/**": "deny",
      "**/node_modules/**": "deny"
    },
    "edit": {
      "src/**/*.ts": "allow",
      "src/**/*.tsx": "allow",
      "test/**": "allow",
      "*.config.*": "ask",
      "package.json": "ask",
      "*": "deny"
    },
    "bash": {
      "npm *": "allow",
      "bun *": "allow",
      "pnpm *": "allow",
      "yarn *": "allow",
      "git status": "allow",
      "git log *": "allow",
      "git diff *": "allow",
      "git add *": "ask",
      "git commit *": "ask",
      "git push *": "ask",
      "rm *": "deny",
      "sudo *": "deny",
      "*": "ask"
    },
    "external_directory": {
      "/tmp/*": "allow",
      "/home/user/projects/*": "allow",
      "*": "ask"
    }
  }
}
```

---

## 7. Command 설정

### 7.1 JSON 방식

```json
{
  "command": {
    "commit": {
      "template": "git 변경사항을 커밋합니다. $ARGUMENTS",
      "description": "Git 커밋 생성",
      "model": "sglang/gpt-oss-120b",
      "subtask": true
    },
    "review": {
      "template": "다음 파일을 리뷰합니다: $ARGUMENTS",
      "description": "코드 리뷰",
      "agent": "code-reviewer"
    }
  }
}
```

### 7.2 마크다운 방식

`.opencode/command/` 디렉토리에 `.md` 파일로 정의 (권장)

---

## 8. 고급 설정

### 8.1 키바인드 커스터마이징

```json
{
  "keybinds": {
    "leader": "ctrl+x",
    "app_exit": "ctrl+c,ctrl+d",
    "session_new": "<leader>n",
    "session_list": "<leader>l",
    "model_list": "<leader>m",
    "agent_list": "<leader>a",
    "agent_cycle": "tab",
    "input_submit": "return",
    "input_newline": "shift+return,ctrl+return"
  }
}
```

### 8.2 TUI 설정

```json
{
  "tui": {
    "scroll_speed": 1.0,
    "scroll_acceleration": {
      "enabled": true
    },
    "diff_style": "auto"
  }
}
```

### 8.3 서버 설정

```json
{
  "server": {
    "port": 4096,
    "hostname": "localhost",
    "mdns": false,
    "cors": ["http://localhost:3000"]
  }
}
```

### 8.4 LSP 설정

```json
{
  "lsp": {
    "typescript": {
      "command": ["typescript-language-server", "--stdio"],
      "extensions": [".ts", ".tsx", ".js", ".jsx"]
    },
    "python": {
      "command": ["pylsp"],
      "extensions": [".py"]
    },
    "rust": {
      "disabled": true
    }
  }
}
```

### 8.5 Formatter 설정

```json
{
  "formatter": {
    "prettier": {
      "command": ["prettier", "--write"],
      "extensions": [".ts", ".tsx", ".js", ".jsx", ".json", ".md"]
    },
    "black": {
      "command": ["black"],
      "extensions": [".py"]
    }
  }
}
```

### 8.6 실험적 기능

```json
{
  "experimental": {
    "hook": {
      "file_edited": {
        "*.ts": [
          {
            "command": ["prettier", "--write"],
            "environment": {}
          }
        ]
      },
      "session_completed": [
        {
          "command": ["./scripts/notify.sh"],
          "environment": {
            "WEBHOOK_URL": "{env:WEBHOOK_URL}"
          }
        }
      ]
    },
    "chatMaxRetries": 3,
    "batch_tool": false,
    "openTelemetry": false,
    "mcp_timeout": 30000
  }
}
```

### 8.7 Compaction 설정

```json
{
  "compaction": {
    "auto": true,
    "prune": true
  }
}
```

---

## 9. 전체 설정 예시

### 9.1 로컬 GPT-OSS-120B 환경 전체 설정

```json
{
  "$schema": "https://opencode.ai/config.json",

  // 기본 설정
  "model": "sglang/gpt-oss-120b",
  "small_model": "sglang/gpt-oss-120b",
  "logLevel": "info",
  "theme": "default",
  "autoupdate": false,
  "share": "disabled",

  // Provider 설정
  "provider": {
    "sglang": {
      "name": "Local SGLang Server",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:30000/v1",
      "env": [],
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:30000/v1",
        "timeout": 300000
      },
      "models": {
        "gpt-oss-120b": {
          "name": "GPT-OSS-120B",
          "id": "gpt-oss-120b",
          "tool_call": true,
          "temperature": true,
          "reasoning": false,
          "attachment": false,
          "modalities": {
            "input": ["text"],
            "output": ["text"]
          },
          "limit": {
            "context": 131072,
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

  // Agent 설정
  "agent": {
    "build": {
      "model": "sglang/gpt-oss-120b",
      "temperature": 0.7,
      "steps": 100
    },
    "plan": {
      "model": "sglang/gpt-oss-120b",
      "temperature": 0.5
    },
    "general": {
      "model": "sglang/gpt-oss-120b"
    },
    "explore": {
      "model": "sglang/gpt-oss-120b"
    },
    "title": {
      "model": "sglang/gpt-oss-120b",
      "temperature": 0.5
    },
    "summary": {
      "model": "sglang/gpt-oss-120b"
    },
    "compaction": {
      "model": "sglang/gpt-oss-120b"
    }
  },

  // MCP 설정
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_TOKEN": "{env:GITHUB_TOKEN}"
      },
      "enabled": true
    },
    "git": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-git"],
      "enabled": true
    },
    "filesystem": {
      "type": "local",
      "command": [
        "npx", "-y",
        "@modelcontextprotocol/server-filesystem",
        "{env:HOME}/projects"
      ],
      "enabled": true
    }
  },

  // 권한 설정
  "permission": {
    "read": {
      "*": "allow",
      "*.env": "deny",
      "*.env.*": "deny"
    },
    "edit": {
      "*": "allow"
    },
    "bash": {
      "npm *": "allow",
      "bun *": "allow",
      "git *": "allow",
      "rm -rf *": "deny",
      "sudo *": "deny",
      "*": "ask"
    },
    "external_directory": "ask"
  },

  // TUI 설정
  "tui": {
    "scroll_speed": 1.0,
    "diff_style": "auto"
  },

  // 키바인드
  "keybinds": {
    "leader": "ctrl+x"
  },

  // Compaction
  "compaction": {
    "auto": true,
    "prune": true
  },

  // 실험적 기능
  "experimental": {
    "mcp_timeout": 30000
  }
}
```

---

## 10. 검증 및 테스트

### 10.1 설정 검증

```bash
# OpenCode 시작 (설정 로드 확인)
opencode

# 로그 레벨 높여서 디버깅
OPENCODE_LOG_LEVEL=debug opencode
```

### 10.2 Provider 연결 테스트

```bash
# OpenCode 내에서
> 안녕하세요. 현재 사용 중인 모델은 무엇인가요?
```

### 10.3 MCP 연결 테스트

```bash
# MCP 상태 확인
opencode mcp status
```

### 10.4 Agent 테스트

```bash
# OpenCode 내에서
> @explore src 디렉토리 구조를 분석해주세요.
> @general 간단한 작업을 처리해주세요.
```

### 10.5 Command 테스트

```bash
# OpenCode 내에서
> /commit 테스트 커밋
> /review src/index.ts
```

### 10.6 일반적인 문제 해결

| 문제 | 원인 | 해결 |
|------|------|------|
| 모델 연결 실패 | 서버 주소 오류 | baseURL 확인 |
| Tool calling 실패 | 모델 미지원 | tool_call: false 설정 |
| MCP 타임아웃 | 느린 서버 | timeout 증가 |
| 권한 거부 | 패턴 불일치 | 권한 설정 확인 |

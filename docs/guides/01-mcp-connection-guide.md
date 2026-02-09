# MCP (Model Context Protocol) 연결 가이드

## 개요

MCP(Model Context Protocol)는 AI 모델이 외부 도구, 데이터 소스, 서비스와 상호작용할 수 있게 해주는 프로토콜입니다. OpenCode는 MCP를 통해 파일 시스템, GitHub, 데이터베이스 등 다양한 외부 리소스에 접근할 수 있습니다.

---

## 목차

1. [MCP 기본 개념](#1-mcp-기본-개념)
2. [연결 유형](#2-연결-유형)
3. [설정 방법](#3-설정-방법)
4. [사용 가능한 MCP 서버](#4-사용-가능한-mcp-서버)
5. [인증 설정](#5-인증-설정)
6. [문제 해결](#6-문제-해결)

---

## 1. MCP 기본 개념

### 아키텍처

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    OpenCode     │────▶│   MCP Client    │────▶│   MCP Server    │
│   (AI Agent)    │◀────│   (내장)         │◀────│   (외부 도구)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │  External API   │
                                                │  File System    │
                                                │  Database       │
                                                └─────────────────┘
```

### 핵심 구성요소

| 구성요소 | 설명 |
|---------|------|
| **Client** | OpenCode에 내장된 MCP 클라이언트 |
| **Server** | 외부 도구를 제공하는 MCP 서버 |
| **Transport** | 통신 방식 (stdio, HTTP, SSE) |
| **Tools** | MCP 서버가 제공하는 기능들 |

---

## 2. 연결 유형

### 2.1 Local (로컬 프로세스)

로컬에서 실행되는 MCP 서버와 stdio를 통해 통신합니다.

**특징:**
- 빠른 응답 속도
- 로컬 리소스 접근 용이
- 별도 인증 불필요

**설정 스키마:**
```json
{
  "type": "local",
  "command": ["string", "array"],
  "environment": { "KEY": "VALUE" },
  "enabled": true,
  "timeout": 30000
}
```

**파라미터 설명:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `type` | string | O | `"local"` 고정 |
| `command` | string[] | O | 실행할 명령어와 인자 배열 |
| `environment` | object | X | 환경 변수 설정 |
| `enabled` | boolean | X | 활성화 여부 (기본: true) |
| `timeout` | number | X | 타임아웃 (ms, 기본: 30000) |

### 2.2 Remote (원격 서버)

HTTP/SSE를 통해 원격 MCP 서버와 통신합니다.

**특징:**
- 클라우드 서비스 연동 가능
- OAuth 인증 지원
- 네트워크 의존적

**설정 스키마:**
```json
{
  "type": "remote",
  "url": "https://mcp.example.com/sse",
  "enabled": true,
  "headers": { "Authorization": "Bearer token" },
  "oauth": { "clientId": "...", "scope": "..." },
  "timeout": 30000
}
```

**파라미터 설명:**

| 파라미터 | 타입 | 필수 | 설명 |
|---------|------|------|------|
| `type` | string | O | `"remote"` 고정 |
| `url` | string | O | MCP 서버 URL |
| `enabled` | boolean | X | 활성화 여부 |
| `headers` | object | X | HTTP 헤더 |
| `oauth` | object/false | X | OAuth 설정 또는 비활성화 |
| `timeout` | number | X | 타임아웃 (ms) |

---

## 3. 설정 방법

### 3.1 설정 파일 위치

우선순위 (높은 것부터):
1. 프로젝트 루트: `./opencode.json` 또는 `./opencode.jsonc`
2. 프로젝트 .opencode: `./.opencode/opencode.json`
3. 글로벌: `~/.config/opencode/opencode.json`

### 3.2 기본 설정 예시

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": [
        "npx", "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/username/projects"
      ],
      "enabled": true
    }
  }
}
```

### 3.3 환경 변수 사용

설정 파일에서 `{env:변수명}` 구문으로 환경 변수를 참조할 수 있습니다.

```json
{
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_TOKEN": "{env:GITHUB_TOKEN}"
      }
    }
  }
}
```

### 3.4 파일 내용 참조

`{file:경로}` 구문으로 파일 내용을 참조할 수 있습니다.

```json
{
  "mcp": {
    "custom": {
      "type": "remote",
      "url": "https://api.example.com/mcp",
      "headers": {
        "Authorization": "Bearer {file:~/.secrets/api-token}"
      }
    }
  }
}
```

---

## 4. 사용 가능한 MCP 서버

### 4.1 공식 MCP 서버

| 서버 | 패키지 | 용도 |
|-----|--------|------|
| Filesystem | `@modelcontextprotocol/server-filesystem` | 파일 시스템 접근 |
| GitHub | `@modelcontextprotocol/server-github` | GitHub API 연동 |
| Git | `@modelcontextprotocol/server-git` | Git 작업 |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | PostgreSQL DB |
| SQLite | `@modelcontextprotocol/server-sqlite` | SQLite DB |
| Slack | `@modelcontextprotocol/server-slack` | Slack 연동 |
| Memory | `@modelcontextprotocol/server-memory` | 메모리 저장소 |

### 4.2 설정 예시 모음

#### Filesystem 서버
```json
{
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": [
        "npx", "-y",
        "@modelcontextprotocol/server-filesystem",
        "/path/to/allowed/directory1",
        "/path/to/allowed/directory2"
      ]
    }
  }
}
```

#### GitHub 서버
```json
{
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_TOKEN": "{env:GITHUB_TOKEN}",
        "GITHUB_OWNER": "your-org",
        "GITHUB_REPO": "your-repo"
      }
    }
  }
}
```

#### Git 서버
```json
{
  "mcp": {
    "git": {
      "type": "local",
      "command": [
        "npx", "-y",
        "@modelcontextprotocol/server-git",
        "--repository", "/path/to/repo"
      ]
    }
  }
}
```

#### PostgreSQL 서버
```json
{
  "mcp": {
    "postgres": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-postgres"],
      "environment": {
        "POSTGRES_CONNECTION_STRING": "{env:DATABASE_URL}"
      }
    }
  }
}
```

---

## 5. 인증 설정

### 5.1 API 토큰 인증

```json
{
  "mcp": {
    "api-service": {
      "type": "remote",
      "url": "https://api.service.com/mcp",
      "headers": {
        "Authorization": "Bearer {env:API_TOKEN}",
        "X-API-Key": "{env:API_KEY}"
      }
    }
  }
}
```

### 5.2 OAuth 인증

OpenCode는 원격 MCP 서버에 대해 OAuth 인증을 지원합니다.

**자동 OAuth (Dynamic Client Registration):**
```json
{
  "mcp": {
    "oauth-service": {
      "type": "remote",
      "url": "https://mcp.service.com",
      "oauth": {
        "scope": "read write"
      }
    }
  }
}
```

**사전 등록된 클라이언트:**
```json
{
  "mcp": {
    "oauth-service": {
      "type": "remote",
      "url": "https://mcp.service.com",
      "oauth": {
        "clientId": "your-client-id",
        "clientSecret": "{env:OAUTH_CLIENT_SECRET}",
        "scope": "read write"
      }
    }
  }
}
```

**OAuth 비활성화:**
```json
{
  "mcp": {
    "no-oauth-service": {
      "type": "remote",
      "url": "https://api.service.com",
      "oauth": false
    }
  }
}
```

### 5.3 OAuth 인증 명령어

```bash
# MCP 서버 인증 시작
opencode mcp auth <mcp-name>

# 인증 제거
opencode mcp remove-auth <mcp-name>

# MCP 상태 확인
opencode mcp status
```

---

## 6. 문제 해결

### 6.1 일반적인 오류

#### 연결 실패
```
Error: Failed to connect to MCP server
```

**해결 방법:**
1. MCP 서버 명령어가 올바른지 확인
2. 필요한 패키지가 설치되어 있는지 확인
3. 환경 변수가 올바르게 설정되어 있는지 확인

#### 타임아웃
```
Error: MCP request timed out
```

**해결 방법:**
```json
{
  "mcp": {
    "slow-server": {
      "type": "local",
      "command": ["..."],
      "timeout": 60000
    }
  }
}
```

#### 인증 필요
```
Status: needs_auth
```

**해결 방법:**
```bash
opencode mcp auth <mcp-name>
```

### 6.2 디버깅

로그 레벨 설정으로 상세 로그 확인:
```json
{
  "logLevel": "debug"
}
```

또는 환경 변수로:
```bash
OPENCODE_LOG_LEVEL=debug opencode
```

### 6.3 MCP 상태 확인 API

```bash
# CLI로 상태 확인
opencode mcp status

# 프로그래밍 방식
GET /mcp/status
```

**상태 값:**
| 상태 | 설명 |
|------|------|
| `connected` | 정상 연결됨 |
| `disabled` | 비활성화됨 |
| `failed` | 연결 실패 |
| `needs_auth` | 인증 필요 |
| `needs_client_registration` | OAuth 클라이언트 등록 필요 |

---

## 부록: 전체 설정 예시

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "filesystem": {
      "type": "local",
      "command": [
        "npx", "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/username/projects"
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
    },
    "postgres": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-postgres"],
      "environment": {
        "POSTGRES_CONNECTION_STRING": "{env:DATABASE_URL}"
      },
      "enabled": false
    },
    "remote-api": {
      "type": "remote",
      "url": "https://mcp.api.example.com/sse",
      "headers": {
        "Authorization": "Bearer {env:API_TOKEN}"
      },
      "oauth": false,
      "timeout": 60000
    }
  },
  "experimental": {
    "mcp_timeout": 30000
  }
}
```
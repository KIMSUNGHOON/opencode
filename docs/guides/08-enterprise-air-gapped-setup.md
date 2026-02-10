> **Note**: This document references `gpt-oss-120b` model IDs which are outdated. The current system uses a single model: `glm/GLM-4.7-FP8` (SGLang port 8000) with built-in Interleaved Thinking. See [14-code-qa-v4-quick-start.md](./14-code-qa-v4-quick-start.md) for current configuration. The air-gapped infrastructure patterns described here remain valid.

# 사내 보안 인프라 (Air-gapped) 환경 구축 가이드

## 개요

이 문서는 인터넷이 제한되거나 완전히 차단된 사내 보안 인프라 환경에서 OpenCode를 구축하는 방법을 설명합니다. GitLab CE (Community Edition, 무료 오픈소스)와 로컬 LLM 서버를 활용하여 외부 의존성 없이 완전한 AI 코딩 환경을 구성합니다.

---

## 목차

1. [아키텍처 개요](#1-아키텍처-개요)
2. [필수 요구사항](#2-필수-요구사항)
3. [LLM 서버 구축](#3-llm-서버-구축)
4. [GitLab CE 설정](#4-gitlab-ce-설정)
5. [MCP 서버 설정](#5-mcp-서버-설정)
6. [OpenCode 설정](#6-opencode-설정)
7. [보안 설정](#7-보안-설정)
8. [운영 가이드](#8-운영-가이드)
9. [문제 해결](#9-문제-해결)
10. [체크리스트](#10-체크리스트)

---

## 1. 아키텍처 개요

### 1.1 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      사내 보안 인프라 (Air-gapped Network)                    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         GPU 서버 클러스터                            │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │   │
│  │  │   GPU Node 1    │  │   GPU Node 2    │  │   GPU Node N    │     │   │
│  │  │  A100 80GB x4   │  │  A100 80GB x4   │  │  A100 80GB x4   │     │   │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘     │   │
│  │           │                    │                    │               │   │
│  │           └────────────────────┼────────────────────┘               │   │
│  │                                │                                    │   │
│  │                    ┌───────────▼───────────┐                        │   │
│  │                    │   Load Balancer       │                        │   │
│  │                    │   (HAProxy/Nginx)     │                        │   │
│  │                    │   llm.internal:30000  │                        │   │
│  │                    └───────────────────────┘                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    │ OpenAI Compatible API                  │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Application Layer                            │   │
│  │                                                                      │   │
│  │  ┌─────────────────┐         ┌─────────────────────────────────┐   │   │
│  │  │   GitLab CE     │         │          개발자 PC               │   │   │
│  │  │   Server        │◄───────▶│                                 │   │   │
│  │  │                 │  API    │  ┌─────────────────────────┐   │   │   │
│  │  │  gitlab.internal│         │  │      OpenCode           │   │   │   │
│  │  │                 │         │  │                         │   │   │   │
│  │  │  - 코드 저장소  │         │  │  ┌─────────────────┐   │   │   │   │
│  │  │  - 이슈 관리    │         │  │  │  LLM Provider   │   │   │   │   │
│  │  │  - MR 관리      │         │  │  │  (로컬 서버)    │   │   │   │   │
│  │  │  - CI/CD        │         │  │  └─────────────────┘   │   │   │   │
│  │  └─────────────────┘         │  │                         │   │   │   │
│  │           │                   │  │  ┌─────────────────┐   │   │   │   │
│  │           │                   │  │  │  GitLab MCP     │   │   │   │   │
│  │           └──────────────────▶│  │  │  Server         │   │   │   │   │
│  │                               │  │  └─────────────────┘   │   │   │   │
│  │                               │  └─────────────────────────┘   │   │   │
│  │                               └─────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         지원 인프라                                  │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │   │
│  │  │  Internal NPM   │  │   Docker        │  │    NFS/S3       │     │   │
│  │  │  Registry       │  │   Registry      │  │    Storage      │     │   │
│  │  │  npm.internal   │  │   registry.int  │  │    storage.int  │     │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 데이터 흐름

```
개발자 요청
     │
     ▼
┌─────────────┐
│  OpenCode   │
│  (Client)   │
└──────┬──────┘
       │
       ├─────────────────────────────────────────┐
       │                                         │
       ▼                                         ▼
┌─────────────┐                          ┌─────────────┐
│  LLM Server │                          │ GitLab MCP  │
│  (sglang)   │                          │   Server    │
└──────┬──────┘                          └──────┬──────┘
       │                                         │
       │ AI 응답                                 │ GitLab API
       │                                         │
       ▼                                         ▼
┌─────────────┐                          ┌─────────────┐
│  코드 생성  │                          │  이슈/MR    │
│  분석/리뷰  │                          │  코드 관리  │
└─────────────┘                          └─────────────┘
```

### 1.3 컴포넌트 역할

| 컴포넌트 | 역할 | 포트 |
|----------|------|------|
| LLM Server (sglang) | AI 추론, 코드 생성 | 30000 |
| GitLab CE | 코드 저장소, 이슈/MR 관리 | 80/443 |
| GitLab MCP Server | GitLab API 브릿지 | stdio |
| OpenCode | AI 코딩 에이전트 | - |
| Internal NPM Registry | 패키지 관리 | 4873 |

---

## 2. 필수 요구사항

### 2.1 하드웨어 요구사항

#### LLM 서버

| 모델 | 최소 GPU | 권장 GPU | VRAM |
|------|----------|----------|------|
| GPT-OSS-120B | A100 40GB x4 | A100 80GB x4 | 160GB+ |
| DeepSeek-V3 | A100 80GB x4 | A100 80GB x8 | 320GB+ |
| Llama 3.3 70B | A100 40GB x2 | A100 80GB x2 | 140GB+ |
| Qwen 2.5 72B | A100 40GB x2 | A100 80GB x2 | 144GB+ |

#### 양자화 옵션

| 양자화 | VRAM 절감 | 품질 | 권장 |
|--------|----------|------|------|
| FP16 | 0% | 100% | 프로덕션 |
| INT8 | 50% | 95% | 균형 |
| INT4 | 75% | 85% | 리소스 제한 |

#### GitLab CE 서버

| 사용자 수 | CPU | RAM | 저장소 |
|----------|-----|-----|--------|
| ~100명 | 8 cores | 16GB | 500GB SSD |
| ~500명 | 16 cores | 32GB | 1TB SSD |
| ~1000명 | 32 cores | 64GB | 2TB SSD |

#### 개발자 PC

| 항목 | 최소 | 권장 |
|------|------|------|
| CPU | 4 cores | 8+ cores |
| RAM | 8GB | 16GB+ |
| 저장소 | 50GB | 100GB+ SSD |
| 네트워크 | 100Mbps | 1Gbps |

### 2.2 소프트웨어 요구사항

#### LLM 서버

```bash
# OS
Ubuntu 22.04 LTS / RHEL 8+

# CUDA
CUDA 12.1+
cuDNN 8.9+

# Python
Python 3.10+

# 패키지
pip install sglang[all]  # 또는 vllm
```

#### GitLab CE

```bash
# OS
Ubuntu 22.04 LTS / RHEL 8+ / Debian 12

# 패키지
GitLab CE 16.0+ (omnibus)
```

#### 개발자 PC

```bash
# Runtime
Node.js 20+
Bun 1.3+ (권장)

# 패키지
npm install -g opencode-ai
```

### 2.3 네트워크 요구사항

| 출발지 | 목적지 | 포트 | 프로토콜 | 용도 |
|--------|--------|------|----------|------|
| 개발자 PC | LLM Server | 30000 | HTTP | AI 추론 |
| 개발자 PC | GitLab CE | 443/80 | HTTPS/HTTP | 코드 관리 |
| 개발자 PC | NPM Registry | 4873 | HTTP | 패키지 |
| GitLab MCP | GitLab CE | 443/80 | HTTPS/HTTP | API |

---

## 3. LLM 서버 구축

### 3.1 sglang 설치

```bash
# 1. CUDA 환경 확인
nvidia-smi
nvcc --version

# 2. Python 가상환경 생성
python -m venv /opt/sglang-env
source /opt/sglang-env/bin/activate

# 3. sglang 설치
pip install --upgrade pip
pip install sglang[all]

# 4. 모델 다운로드 (인터넷 있는 환경에서)
# Hugging Face에서 모델 다운로드 후 내부 스토리지로 복사
huggingface-cli download \
  --local-dir /models/gpt-oss-120b \
  gpt-oss/gpt-oss-120b
```

### 3.2 Air-gapped 환경 모델 전송

```bash
# 인터넷 환경에서 모델 다운로드
huggingface-cli download \
  --local-dir ./gpt-oss-120b \
  gpt-oss/gpt-oss-120b

# 압축
tar -czvf gpt-oss-120b.tar.gz gpt-oss-120b/

# 물리적 또는 보안 채널을 통해 내부 전송
# USB, 전용 전송 서버 등

# 내부 환경에서 압축 해제
tar -xzvf gpt-oss-120b.tar.gz -C /models/
```

### 3.3 sglang 서버 시작

```bash
# 단일 노드 (GPU 4장)
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --port 30000 \
  --host 0.0.0.0 \
  --tp 4 \
  --trust-remote-code \
  --mem-fraction-static 0.85

# 다중 노드 (분산 추론)
# Node 0 (Master)
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --port 30000 \
  --host 0.0.0.0 \
  --tp 8 \
  --nccl-init-addr node0:29500 \
  --nnodes 2 \
  --node-rank 0

# Node 1
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --port 30000 \
  --host 0.0.0.0 \
  --tp 8 \
  --nccl-init-addr node0:29500 \
  --nnodes 2 \
  --node-rank 1
```

### 3.4 Systemd 서비스 등록

```ini
# /etc/systemd/system/sglang.service
[Unit]
Description=SGLang LLM Server
After=network.target

[Service]
Type=simple
User=llm
Group=llm
WorkingDirectory=/opt/sglang
Environment="PATH=/opt/sglang-env/bin:/usr/local/cuda/bin:$PATH"
Environment="CUDA_VISIBLE_DEVICES=0,1,2,3"
ExecStart=/opt/sglang-env/bin/python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --port 30000 \
  --host 0.0.0.0 \
  --tp 4 \
  --trust-remote-code \
  --mem-fraction-static 0.85
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 서비스 활성화
sudo systemctl daemon-reload
sudo systemctl enable sglang
sudo systemctl start sglang

# 상태 확인
sudo systemctl status sglang
```

### 3.5 연결 테스트

```bash
# Health check
curl http://llm.internal:30000/health

# 모델 정보
curl http://llm.internal:30000/v1/models

# 추론 테스트
curl http://llm.internal:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss-120b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

---

## 4. GitLab CE 설정

### 4.1 GitLab CE 설치

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl

# GitLab 패키지 저장소 추가
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

# GitLab CE 설치
sudo EXTERNAL_URL="https://gitlab.internal.company.com" apt-get install gitlab-ce
```

### 4.2 Air-gapped 설치

```bash
# 인터넷 환경에서 패키지 다운로드
wget https://packages.gitlab.com/gitlab/gitlab-ce/packages/ubuntu/jammy/gitlab-ce_16.x.x-ce.0_amd64.deb/download.deb

# 내부 전송 후 설치
sudo dpkg -i gitlab-ce_16.x.x-ce.0_amd64.deb

# 설정
sudo gitlab-ctl reconfigure
```

### 4.3 GitLab 설정 최적화

```ruby
# /etc/gitlab/gitlab.rb

# 외부 URL
external_url 'https://gitlab.internal.company.com'

# HTTPS 설정 (인증서)
nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.key"

# API 설정
gitlab_rails['api_cidr_allowlist'] = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']

# 성능 최적화
postgresql['shared_buffers'] = "4GB"
postgresql['work_mem'] = "128MB"
puma['worker_processes'] = 4
sidekiq['concurrency'] = 25

# 이메일 (내부 SMTP)
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.internal.company.com"
gitlab_rails['smtp_port'] = 25
```

```bash
# 설정 적용
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
```

### 4.4 Personal Access Token 생성

```
1. GitLab 웹 접속: https://gitlab.internal.company.com
2. 프로필 → Settings → Access Tokens
3. 새 토큰 생성:
   - Name: opencode-mcp
   - Expiration: 필요에 따라 설정
   - Scopes:
     ✅ api
     ✅ read_repository
     ✅ write_repository
     ✅ read_user
4. 토큰 저장 (한 번만 표시됨)
```

### 4.5 API 테스트

```bash
# 토큰 설정
export GITLAB_TOKEN="glpat-xxxxx"
export GITLAB_URL="https://gitlab.internal.company.com"

# API 테스트
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects"

# 사용자 정보
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/user"
```

---

## 5. MCP 서버 설정

### 5.1 Internal NPM Registry 설정 (Verdaccio)

```bash
# Verdaccio 설치
npm install -g verdaccio

# 설정 파일
mkdir -p /opt/verdaccio
cat > /opt/verdaccio/config.yaml << 'EOF'
storage: /opt/verdaccio/storage
plugins: /opt/verdaccio/plugins

web:
  title: Internal NPM Registry
  enable: true

auth:
  htpasswd:
    file: /opt/verdaccio/htpasswd
    max_users: 1000

uplinks:
  # Air-gapped 환경에서는 uplinks 비활성화
  # npmjs:
  #   url: https://registry.npmjs.org/

packages:
  '@*/*':
    access: $authenticated
    publish: $authenticated

  '**':
    access: $authenticated
    publish: $authenticated

server:
  keepAliveTimeout: 60

listen:
  - 0.0.0.0:4873

logs:
  - { type: stdout, format: pretty, level: info }
EOF

# 서비스 시작
verdaccio --config /opt/verdaccio/config.yaml
```

### 5.2 MCP 패키지 미러링

```bash
# 인터넷 환경에서 패키지 다운로드
npm pack @modelcontextprotocol/server-gitlab
npm pack @modelcontextprotocol/sdk

# 내부 Registry에 퍼블리시
npm publish modelcontextprotocol-server-gitlab-x.x.x.tgz \
  --registry http://npm.internal:4873

npm publish modelcontextprotocol-sdk-x.x.x.tgz \
  --registry http://npm.internal:4873
```

### 5.3 개발자 PC NPM 설정

```bash
# NPM Registry 설정
npm config set registry http://npm.internal:4873

# 또는 .npmrc 파일
cat > ~/.npmrc << 'EOF'
registry=http://npm.internal:4873/
strict-ssl=false
EOF

# 패키지 설치 테스트
npm install @modelcontextprotocol/server-gitlab
```

### 5.4 MCP 서버 로컬 설치

```bash
# 글로벌 설치
npm install -g @modelcontextprotocol/server-gitlab

# 또는 프로젝트 로컬 설치
npm install @modelcontextprotocol/server-gitlab

# 설치 확인
which modelcontextprotocol-server-gitlab
# 또는
npx @modelcontextprotocol/server-gitlab --help
```

---

## 6. OpenCode 설정

### 6.1 OpenCode 설치

```bash
# Bun 설치 (권장)
curl -fsSL https://bun.sh/install | bash

# 또는 내부 미러에서
curl -fsSL http://mirror.internal/bun/install.sh | bash

# OpenCode 설치
npm install -g opencode-ai

# 또는 내부 Registry에서
npm install -g opencode-ai --registry http://npm.internal:4873
```

### 6.2 전체 설정 파일

프로젝트 루트 또는 `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",

  "model": "internal/gpt-oss-120b",
  "small_model": "internal/gpt-oss-120b",

  "logLevel": "info",
  "autoupdate": false,
  "share": "disabled",

  "provider": {
    "internal": {
      "name": "사내 LLM 서버",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://llm.internal.company.com:30000/v1",
      "env": [],
      "options": {
        "apiKey": "internal",
        "baseURL": "http://llm.internal.company.com:30000/v1",
        "timeout": 300000
      },
      "models": {
        "gpt-oss-120b": {
          "name": "GPT-OSS-120B (사내)",
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

  "agent": {
    "build": {
      "model": "internal/gpt-oss-120b",
      "temperature": 0.7,
      "steps": 100
    },
    "plan": {
      "model": "internal/gpt-oss-120b",
      "temperature": 0.3
    },
    "general": {
      "model": "internal/gpt-oss-120b"
    },
    "explore": {
      "model": "internal/gpt-oss-120b"
    },
    "title": {
      "model": "internal/gpt-oss-120b",
      "temperature": 0.5
    },
    "summary": {
      "model": "internal/gpt-oss-120b"
    },
    "compaction": {
      "model": "internal/gpt-oss-120b"
    }
  },

  "mcp": {
    "gitlab": {
      "type": "local",
      "command": ["npx", "@modelcontextprotocol/server-gitlab"],
      "environment": {
        "GITLAB_PERSONAL_ACCESS_TOKEN": "{env:GITLAB_TOKEN}",
        "GITLAB_API_URL": "https://gitlab.internal.company.com/api/v4"
      },
      "enabled": true,
      "timeout": 30000
    }
  },

  "permission": {
    "read": {
      "*": "allow",
      "*.env": "deny",
      "*.env.*": "deny",
      "*.pem": "deny",
      "*.key": "deny",
      "**/credentials*": "deny"
    },
    "edit": {
      "*": "allow"
    },
    "bash": {
      "git *": "allow",
      "npm *": "allow",
      "bun *": "allow",
      "rm -rf *": "deny",
      "sudo *": "deny",
      "*": "ask"
    },
    "external_directory": "ask"
  },

  "compaction": {
    "auto": true,
    "prune": true
  },

  "experimental": {
    "mcp_timeout": 30000
  }
}
```

### 6.3 환경 변수 설정

```bash
# ~/.bashrc 또는 ~/.zshrc에 추가
export GITLAB_TOKEN="glpat-xxxxx"
export GITLAB_API_URL="https://gitlab.internal.company.com/api/v4"

# NPM Registry
export NPM_CONFIG_REGISTRY="http://npm.internal:4873"

# 적용
source ~/.bashrc
```

### 6.4 연결 테스트

```bash
# OpenCode 시작
opencode

# 내부에서 테스트
> 안녕하세요. 현재 사용 중인 모델은 무엇인가요?

# GitLab MCP 테스트
> GitLab에서 내 프로젝트 목록을 보여주세요.
```

---

## 7. 보안 설정

### 7.1 네트워크 보안

```bash
# 방화벽 설정 (firewalld)
# LLM 서버
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port port="30000" protocol="tcp" accept'

# GitLab
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port port="443" protocol="tcp" accept'

# 적용
sudo firewall-cmd --reload
```

### 7.2 TLS 설정

```bash
# 내부 CA에서 인증서 발급
# LLM 서버용
openssl req -new -key llm.key -out llm.csr \
  -subj "/CN=llm.internal.company.com"

# GitLab용
openssl req -new -key gitlab.key -out gitlab.csr \
  -subj "/CN=gitlab.internal.company.com"

# 내부 CA로 서명
# ...
```

### 7.3 LLM 서버 HTTPS 설정 (Nginx Reverse Proxy)

```nginx
# /etc/nginx/conf.d/llm.conf
upstream sglang {
    server 127.0.0.1:30000;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name llm.internal.company.com;

    ssl_certificate /etc/nginx/ssl/llm.crt;
    ssl_certificate_key /etc/nginx/ssl/llm.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://sglang;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Connection "";
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
```

### 7.4 API 인증 설정

```json
{
  "provider": {
    "internal": {
      "options": {
        "apiKey": "{env:INTERNAL_LLM_API_KEY}",
        "headers": {
          "X-Internal-Auth": "{env:INTERNAL_AUTH_TOKEN}"
        }
      }
    }
  }
}
```

### 7.5 감사 로깅

```bash
# LLM 서버 요청 로깅
# sglang 시작 시 로깅 활성화
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --log-level info \
  --log-requests \
  --log-dir /var/log/sglang

# 로그 로테이션
cat > /etc/logrotate.d/sglang << 'EOF'
/var/log/sglang/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

---

## 8. 운영 가이드

### 8.1 모니터링

#### Prometheus 메트릭

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'sglang'
    static_configs:
      - targets: ['llm.internal:30000']
    metrics_path: /metrics

  - job_name: 'gitlab'
    static_configs:
      - targets: ['gitlab.internal:9168']
```

#### Grafana 대시보드

```
주요 메트릭:
- GPU 사용률 (nvidia_gpu_utilization)
- 추론 지연 시간 (sglang_request_latency)
- 토큰 처리량 (sglang_tokens_per_second)
- 요청 큐 길이 (sglang_queue_length)
- GitLab API 응답 시간
```

### 8.2 백업

```bash
# LLM 모델 백업 (변경되지 않으므로 최초 1회)
tar -czvf /backup/models/gpt-oss-120b.tar.gz /models/gpt-oss-120b

# GitLab 백업
sudo gitlab-backup create

# 백업 스케줄링
crontab -e
# 0 2 * * * /opt/gitlab/bin/gitlab-backup create CRON=1
```

### 8.3 업데이트 절차

```bash
# 1. 모델 업데이트 (필요시)
# 인터넷 환경에서 다운로드 → 내부 전송 → 교체

# 2. sglang 업데이트
pip install --upgrade sglang[all]
sudo systemctl restart sglang

# 3. GitLab 업데이트
sudo apt-get update
sudo apt-get install gitlab-ce

# 4. MCP 패키지 업데이트
npm update @modelcontextprotocol/server-gitlab

# 5. OpenCode 업데이트
npm update -g opencode-ai
```

### 8.4 장애 대응

```bash
# LLM 서버 상태 확인
curl http://llm.internal:30000/health
sudo systemctl status sglang
journalctl -u sglang -f

# GitLab 상태 확인
sudo gitlab-ctl status
sudo gitlab-rake gitlab:check

# MCP 연결 확인
opencode mcp status
```

---

## 9. 문제 해결

### 9.1 일반적인 문제

| 문제 | 원인 | 해결 |
|------|------|------|
| LLM 연결 실패 | 네트워크/방화벽 | 포트 30000 확인 |
| GPU OOM | VRAM 부족 | 양자화 적용 또는 tp 증가 |
| GitLab 인증 실패 | 토큰 만료 | 새 토큰 발급 |
| MCP 타임아웃 | 네트워크 느림 | timeout 증가 |
| NPM 패키지 없음 | 미러 미설정 | 패키지 퍼블리시 |

### 9.2 디버깅

```bash
# OpenCode 디버그 모드
OPENCODE_LOG_LEVEL=debug opencode

# LLM 서버 로그
journalctl -u sglang -f

# GitLab 로그
sudo gitlab-ctl tail

# 네트워크 테스트
curl -v http://llm.internal:30000/health
curl -v https://gitlab.internal/api/v4/projects \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN"
```

### 9.3 성능 튜닝

```bash
# GPU 최적화
export CUDA_VISIBLE_DEVICES=0,1,2,3
export NCCL_P2P_DISABLE=0
export NCCL_IB_DISABLE=0

# sglang 메모리 최적화
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --mem-fraction-static 0.9 \
  --max-running-requests 8 \
  --max-num-reqs 32
```

---

## 10. 체크리스트

### 10.1 구축 전 체크리스트

- [ ] GPU 서버 하드웨어 준비
- [ ] 네트워크 구성 확인 (방화벽, DNS)
- [ ] 모델 파일 다운로드 및 내부 전송
- [ ] 인증서 준비 (내부 CA)
- [ ] GitLab CE 서버 준비
- [ ] Internal NPM Registry 준비

### 10.2 구축 체크리스트

- [ ] CUDA/cuDNN 설치
- [ ] sglang 설치 및 서비스 등록
- [ ] LLM 서버 연결 테스트
- [ ] GitLab CE 설치 및 설정
- [ ] GitLab PAT 생성
- [ ] GitLab API 테스트
- [ ] NPM Registry 설정
- [ ] MCP 패키지 미러링
- [ ] OpenCode 설치
- [ ] OpenCode 설정 파일 작성
- [ ] 전체 연결 테스트

### 10.3 보안 체크리스트

- [ ] 방화벽 규칙 적용
- [ ] TLS 인증서 설치
- [ ] API 인증 설정
- [ ] 감사 로깅 활성화
- [ ] 권한 최소화 적용
- [ ] 민감 파일 접근 차단

### 10.4 운영 체크리스트

- [ ] 모니터링 설정
- [ ] 알림 설정
- [ ] 백업 스케줄 설정
- [ ] 업데이트 절차 문서화
- [ ] 장애 대응 절차 문서화
- [ ] 사용자 교육

---

## 부록: 빠른 시작 스크립트

### setup-env.sh

```bash
#!/bin/bash
# 환경 변수 설정 스크립트

# GitLab 설정
export GITLAB_TOKEN="glpat-your-token-here"
export GITLAB_API_URL="https://gitlab.internal.company.com/api/v4"

# NPM Registry
export NPM_CONFIG_REGISTRY="http://npm.internal:4873"

# LLM 서버 (선택적)
export INTERNAL_LLM_URL="http://llm.internal.company.com:30000/v1"

echo "환경 변수 설정 완료"
echo "GITLAB_API_URL: $GITLAB_API_URL"
echo "NPM_CONFIG_REGISTRY: $NPM_CONFIG_REGISTRY"
```

### verify-setup.sh

```bash
#!/bin/bash
# 설정 검증 스크립트

echo "=== 설정 검증 시작 ==="

# 1. LLM 서버
echo -n "LLM 서버 연결: "
if curl -s http://llm.internal:30000/health > /dev/null; then
  echo "✅ 성공"
else
  echo "❌ 실패"
fi

# 2. GitLab API
echo -n "GitLab API 연결: "
if curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_API_URL/user" | grep -q "username"; then
  echo "✅ 성공"
else
  echo "❌ 실패"
fi

# 3. NPM Registry
echo -n "NPM Registry 연결: "
if curl -s http://npm.internal:4873/-/ping | grep -q "ok"; then
  echo "✅ 성공"
else
  echo "❌ 실패"
fi

# 4. OpenCode
echo -n "OpenCode 설치: "
if command -v opencode &> /dev/null; then
  echo "✅ 설치됨 ($(opencode --version))"
else
  echo "❌ 미설치"
fi

echo "=== 검증 완료 ==="
```

# Enterprise Air-Gapped Infrastructure Setup Guide

## Overview

This document explains how to set up OpenCode in an enterprise security infrastructure environment where internet access is restricted or completely blocked. By leveraging GitLab CE (Community Edition, free open-source) and a local LLM server, a complete AI coding environment is configured without any external dependencies.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [LLM Server Setup](#3-llm-server-setup)
4. [GitLab CE Configuration](#4-gitlab-ce-configuration)
5. [MCP Server Configuration](#5-mcp-server-configuration)
6. [OpenCode Configuration](#6-opencode-configuration)
7. [Security Configuration](#7-security-configuration)
8. [Operations Guide](#8-operations-guide)
9. [Troubleshooting](#9-troubleshooting)
10. [Checklists](#10-checklists)

---

## 1. Architecture Overview

### 1.1 Overall Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Enterprise Security Infrastructure (Air-gapped Network)│
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         GPU Server Cluster                          │   │
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
│  │  │   GitLab CE     │         │          Developer PC            │   │   │
│  │  │   Server        │◄───────▶│                                 │   │   │
│  │  │                 │  API    │  ┌─────────────────────────┐   │   │   │
│  │  │  gitlab.internal│         │  │      OpenCode           │   │   │   │
│  │  │                 │         │  │                         │   │   │   │
│  │  │  - Code repos   │         │  │  ┌─────────────────┐   │   │   │   │
│  │  │  - Issue mgmt   │         │  │  │  LLM Provider   │   │   │   │   │
│  │  │  - MR mgmt      │         │  │  │  (Local server) │   │   │   │   │
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
│  │                         Supporting Infrastructure                    │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │   │
│  │  │  Internal NPM   │  │   Docker        │  │    NFS/S3       │     │   │
│  │  │  Registry       │  │   Registry      │  │    Storage      │     │   │
│  │  │  npm.internal   │  │   registry.int  │  │    storage.int  │     │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow

```
Developer Request
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
       │ AI Response                             │ GitLab API
       │                                         │
       ▼                                         ▼
┌─────────────┐                          ┌─────────────┐
│  Code Gen   │                          │  Issue/MR   │
│  Analysis/  │                          │  Code Mgmt  │
│  Review     │                          │             │
└─────────────┘                          └─────────────┘
```

### 1.3 Component Roles

| Component | Role | Port |
|-----------|------|------|
| LLM Server (sglang) | AI inference, code generation | 30000 |
| GitLab CE | Code repository, issue/MR management | 80/443 |
| GitLab MCP Server | GitLab API bridge | stdio |
| OpenCode | AI coding agent | - |
| Internal NPM Registry | Package management | 4873 |

---

## 2. Prerequisites

### 2.1 Hardware Requirements

#### LLM Server

| Model | Minimum GPU | Recommended GPU | VRAM |
|-------|-------------|-----------------|------|
| GPT-OSS-120B | A100 40GB x4 | A100 80GB x4 | 160GB+ |
| DeepSeek-V3 | A100 80GB x4 | A100 80GB x8 | 320GB+ |
| Llama 3.3 70B | A100 40GB x2 | A100 80GB x2 | 140GB+ |
| Qwen 2.5 72B | A100 40GB x2 | A100 80GB x2 | 144GB+ |

#### Quantization Options

| Quantization | VRAM Savings | Quality | Recommendation |
|-------------|-------------|---------|----------------|
| FP16 | 0% | 100% | Production |
| INT8 | 50% | 95% | Balanced |
| INT4 | 75% | 85% | Resource-constrained |

#### GitLab CE Server

| Number of Users | CPU | RAM | Storage |
|----------------|-----|-----|---------|
| ~100 | 8 cores | 16GB | 500GB SSD |
| ~500 | 16 cores | 32GB | 1TB SSD |
| ~1000 | 32 cores | 64GB | 2TB SSD |

#### Developer PC

| Item | Minimum | Recommended |
|------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 8GB | 16GB+ |
| Storage | 50GB | 100GB+ SSD |
| Network | 100Mbps | 1Gbps |

### 2.2 Software Requirements

#### LLM Server

```bash
# OS
Ubuntu 22.04 LTS / RHEL 8+

# CUDA
CUDA 12.1+
cuDNN 8.9+

# Python
Python 3.10+

# Packages
pip install sglang[all]  # or vllm
```

#### GitLab CE

```bash
# OS
Ubuntu 22.04 LTS / RHEL 8+ / Debian 12

# Packages
GitLab CE 16.0+ (omnibus)
```

#### Developer PC

```bash
# Runtime
Node.js 20+
Bun 1.3+ (recommended)

# Packages
npm install -g opencode-ai
```

### 2.3 Network Requirements

| Source | Destination | Port | Protocol | Purpose |
|--------|------------|------|----------|---------|
| Developer PC | LLM Server | 30000 | HTTP | AI inference |
| Developer PC | GitLab CE | 443/80 | HTTPS/HTTP | Code management |
| Developer PC | NPM Registry | 4873 | HTTP | Packages |
| GitLab MCP | GitLab CE | 443/80 | HTTPS/HTTP | API |

---

## 3. LLM Server Setup

### 3.1 sglang Installation

```bash
# 1. Verify CUDA environment
nvidia-smi
nvcc --version

# 2. Create Python virtual environment
python -m venv /opt/sglang-env
source /opt/sglang-env/bin/activate

# 3. Install sglang
pip install --upgrade pip
pip install sglang[all]

# 4. Download model (from an internet-connected environment)
# Download model from Hugging Face and copy to internal storage
huggingface-cli download \
  --local-dir /models/gpt-oss-120b \
  gpt-oss/gpt-oss-120b
```

### 3.2 Air-gapped Environment Model Transfer

```bash
# Download model from internet-connected environment
huggingface-cli download \
  --local-dir ./gpt-oss-120b \
  gpt-oss/gpt-oss-120b

# Compress
tar -czvf gpt-oss-120b.tar.gz gpt-oss-120b/

# Transfer internally via physical or secure channel
# USB, dedicated transfer server, etc.

# Extract in internal environment
tar -xzvf gpt-oss-120b.tar.gz -C /models/
```

### 3.3 Starting the sglang Server

```bash
# Single node (4 GPUs)
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --port 30000 \
  --host 0.0.0.0 \
  --tp 4 \
  --trust-remote-code \
  --mem-fraction-static 0.85

# Multi-node (distributed inference)
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

### 3.4 Systemd Service Registration

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
# Enable service
sudo systemctl daemon-reload
sudo systemctl enable sglang
sudo systemctl start sglang

# Check status
sudo systemctl status sglang
```

### 3.5 Connection Test

```bash
# Health check
curl http://llm.internal:30000/health

# Model info
curl http://llm.internal:30000/v1/models

# Inference test
curl http://llm.internal:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-oss-120b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

---

## 4. GitLab CE Configuration

### 4.1 GitLab CE Installation

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl

# Add GitLab package repository
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

# Install GitLab CE
sudo EXTERNAL_URL="https://gitlab.internal.company.com" apt-get install gitlab-ce
```

### 4.2 Air-gapped Installation

```bash
# Download package from internet-connected environment
wget https://packages.gitlab.com/gitlab/gitlab-ce/packages/ubuntu/jammy/gitlab-ce_16.x.x-ce.0_amd64.deb/download.deb

# Transfer internally and install
sudo dpkg -i gitlab-ce_16.x.x-ce.0_amd64.deb

# Configure
sudo gitlab-ctl reconfigure
```

### 4.3 GitLab Configuration Optimization

```ruby
# /etc/gitlab/gitlab.rb

# External URL
external_url 'https://gitlab.internal.company.com'

# HTTPS configuration (certificates)
nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.key"

# API configuration
gitlab_rails['api_cidr_allowlist'] = ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']

# Performance optimization
postgresql['shared_buffers'] = "4GB"
postgresql['work_mem'] = "128MB"
puma['worker_processes'] = 4
sidekiq['concurrency'] = 25

# Email (internal SMTP)
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.internal.company.com"
gitlab_rails['smtp_port'] = 25
```

```bash
# Apply configuration
sudo gitlab-ctl reconfigure
sudo gitlab-ctl restart
```

### 4.4 Personal Access Token Generation

```
1. Access GitLab web UI: https://gitlab.internal.company.com
2. Profile → Settings → Access Tokens
3. Create new token:
   - Name: opencode-mcp
   - Expiration: Set as needed
   - Scopes:
     ✅ api
     ✅ read_repository
     ✅ write_repository
     ✅ read_user
4. Save the token (displayed only once)
```

### 4.5 API Test

```bash
# Set token
export GITLAB_TOKEN="glpat-xxxxx"
export GITLAB_URL="https://gitlab.internal.company.com"

# API test
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects"

# User info
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/user"
```

---

## 5. MCP Server Configuration

### 5.1 Internal NPM Registry Setup (Verdaccio)

```bash
# Install Verdaccio
npm install -g verdaccio

# Configuration file
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
  # Disable uplinks in air-gapped environment
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

# Start service
verdaccio --config /opt/verdaccio/config.yaml
```

### 5.2 MCP Package Mirroring

```bash
# Download packages from internet-connected environment
npm pack @modelcontextprotocol/server-gitlab
npm pack @modelcontextprotocol/sdk

# Publish to internal registry
npm publish modelcontextprotocol-server-gitlab-x.x.x.tgz \
  --registry http://npm.internal:4873

npm publish modelcontextprotocol-sdk-x.x.x.tgz \
  --registry http://npm.internal:4873
```

### 5.3 Developer PC NPM Configuration

```bash
# Set NPM registry
npm config set registry http://npm.internal:4873

# Or via .npmrc file
cat > ~/.npmrc << 'EOF'
registry=http://npm.internal:4873/
strict-ssl=false
EOF

# Test package installation
npm install @modelcontextprotocol/server-gitlab
```

### 5.4 MCP Server Local Installation

```bash
# Global installation
npm install -g @modelcontextprotocol/server-gitlab

# Or project-local installation
npm install @modelcontextprotocol/server-gitlab

# Verify installation
which modelcontextprotocol-server-gitlab
# or
npx @modelcontextprotocol/server-gitlab --help
```

---

## 6. OpenCode Configuration

### 6.1 OpenCode Installation

```bash
# Install Bun (recommended)
curl -fsSL https://bun.sh/install | bash

# Or from internal mirror
curl -fsSL http://mirror.internal/bun/install.sh | bash

# Install OpenCode
npm install -g opencode-ai

# Or from internal registry
npm install -g opencode-ai --registry http://npm.internal:4873
```

### 6.2 Full Configuration File

Project root or `~/.config/opencode/opencode.json`:

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
      "name": "Internal LLM Server",
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
          "name": "GPT-OSS-120B (Internal)",
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

### 6.3 Environment Variable Configuration

```bash
# Add to ~/.bashrc or ~/.zshrc
export GITLAB_TOKEN="glpat-xxxxx"
export GITLAB_API_URL="https://gitlab.internal.company.com/api/v4"

# NPM Registry
export NPM_CONFIG_REGISTRY="http://npm.internal:4873"

# Apply
source ~/.bashrc
```

### 6.4 Connection Test

```bash
# Start OpenCode
opencode

# Test internally
> Hello. What model are you currently using?

# Test GitLab MCP
> Show me my project list from GitLab.
```

---

## 7. Security Configuration

### 7.1 Network Security

```bash
# Firewall configuration (firewalld)
# LLM server
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port port="30000" protocol="tcp" accept'

# GitLab
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port port="443" protocol="tcp" accept'

# Apply
sudo firewall-cmd --reload
```

### 7.2 TLS Configuration

```bash
# Issue certificates from internal CA
# For LLM server
openssl req -new -key llm.key -out llm.csr \
  -subj "/CN=llm.internal.company.com"

# For GitLab
openssl req -new -key gitlab.key -out gitlab.csr \
  -subj "/CN=gitlab.internal.company.com"

# Sign with internal CA
# ...
```

### 7.3 LLM Server HTTPS Configuration (Nginx Reverse Proxy)

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

### 7.4 API Authentication Configuration

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

### 7.5 Audit Logging

```bash
# LLM server request logging
# Enable logging when starting sglang
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --log-level info \
  --log-requests \
  --log-dir /var/log/sglang

# Log rotation
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

## 8. Operations Guide

### 8.1 Monitoring

#### Prometheus Metrics

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

#### Grafana Dashboard

```
Key metrics:
- GPU utilization (nvidia_gpu_utilization)
- Inference latency (sglang_request_latency)
- Token throughput (sglang_tokens_per_second)
- Request queue length (sglang_queue_length)
- GitLab API response time
```

### 8.2 Backup

```bash
# LLM model backup (one-time, as model files don't change)
tar -czvf /backup/models/gpt-oss-120b.tar.gz /models/gpt-oss-120b

# GitLab backup
sudo gitlab-backup create

# Schedule backups
crontab -e
# 0 2 * * * /opt/gitlab/bin/gitlab-backup create CRON=1
```

### 8.3 Update Procedure

```bash
# 1. Model update (if needed)
# Download from internet-connected environment → Transfer internally → Replace

# 2. sglang update
pip install --upgrade sglang[all]
sudo systemctl restart sglang

# 3. GitLab update
sudo apt-get update
sudo apt-get install gitlab-ce

# 4. MCP package update
npm update @modelcontextprotocol/server-gitlab

# 5. OpenCode update
npm update -g opencode-ai
```

### 8.4 Incident Response

```bash
# Check LLM server status
curl http://llm.internal:30000/health
sudo systemctl status sglang
journalctl -u sglang -f

# Check GitLab status
sudo gitlab-ctl status
sudo gitlab-rake gitlab:check

# Check MCP connection
opencode mcp status
```

---

## 9. Troubleshooting

### 9.1 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| LLM connection failure | Network/firewall | Check port 30000 |
| GPU OOM | Insufficient VRAM | Apply quantization or increase tp |
| GitLab authentication failure | Token expired | Issue new token |
| MCP timeout | Slow network | Increase timeout |
| NPM package not found | Mirror not configured | Publish package |

### 9.2 Debugging

```bash
# OpenCode debug mode
OPENCODE_LOG_LEVEL=debug opencode

# LLM server logs
journalctl -u sglang -f

# GitLab logs
sudo gitlab-ctl tail

# Network test
curl -v http://llm.internal:30000/health
curl -v https://gitlab.internal/api/v4/projects \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN"
```

### 9.3 Performance Tuning

```bash
# GPU optimization
export CUDA_VISIBLE_DEVICES=0,1,2,3
export NCCL_P2P_DISABLE=0
export NCCL_IB_DISABLE=0

# sglang memory optimization
python -m sglang.launch_server \
  --model /models/gpt-oss-120b \
  --mem-fraction-static 0.9 \
  --max-running-requests 8 \
  --max-num-reqs 32
```

---

## 10. Checklists

### 10.1 Pre-Setup Checklist

- [ ] GPU server hardware prepared
- [ ] Network configuration verified (firewall, DNS)
- [ ] Model files downloaded and transferred internally
- [ ] Certificates prepared (internal CA)
- [ ] GitLab CE server prepared
- [ ] Internal NPM Registry prepared

### 10.2 Setup Checklist

- [ ] CUDA/cuDNN installed
- [ ] sglang installed and service registered
- [ ] LLM server connection tested
- [ ] GitLab CE installed and configured
- [ ] GitLab PAT generated
- [ ] GitLab API tested
- [ ] NPM Registry configured
- [ ] MCP packages mirrored
- [ ] OpenCode installed
- [ ] OpenCode configuration file created
- [ ] End-to-end connection tested

### 10.3 Security Checklist

- [ ] Firewall rules applied
- [ ] TLS certificates installed
- [ ] API authentication configured
- [ ] Audit logging enabled
- [ ] Least privilege principle applied
- [ ] Sensitive file access blocked

### 10.4 Operations Checklist

- [ ] Monitoring configured
- [ ] Alerts configured
- [ ] Backup schedule configured
- [ ] Update procedures documented
- [ ] Incident response procedures documented
- [ ] User training completed

---

## Appendix: Quick Start Scripts

### setup-env.sh

```bash
#!/bin/bash
# Environment variable setup script

# GitLab configuration
export GITLAB_TOKEN="glpat-your-token-here"
export GITLAB_API_URL="https://gitlab.internal.company.com/api/v4"

# NPM Registry
export NPM_CONFIG_REGISTRY="http://npm.internal:4873"

# LLM server (optional)
export INTERNAL_LLM_URL="http://llm.internal.company.com:30000/v1"

echo "Environment variables configured"
echo "GITLAB_API_URL: $GITLAB_API_URL"
echo "NPM_CONFIG_REGISTRY: $NPM_CONFIG_REGISTRY"
```

### verify-setup.sh

```bash
#!/bin/bash
# Setup verification script

echo "=== Starting setup verification ==="

# 1. LLM server
echo -n "LLM server connection: "
if curl -s http://llm.internal:30000/health > /dev/null; then
  echo "✅ Success"
else
  echo "❌ Failed"
fi

# 2. GitLab API
echo -n "GitLab API connection: "
if curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_API_URL/user" | grep -q "username"; then
  echo "✅ Success"
else
  echo "❌ Failed"
fi

# 3. NPM Registry
echo -n "NPM Registry connection: "
if curl -s http://npm.internal:4873/-/ping | grep -q "ok"; then
  echo "✅ Success"
else
  echo "❌ Failed"
fi

# 4. OpenCode
echo -n "OpenCode installation: "
if command -v opencode &> /dev/null; then
  echo "✅ Installed ($(opencode --version))"
else
  echo "❌ Not installed"
fi

echo "=== Verification complete ==="
```

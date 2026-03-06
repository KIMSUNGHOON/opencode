# MCP (Model Context Protocol) Connection Guide

## Overview

MCP (Model Context Protocol) is a protocol that enables AI models to interact with external tools, data sources, and services. OpenCode can access various external resources such as file systems, GitHub, and databases through MCP.

---

## Table of Contents

1. [MCP Basic Concepts](#1-mcp-basic-concepts)
2. [Connection Types](#2-connection-types)
3. [Configuration Methods](#3-configuration-methods)
4. [Available MCP Servers](#4-available-mcp-servers)
5. [Authentication Setup](#5-authentication-setup)
6. [Troubleshooting](#6-troubleshooting)

---

## 1. MCP Basic Concepts

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    OpenCode     │────▶│   MCP Client    │────▶│   MCP Server    │
│   (AI Agent)    │◀────│   (Built-in)    │◀────│ (External Tool) │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │  External API   │
                                                │  File System    │
                                                │  Database       │
                                                └─────────────────┘
```

### Core Components

| Component | Description |
|-----------|-------------|
| **Client** | MCP client built into OpenCode |
| **Server** | MCP server providing external tools |
| **Transport** | Communication method (stdio, HTTP, SSE) |
| **Tools** | Features provided by MCP servers |

---

## 2. Connection Types

### 2.1 Local (Local Process)

Communicates with locally running MCP servers via stdio.

**Features:**
- Fast response time
- Easy access to local resources
- No separate authentication required

**Configuration Schema:**
```json
{
  "type": "local",
  "command": ["string", "array"],
  "environment": { "KEY": "VALUE" },
  "enabled": true,
  "timeout": 30000
}
```

**Parameter Description:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | Fixed as `"local"` |
| `command` | string[] | Yes | Command and argument array to execute |
| `environment` | object | No | Environment variable settings |
| `enabled` | boolean | No | Enable/disable (default: true) |
| `timeout` | number | No | Timeout (ms, default: 30000) |

### 2.2 Remote (Remote Server)

Communicates with remote MCP servers via HTTP/SSE.

**Features:**
- Cloud service integration possible
- OAuth authentication support
- Network dependent

**Configuration Schema:**
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

**Parameter Description:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | Fixed as `"remote"` |
| `url` | string | Yes | MCP server URL |
| `enabled` | boolean | No | Enable/disable |
| `headers` | object | No | HTTP headers |
| `oauth` | object/false | No | OAuth settings or disable |
| `timeout` | number | No | Timeout (ms) |

---

## 3. Configuration Methods

### 3.1 Configuration File Locations

Priority (highest first):
1. Project root: `./opencode.json` or `./opencode.jsonc`
2. Project .opencode: `./.opencode/opencode.json`
3. Global: `~/.config/opencode/opencode.json`

### 3.2 Basic Configuration Example

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

### 3.3 Using Environment Variables

You can reference environment variables in the configuration file using the `{env:VARIABLE_NAME}` syntax.

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

### 3.4 File Content Reference

You can reference file contents using the `{file:path}` syntax.

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

## 4. Available MCP Servers

### 4.1 Official MCP Servers

| Server | Package | Purpose |
|--------|---------|---------|
| Filesystem | `@modelcontextprotocol/server-filesystem` | File system access |
| GitHub | `@modelcontextprotocol/server-github` | GitHub API integration |
| Git | `@modelcontextprotocol/server-git` | Git operations |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | PostgreSQL DB |
| SQLite | `@modelcontextprotocol/server-sqlite` | SQLite DB |
| Slack | `@modelcontextprotocol/server-slack` | Slack integration |
| Memory | `@modelcontextprotocol/server-memory` | Memory storage |

### 4.2 Configuration Examples

#### Filesystem Server
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

#### GitHub Server
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

#### Git Server
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

#### PostgreSQL Server
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

## 5. Authentication Setup

### 5.1 API Token Authentication

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

### 5.2 OAuth Authentication

OpenCode supports OAuth authentication for remote MCP servers.

**Automatic OAuth (Dynamic Client Registration):**
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

**Pre-registered Client:**
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

**Disable OAuth:**
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

### 5.3 OAuth Authentication Commands

```bash
# Start MCP server authentication
opencode mcp auth <mcp-name>

# Remove authentication
opencode mcp remove-auth <mcp-name>

# Check MCP status
opencode mcp status
```

---

## 6. Troubleshooting

### 6.1 Common Errors

#### Connection Failure
```
Error: Failed to connect to MCP server
```

**Solution:**
1. Verify the MCP server command is correct
2. Ensure required packages are installed
3. Verify environment variables are properly configured

#### Timeout
```
Error: MCP request timed out
```

**Solution:**
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

#### Authentication Required
```
Status: needs_auth
```

**Solution:**
```bash
opencode mcp auth <mcp-name>
```

### 6.2 Debugging

Enable detailed logging by setting the log level:
```json
{
  "logLevel": "debug"
}
```

Or via environment variable:
```bash
OPENCODE_LOG_LEVEL=debug opencode
```

### 6.3 MCP Status Check API

```bash
# Check status via CLI
opencode mcp status

# Programmatic approach
GET /mcp/status
```

**Status Values:**
| Status | Description |
|--------|-------------|
| `connected` | Successfully connected |
| `disabled` | Disabled |
| `failed` | Connection failed |
| `needs_auth` | Authentication required |
| `needs_client_registration` | OAuth client registration required |

---

## Appendix: Complete Configuration Example

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
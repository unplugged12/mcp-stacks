# MCP Stacks - GitOps Deployment for Portainer

[![CI Pipeline](https://github.com/unplugged12/mcp-stacks/actions/workflows/ci.yml/badge.svg)](https://github.com/unplugged12/mcp-stacks/actions/workflows/ci.yml)
[![Deploy](https://github.com/unplugged12/mcp-stacks/actions/workflows/deploy.yml/badge.svg)](https://github.com/unplugged12/mcp-stacks/actions/workflows/deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Production-grade GitOps infrastructure for deploying and managing Model Context Protocol (MCP) servers across distributed Docker environments.**

## Why This Matters

Modern IT infrastructure demands:
- **Automated, repeatable deployments** that eliminate configuration drift
- **Zero-trust secret management** that never commits credentials to source control
- **Multi-environment orchestration** supporting both persistent and ephemeral workloads
- **Infrastructure as Code** principles for auditability and version control

This repository demonstrates **enterprise-grade DevOps practices** applied to container orchestration, showcasing:
- ✅ **GitOps methodology** - Single source of truth with automated sync
- ✅ **Security-first architecture** - Secrets delivered via encrypted channels, never stored in Git
- ✅ **Production resilience** - Health checks, resource limits, logging, and rollback capabilities
- ✅ **Multi-platform support** - Agent-based (always-on hosts) and Edge-based (roaming devices) deployment models
- ✅ **CI/CD automation** - Automated testing, security scanning, and deployment workflows

## Overview

This platform manages MCP server deployments using GitOps principles with Portainer CE across heterogeneous infrastructure

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [MCP Servers](#mcp-servers)
- [Secrets Management](#secrets-management)
- [Deployment Workflows](#deployment-workflows)
- [CI/CD Pipeline](#cicd-pipeline)
- [Adding New MCP Servers](#adding-new-mcp-servers)
- [Production Features](#production-features)
- [Triggering Redeployments](#triggering-redeployments)
- [Off-LAN Access](#off-lan-access)
- [Troubleshooting](#troubleshooting)
- [Scripts Reference](#scripts-reference)

---

## Overview

This repository manages MCP server deployments using:

- **GitOps**: Compose files stored in Git, auto-deployed via Portainer
- **Multi-environment**: Separate configs for desktops (Agent) and laptops (Edge)
- **Zero secrets in Git**: Edge Configs and agent env files for secrets
- **Automated workflows**: Scripts for install, validation, and rollback

**Key Principle:** **Never commit secrets to Git**

> **📝 Note:** Throughout this documentation, `jabba.lan:9444` is used as an example Portainer server hostname. Replace this with your own Portainer server address (e.g., `portainer.example.com:9443` or your server's IP/hostname).

---

## Architecture

### Deployment Types

| Type | Endpoints | Connection | GitOps | Secrets Delivery |
|------|-----------|------------|--------|------------------|
| **Agent** | Desktops, always-on hosts | Direct (port 9001) | Auto-sync on Git commit | Host env file (`/run/mcp/mcp.env`) |
| **Edge** | Laptops, roaming hosts | Tunnel (port 8000) | Manual redeploy (CE limitation) | Edge Config (.env file) |

### Repository Structure

```
mcp-stacks/
├── stacks/
│   ├── common/docker-compose.yml      # Shared MCP services
│   ├── desktop/docker-compose.yml     # Agent endpoints (includes common)
│   └── laptop/docker-compose.yml      # Edge endpoints (explicit services)
├── edge-configs/
│   ├── README.md                      # Edge Config documentation
│   └── laptops.zip                    # Generated (gitignored)
├── scripts/
│   ├── build-edge-config.{ps1,sh}    # Create Edge Config bundle
│   ├── install/
│   │   ├── configure-agent-env.{ps1,sh} # Create /run/mcp/mcp.env on agents
│   │   ├── install-agent.{ps1,sh}    # Install Portainer Agent (desktops)
│   │   ├── uninstall-agent.{ps1,sh}
│   │   ├── install-edge-agent.{ps1,sh}  # Install Edge Agent (laptops)
│   │   └── uninstall-edge-agent.{ps1,sh}
│   ├── api/
│   │   └── redeploy-stack.{ps1,sh}   # API-based redeploy helper
│   ├── validation/
│   │   ├── pre-deploy-check.ps1      # Pre-deployment validation
│   │   └── post-deploy-check.ps1     # Post-deployment validation
│   └── rollback-stack.ps1            # Rollback to previous commit
└── README.md                          # This file
```

---

## Hardware Requirements

### Minimum Requirements

The MCP stack has been tuned for resource-constrained environments, specifically the **UGREEN DXP 2800** NAS:

- **CPU:** Intel N100 (4 cores) or equivalent
- **RAM:** 8-16GB (shared with other workloads like 4K transcoding)
- **Storage:** 10GB free space for Docker images and logs

### Resource Allocation

Current resource limits are conservative to accommodate concurrent workloads (e.g., 4K video transcoding):

| Service | CPU Limit | Memory Limit | Notes |
|---------|-----------|--------------|-------|
| context7 | 0.5 core | 256MB | Reduced from 1.0/512MB |
| dockerhub | 0.25 core | 128MB | Reduced from 0.5/256MB |
| playwright | 1.0 core | 1GB | Reduced from 2.0/2GB (browser automation) |
| sequentialthinking | 0.5 core | 256MB | Reduced from 1.0/512MB |
| **Total** | **2.25 cores** | **1.64GB** | Leaves ~1.75 cores for transcoding/OS |

### Tuning for Different Hardware

If you have more powerful hardware or dedicated systems, you can increase limits:

**High-Performance Desktop (8+ cores, 32GB+ RAM):**
```yaml
# In stacks/common/docker-compose.yml or stacks/laptop/docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '2.0'  # Increase from 0.5
      memory: 1G   # Increase from 256M
```

**Dedicated NAS Without Transcoding:**
- Can restore original limits (double the current values)
- Playwright can go back to 2.0 CPUs / 2GB for better browser performance

**Lower-End Hardware (2-core systems):**
- Consider running only essential services (disable playwright if not needed)
- Reduce limits further or stagger service usage

---

## Quick Start

### Prerequisites

- Docker Desktop installed on all endpoints
- Portainer CE running at `https://jabba.lan:9444`
- Git and GitHub CLI (`gh`) configured
- Network access to Jabba (on-LAN or via VPN/Tailscale)

### 1. Clone Repository

```bash
git clone https://github.com/unplugged12/mcp-stacks.git
cd mcp-stacks
```

### 2. Install Agents/Edge Agents

**Desktops (Agent):**
```powershell
.\scripts\install\install-agent.ps1
```

**Laptops (Edge):**
```powershell
.\scripts\install\install-edge-agent.ps1
# Follow prompts to paste docker run command from Portainer UI
```

### 3. Register Environments in Portainer

#### Agent Endpoints (Desktops)

1. Go to https://jabba.lan:9444
2. **Environments** → **Add environment**
3. Select **Docker Standalone** → **Agent**
4. Enter:
   - **Name:** `desktop-<hostname>`
   - **Environment URL:** `<desktop-ip>:9001`
5. Click **Add environment**

#### Edge Endpoints (Laptops)

1. Go to https://jabba.lan:9444
2. **Environments** → **Add environment**
3. Select **Docker Standalone** → **Edge Agent** → **Standard**
4. Configure:
   - **Name:** `laptop-<name>`
   - **Portainer server URL:** `https://jabba.lan:9444`
   - **Edge Group:** `laptops` (create if doesn't exist)
5. Copy the generated `docker run` command
6. Run the install script and paste the command when prompted

### 4. Configure Secrets

**For Laptops (Edge Config):**
```powershell
.\scripts\build-edge-config.ps1
# Follow prompts to enter secrets interactively
# Upload generated edge-configs/laptops.zip via Portainer UI:
#   Edge Configurations → Create → Upload ZIP → Target: laptops group
```

**For Desktops (Agent env file):**
```bash
sudo ./scripts/install/configure-agent-env.sh
# or, with PowerShell 7+
sudo pwsh ./scripts/install/configure-agent-env.ps1
```
- Run on each agent host before the first deployment.
- Creates `/run/mcp/mcp.env` with the required secrets and locks down permissions.
- Redeploy the stack after updating credentials so containers reload the values.

### 5. Deploy Stacks from Git

#### Agent Stack (Desktops)

1. **Stacks** → **Add stack**
2. **Git Repository** (under "Build method")
3. Configure:
   - **Repository URL:** `https://github.com/unplugged12/mcp-stacks`
   - **Reference:** `refs/heads/main`
   - **Compose path:** `stacks/desktop/docker-compose.yml`
4. (Optional) Define `MCP_ENV_FILE` if you used a non-default path. Leave blank to use `/run/mcp/mcp.env` created by the setup script.
5. Enable **GitOps updates** (automatic polling)
6. Deploy

#### Edge Stack (Laptops)

1. **Edge Stacks** → **Add stack**
2. **Git Repository**
3. Configure:
   - **Repository URL:** `https://github.com/unplugged12/mcp-stacks`
   - **Reference:** `refs/heads/main`
   - **Compose path:** `stacks/laptop/docker-compose.yml`
   - **Target:** Edge Group `laptops`
4. Deploy

**Note:** GitOps auto-sync for Edge Stacks is a Business feature. In CE, use **Pull and redeploy** after commits.

---

## MCP Servers

| Server | Image | Description | Auth Required |
|--------|-------|-------------|---------------|
| **Context7** | `mcp/context7:latest` | Context management | ✅ CONTEXT7_TOKEN |
| **Docker Hub** | `mcp/dockerhub:latest` | Docker Hub integration | ✅ HUB_USERNAME, HUB_PAT_TOKEN |
| **Playwright** | `mcp/mcp-playwright:latest` | Browser automation | ❌ |
| **Sequential Thinking** | `mcp/sequentialthinking:latest` | Sequential reasoning | ❌ |

All images are available on Docker Hub under the `mcp/` organization.

---

## Secrets Management

### 🔐 Security Principles

1. **Never commit secrets to Git** (protected by `.gitignore`)
2. **Edge (laptops):** Secrets delivered via Edge Config `.env` file
3. **Agent (desktops):** Secrets stored in `/run/mcp/mcp.env` on each host
4. **Portainer DB:** Consider enabling encryption at rest (Portainer settings)

### Edge Config Delivery (Laptops)

**Path on endpoint:** `/var/edge/configs/mcp.env`

**Build and deploy:**
```powershell
# 1. Build config bundle
.\scripts\build-edge-config.ps1

# 2. Upload in Portainer UI
#    Edge Configurations → Create configuration
#    Name: mcp-env
#    Target: Edge Group "laptops"
#    Upload: edge-configs/laptops.zip
```

**The bundle contains:**
```env
HUB_USERNAME=<value>
HUB_PAT_TOKEN=<value>
CONTEXT7_TOKEN=<value>
```

### Stack Env Vars (Desktops)

**Set during stack creation:**
- Portainer UI → Stacks → Add stack → Environment variables section

**Update existing stack:**
- Portainer UI → Stacks → Select stack → Editor tab → Environment variables

Portainer stores these in its database (not in Git).

---

## Deployment Workflows

### Agent Endpoints (Desktops) - Fully Automated

1. **Make changes** to compose files
2. **Commit and push** to Git
   ```bash
   git add stacks/
   git commit -m "Add new MCP server"
   git push origin main
   ```
3. **Portainer auto-syncs** (GitOps polling enabled)
4. **Stack redeployed** automatically

**Manual trigger (optional):**
```powershell
.\scripts\api\redeploy-stack.ps1 -ApiKey "ptr_xxxx" -StackName "mcp-desktop"
```

### Edge Endpoints (Laptops) - Manual Redeploy

1. **Make changes** to compose files
2. **Commit and push** to Git
3. **Trigger redeploy** via Portainer UI:
   - Edge Stacks → Select stack → **Pull and redeploy**

**Or use helper script:**
```powershell
.\scripts\api\redeploy-stack.ps1 -ApiKey "ptr_xxxx" -StackName "mcp-laptop" -Type edge
# Note: Will display instructions for CE users
```

### Selecting Lightweight Profiles in Portainer

Portainer honors the Compose `profiles` declared in the stack files:

- **Core services** (`mcp-context7`, `mcp-dockerhub`, `mcp-sequentialthinking`) run under both the `default` and `lite` profiles.
- **Browser automation** (`mcp-playwright`) is only part of the `default` profile.

To deploy a lightweight stack on laptops, NAS devices, or other constrained hosts:

1. Portainer UI → **Stacks** → Select the stack → **Editor**.
2. In the **Environment variables** panel add `COMPOSE_PROFILES=lite` (or edit the existing variable).
3. Click **Update the stack** to redeploy.

With `COMPOSE_PROFILES=lite`, Portainer omits the Playwright container entirely and applies the reduced resource requests (1 vCPU / 1 GB RAM / 1 GB `shm_size`). If you later need browser automation, clear the variable or set `COMPOSE_PROFILES=default` to restore the full profile.

> **Tip for NAS owners:** Skip Playwright unless the NAS has spare CPU and RAM headroom; the lite profile keeps the core MCP services responsive without launching a Chromium worker.

---

## CI/CD Pipeline

This repository uses GitHub Actions for automated testing, security scanning, and deployment orchestration.

### Pipeline Overview

The CI/CD pipeline provides:
- **Automated Linting**: PSScriptAnalyzer for PowerShell, shellcheck for Bash
- **Security Scanning**: SAST analysis with Trivy and Semgrep
- **Validation**: Docker Compose syntax checking and script testing
- **SBOM Generation**: Software Bill of Materials for dependency tracking
- **Deployment Automation**: Manual deployment workflows with validation

### CI Pipeline

Runs automatically on every push and pull request:

```bash
# View CI status
gh workflow view ci.yml

# Manually trigger CI
gh workflow run ci.yml
```

**Pipeline Stages:**
1. Lint PowerShell and Bash scripts
2. Security SAST scanning (Trivy + Semgrep)
3. Validate Docker Compose files
4. Generate SBOM and scan for vulnerabilities
5. Test scripts on Windows and Linux runners

### Deployment Workflow

Manual deployment with validation:

```bash
# Deploy to desktop environments
gh workflow run deploy.yml -f environment=desktop

# Deploy to laptop environments
gh workflow run deploy.yml -f environment=laptop

# Deploy to all environments
gh workflow run deploy.yml -f environment=all
```

**Note:** For Portainer CE, the deployment workflow provides detailed manual deployment instructions. Automatic API deployment requires the `PORTAINER_API_KEY` secret and is primarily informational for CE users.

### Required GitHub Secrets

Configure these secrets in repository settings for CI/CD:

| Secret | Purpose | Required |
|--------|---------|----------|
| `HUB_USERNAME` | Docker Hub authentication | Yes |
| `HUB_PAT_TOKEN` | Docker Hub PAT | Yes |
| `CONTEXT7_TOKEN` | Context7 service auth | Yes |
| `PORTAINER_API_KEY` | Portainer API access (optional) | No |

See [docs/SECRETS.md](docs/SECRETS.md) for detailed secrets configuration.

### Documentation

For comprehensive pipeline documentation, see:
- [docs/PIPELINE.md](docs/PIPELINE.md) - Complete pipeline architecture and usage
- [docs/SECRETS.md](docs/SECRETS.md) - Secrets management and rotation

---

## Adding New MCP Servers

### Step 1: Update Compose Files

**Edit `stacks/common/docker-compose.yml`:**
```yaml
services:
  mcp-newserver:
    image: mcp/newserver:latest
    restart: unless-stopped
    env_file: ${MCP_ENV_FILE:-/run/mcp/mcp.env}
```

**Edit `stacks/laptop/docker-compose.yml`:**
```yaml
services:
  mcp-newserver:
    image: mcp/newserver:latest
    restart: unless-stopped
    env_file: /var/edge/configs/mcp.env
```

### Step 2: Add Secrets (if needed)

**For Edge (laptops):**
- Update `scripts/build-edge-config.ps1` to prompt for new secrets
- Rebuild and redeploy Edge Config

**For Agent (desktops):**
- Update `scripts/install/configure-agent-env.{ps1,sh}` to prompt for the new secret
- Re-run the script on each agent host to refresh `/run/mcp/mcp.env`

### Step 3: Validate and Deploy

```powershell
# Validate before deploy
.\scripts\validation\pre-deploy-check.ps1

# Commit and push
git add stacks/
git commit -m "Add mcp-newserver"
git push origin main

# Agent: Auto-deploys
# Edge: Manual redeploy in UI

# Verify after deploy
.\scripts\validation\post-deploy-check.ps1 -StackPrefix "mcp"
```

---

## Production Features

### Health Checks

All MCP services include container-level health checks:

- **Health Check Type:** TCP connectivity test to port 3000
- **Interval:** Every 30 seconds
- **Retries:** 3 consecutive failures before marking unhealthy
- **Start Period:** 40-60 seconds (varies by service)

**View health status:**
```powershell
docker ps  # Shows "(healthy)" or "(unhealthy)" status
docker inspect <container-name> --format='{{.State.Health.Status}}'
```

**Health check details:**
```powershell
docker inspect <container-name> --format='{{json .State.Health}}' | ConvertFrom-Json
```

### Resource Limits

Resource limits prevent any single service from consuming excessive resources. Current limits are tuned for the UGREEN DXP 2800 NAS with concurrent 4K transcoding workload:

| Service | CPU Limit | Memory Limit | CPU Reservation | Memory Reservation |
|---------|-----------|--------------|-----------------|-------------------|
| context7 | 0.5 core | 256MB | 0.25 core | 128MB |
| dockerhub | 0.25 core | 128MB | 0.1 core | 64MB |
| playwright | 1.0 core | 1GB | 0.5 core | 256MB |
| sequentialthinking | 0.5 core | 256MB | 0.25 core | 128MB |
| **Total** | **2.25 cores** | **1.64GB** | **1.1 cores** | **576MB** |

See the [Hardware Requirements](#hardware-requirements) section for tuning guidance.

**Monitor resource usage:**
```powershell
docker stats
```

### Logging Configuration

All services use structured JSON logging with automatic rotation:

- **Max log size per file:** 10MB
- **Max files retained:** 3
- **Total max storage:** 30MB per container

**View logs:**
```powershell
docker logs <container-name> --tail 100 --follow
docker logs <container-name> --since 1h
docker logs <container-name> --timestamps
```

### Restart Policies

All services use `restart: unless-stopped` policy:
- Automatically restart on failure
- Restart after Docker daemon restarts
- Don't restart if manually stopped

### Service Labels

Labels enable filtering and observability:
- `com.mcp.service` - Service identifier
- `com.mcp.version` - Image version
- `com.mcp.environment` - Environment (production/staging/dev)
- `com.mcp.deployment` - Deployment type (agent/edge)

**Filter by label:**
```powershell
docker ps --filter "label=com.mcp.service=playwright"
docker ps --filter "label=com.mcp.deployment=edge"
```

### Smoke Testing

Run comprehensive health validation after deployment:

```powershell
.\scripts\smoke-test.ps1 -StackPrefix "mcp"
```

**Tests performed:**
- Docker daemon availability
- Container discovery
- Running status verification
- Health check status
- Resource limits enforcement
- Environment variable loading
- Logging configuration
- Recent log output analysis
- Port exposure validation
- Restart policy verification
- Container uptime tracking
- Resource usage snapshot

**Options:**
```powershell
# Verbose output
.\scripts\smoke-test.ps1 -StackPrefix "mcp" -Verbose

# Custom timeout
.\scripts\smoke-test.ps1 -StackPrefix "mcp" -Timeout 180

# Skip health checks
.\scripts\smoke-test.ps1 -StackPrefix "mcp" -SkipHealthCheck
```

### Observability & Monitoring

For comprehensive observability strategy including OpenTelemetry instrumentation, metrics collection, and distributed tracing, see:

**[observability/README.md](observability/README.md)**

Topics covered:
- OpenTelemetry SDK integration for Node.js MCP servers
- Metrics collection with Prometheus
- Log aggregation with Loki
- Distributed tracing with Jaeger
- Alerting with Alertmanager
- Grafana dashboards
- Container metrics with cAdvisor

#### Resource Planning for Monitoring Stacks

- The full Prometheus/Grafana/Loki bundle typically consumes **4+ vCPU**, **8+ GB
  RAM**, and fast SSD storage for metrics and logs. Avoid running it on the NAS
  when Plex, backups, or VMs already compete for those resources. Instead,
  deploy it on a dedicated observability node or cloud VM and point agents at
  that host.
- For NAS deployments, use the lightweight collectors defined in
  [`stacks/monitoring-lite`](stacks/monitoring-lite/README.md). They forward
  telemetry to a remote backend (Grafana Cloud, InfluxDB Cloud, VictoriaMetrics,
  etc.) while keeping local usage under ~200 MB RAM and <1 vCPU steady state.
- Always store remote API tokens in Portainer secrets or stack environment
  variables—**never commit credentials to Git**.

---

## Triggering Redeployments

### Via Git Commit (Agent - Automatic)

```bash
git commit -am "Update MCP configuration"
git push origin main
# Portainer auto-syncs within polling interval (default: 5 minutes)
```

### Via API (Agent)

```powershell
.\scripts\api\redeploy-stack.ps1 `
  -ApiKey "ptr_YOUR_API_KEY" `
  -StackName "mcp-desktop"
```

**Get API key:** Portainer UI → User settings → Access tokens → Add access token

### Via UI (Edge)

1. https://jabba.lan:9444/#!/edge/stacks
2. Select stack
3. Click **Pull and redeploy**

### Rollback to Previous Commit

```powershell
.\scripts\rollback-stack.ps1 `
  -ApiKey "ptr_YOUR_API_KEY" `
  -StackName "mcp-desktop"
# Follow prompts to select commit hash
```

---

## Off-LAN Access

### Option 1: WireGuard VPN (Existing)

- Configure WireGuard client on laptops
- DNS: Ensure `jabba.lan` resolves via WireGuard DNS

### Option 2: Tailscale (Recommended for Roaming)

#### Why Tailscale?

- **MagicDNS:** Auto-resolves friendly names across all nodes
- **Mesh networking:** Direct peer-to-peer when possible
- **Easy roaming:** Works seamlessly on/off-LAN
- **Zero-config:** No manual port forwarding

#### Install Tailscale

**On Jabba (NAS):**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --hostname jabba
```

**On Windows Laptops:**
```powershell
winget install -e --id Tailscale.Tailscale
tailscale up --hostname laptop1
```

**On macOS/Linux:**
```bash
# See https://tailscale.com/download
tailscale up --hostname <name>
```

#### Auth Keys (Optional - for Automation)

Generate pre-approved keys at: https://login.tailscale.com/admin/settings/keys

```bash
tailscale up --auth-key tskey-auth-XXXXX --ssh --hostname <name>
```

#### Access Portainer via Tailscale

Once connected, access via Tailscale hostname:
```
https://jabba.tail<YOUR_TAILNET>.ts.net:9444
```

Or update your hosts to use Tailscale IP.

---

## Troubleshooting

### Edge Agent Not Connecting

**Symptoms:** Edge environment shows "offline" in Portainer

**Solutions:**
1. Check Edge tunnel reachability:
   ```powershell
   Test-NetConnection jabba.lan -Port 8000
   ```
2. Verify agent container is running:
   ```bash
   docker ps --filter "name=portainer_edge_agent"
   ```
3. Check agent logs:
   ```bash
   docker logs portainer_edge_agent
   ```
4. Ensure Portainer server URL is `https://jabba.lan:9444` (not 9443!)

### Stack Deployment Fails

**Check compose syntax:**
```powershell
.\scripts\validation\pre-deploy-check.ps1
```

**View Portainer logs:**
- Portainer UI → Stacks → Select stack → Logs tab

**Inspect container logs:**
```bash
docker logs <container-name>
```

### Images Won't Pull

**Verify Docker Hub credentials (if private images):**
```bash
docker login
docker pull mcp/context7:latest
```

**For stack deployments:** Ensure credentials are in secrets (Edge Config or agent env file)

### GitOps Not Auto-Syncing (Agent)

**Verify GitOps is enabled:**
- Portainer UI → Stacks → Select stack → ensure "Auto update" is ON

**Check polling interval:**
- Default is 5 minutes; manually trigger if needed via API script

**Verify webhook (if configured):**
- Portainer UI → Stacks → Select stack → Webhook tab

### Secrets Not Loading

**Edge (laptops):**
1. Verify Edge Config deployed to correct group:
   - Portainer UI → Edge Configurations → Check target
2. Check config file path in compose: `/var/edge/configs/mcp.env`
3. Inspect container:
   ```bash
   docker exec <container> cat /var/edge/configs/mcp.env
   ```

**Agent (desktops):**
1. Verify the env file on the host:
   ```bash
   sudo cat /run/mcp/mcp.env
   ```
2. If you used a custom path, confirm the stack's `MCP_ENV_FILE` variable matches the location.
3. Inspect container environment:
   ```bash
   docker inspect <container> --format='{{.Config.Env}}'
   ```

---

## Scripts Reference

### Installation

| Script | Purpose | Platform |
|--------|---------|----------|
| `scripts/install/install-agent.ps1` | Install Portainer Agent on desktops | PowerShell |
| `scripts/install/install-agent.sh` | Install Portainer Agent on desktops | Bash |
| `scripts/install/install-edge-agent.ps1` | Install Edge Agent on laptops | PowerShell |
| `scripts/install/install-edge-agent.sh` | Install Edge Agent on laptops | Bash |
| `scripts/install/uninstall-agent.ps1` | Remove Agent | PowerShell |
| `scripts/install/uninstall-edge-agent.ps1` | Remove Edge Agent | PowerShell |

### Configuration

| Script | Purpose | Platform |
|--------|---------|----------|
| `scripts/build-edge-config.ps1` | Build Edge Config bundle with secrets | PowerShell |
| `scripts/build-edge-config.sh` | Build Edge Config bundle with secrets | Bash |
| `scripts/install/configure-agent-env.ps1` | Create `/run/mcp/mcp.env` on agent hosts | PowerShell |
| `scripts/install/configure-agent-env.sh` | Create `/run/mcp/mcp.env` on agent hosts | Bash |

### Deployment & Management

| Script | Purpose | Platform |
|--------|---------|----------|
| `scripts/api/redeploy-stack.ps1` | Trigger stack redeploy via API | PowerShell |
| `scripts/api/redeploy-stack.sh` | Trigger stack redeploy via API | Bash |
| `scripts/rollback-stack.ps1` | Rollback to previous Git commit | PowerShell |

### Validation

| Script | Purpose | Platform |
|--------|---------|----------|
| `scripts/validation/pre-deploy-check.ps1` | Pre-deployment validation | PowerShell |
| `scripts/validation/post-deploy-check.ps1` | Post-deployment verification | PowerShell |
| `scripts/smoke-test.ps1` | Comprehensive health validation suite | PowerShell |

---

## Contributing

When adding new MCP servers or making infrastructure changes:

1. **Never commit secrets** - Use Edge Configs or agent env files
2. **Validate before commit:**
   ```powershell
   .\scripts\validation\pre-deploy-check.ps1
   ```
3. **Test locally:**
   ```bash
   docker compose -f stacks/desktop/docker-compose.yml up -d
   ```
4. **Document changes** in this README
5. **Create meaningful commits** - helpful for rollbacks

---

## Future Enhancements

The mcp-stacks platform is evolving toward production-grade maturity. Planned enhancements include:

### Next Phase Priorities

1. **Monitoring & Alerting** - Prometheus/Grafana stack with health metrics, log aggregation via Loki, and PagerDuty/Opsgenie integration for on-call alerting
2. **Multi-Environment Support** - Isolated dev/staging/prod environments with automated promotion workflows and environment-specific configurations
3. **CI/CD Integration** - GitHub Actions or Azure Pipelines for automated testing, secrets scanning, and deployment orchestration

### Additional Roadmap Items

- **Disaster Recovery** - Automated backup/restore procedures for Portainer configs and Edge settings
- **Performance Optimization** - Container profiling, image layer optimization, and network tuning
- **Tailscale Integration** - Mesh networking with MagicDNS for seamless off-LAN connectivity
- **Expanded MCP Catalog** - Evaluation and deployment of additional MCP servers (filesystem, database, git, etc.)
- **Enhanced Documentation** - Architecture diagrams, operational runbooks, troubleshooting decision trees

For detailed roadmap, risks, and work breakdown, see [docs/ROADMAP.md](docs/ROADMAP.md).

For the complete backlog ready for Azure DevOps/Jira import, see [docs/backlog.csv](docs/backlog.csv).

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

You are free to use, modify, and distribute this code in accordance with the MIT License terms.

---

## Support

**Portainer Documentation:** https://docs.portainer.io
**MCP Protocol:** https://modelcontextprotocol.io

For issues with this setup, check:
1. Portainer logs
2. Container logs (`docker logs <name>`)
3. This repository's documentation

# MCP Stacks - GitOps Deployment for Portainer

GitOps-style deployment of MCP (Model Context Protocol) servers across multiple Docker hosts managed by Portainer CE.

**Portainer Server:** `https://jabba.lan:9444` (Edge tunnel on port 8000)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [MCP Servers](#mcp-servers)
- [Secrets Management](#secrets-management)
- [Deployment Workflows](#deployment-workflows)
- [Adding New MCP Servers](#adding-new-mcp-servers)
- [Triggering Redeployments](#triggering-redeployments)
- [Off-LAN Access](#off-lan-access)
- [Troubleshooting](#troubleshooting)
- [Scripts Reference](#scripts-reference)

---

## Overview

This repository manages MCP server deployments using:

- **GitOps**: Compose files stored in Git, auto-deployed via Portainer
- **Multi-environment**: Separate configs for desktops (Agent) and laptops (Edge)
- **Zero secrets in Git**: Edge Configs and Stack env vars for secrets
- **Automated workflows**: Scripts for install, validation, and rollback

**Key Principle:** **Never commit secrets to Git**

---

## Architecture

### Deployment Types

| Type | Endpoints | Connection | GitOps | Secrets Delivery |
|------|-----------|------------|--------|------------------|
| **Agent** | Desktops, always-on hosts | Direct (port 9001) | Auto-sync on Git commit | Stack env vars in Portainer |
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

**For Desktops (Stack Env Vars):**
- Add via Portainer UI when deploying the stack (step 5)
- Or update existing stack: **Stacks** → **mcp-desktop** → **Editor** → **Environment variables**

### 5. Deploy Stacks from Git

#### Agent Stack (Desktops)

1. **Stacks** → **Add stack**
2. **Git Repository** (under "Build method")
3. Configure:
   - **Repository URL:** `https://github.com/unplugged12/mcp-stacks`
   - **Reference:** `refs/heads/main`
   - **Compose path:** `stacks/desktop/docker-compose.yml`
4. **Environment variables** (add secrets):
   ```
   HUB_USERNAME=<your-dockerhub-username>
   HUB_PAT_TOKEN=<your-dockerhub-pat>
   CONTEXT7_TOKEN=<your-context7-token>
   ```
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
3. **Agent (desktops):** Secrets stored as Stack env vars in Portainer DB
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
- Add env vars in Portainer UI (Stacks → Edit → Environment variables)

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

**For stack deployments:** Ensure credentials are in secrets (Edge Config or Stack env vars)

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
1. Check Stack env vars:
   - Portainer UI → Stacks → Select stack → Editor → Environment variables
2. Inspect container environment:
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

1. **Never commit secrets** - Use Edge Configs or Stack env vars
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

Private repository - all rights reserved.

---

## Support

**Portainer Documentation:** https://docs.portainer.io
**MCP Protocol:** https://modelcontextprotocol.io

For issues with this setup, check:
1. Portainer logs
2. Container logs (`docker logs <name>`)
3. This repository's documentation

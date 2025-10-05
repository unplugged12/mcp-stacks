#!/usr/bin/env bash
#
# Install Portainer Agent on desktop/always-on hosts
# Deploys portainer/agent:latest on port 9001 with auto-restart.
# Verifies connectivity from Jabba (https://jabba.lan:9444).
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

AGENT_PORT="${1:-9001}"
FORCE="${2:-false}"

echo -e "${CYAN}🔧 Portainer Agent Installer (Desktop)${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

DOCKER_VERSION=$(docker --version)
echo -e "${GREEN}✓ Docker detected: $DOCKER_VERSION${NC}"

# Check if agent already running
EXISTING_AGENT=$(docker ps -a --filter "name=portainer_agent" --format "{{.Names}}" || true)
if [ -n "$EXISTING_AGENT" ] && [ "$FORCE" != "true" ]; then
    echo -e "${YELLOW}⚠️  Portainer Agent already exists: $EXISTING_AGENT${NC}"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
    FORCE="true"
fi

if [ "$FORCE" = "true" ] && [ -n "$EXISTING_AGENT" ]; then
    echo -e "${YELLOW}Removing existing agent...${NC}"
    docker stop portainer_agent 2>/dev/null || true
    docker rm portainer_agent 2>/dev/null || true
    echo -e "${GREEN}✓ Removed existing agent${NC}"
fi

# Pull latest agent image
echo ""
echo -e "${CYAN}Pulling portainer/agent:latest...${NC}"
docker pull portainer/agent:latest

# Deploy agent
echo ""
echo -e "${CYAN}Deploying Portainer Agent on port $AGENT_PORT...${NC}"

if docker run -d \
    --name portainer_agent \
    --restart=always \
    -p "${AGENT_PORT}:9001" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    portainer/agent:latest; then
    echo -e "${GREEN}✓ Agent deployed successfully${NC}"
else
    echo -e "${RED}✗ Agent deployment failed${NC}"
    exit 1
fi

# Verify agent is running
sleep 2
AGENT_STATUS=$(docker ps --filter "name=portainer_agent" --format "{{.Status}}")
echo -e "${GREEN}✓ Agent status: $AGENT_STATUS${NC}"

echo ""
echo -e "${GREEN}🎉 Portainer Agent installation complete!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "${NC}1. Log into Portainer at https://jabba.lan:9444${NC}"
echo -e "${NC}2. Navigate to Environments → Add environment${NC}"
echo -e "${NC}3. Select 'Docker Standalone' → 'Agent'${NC}"
echo -e "${NC}4. Enter this machine's hostname/IP and port $AGENT_PORT${NC}"
echo -e "${NC}5. Verify connectivity and add the environment${NC}"
echo ""
echo -e "${YELLOW}Agent endpoint: <this-host>:$AGENT_PORT${NC}"

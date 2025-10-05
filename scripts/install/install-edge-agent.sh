#!/usr/bin/env bash
#
# Install Portainer Edge Agent on laptop/roaming hosts
# Executes the docker run command from Portainer's Edge Agent wizard.
# Paste the exact command when prompted.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DOCKER_COMMAND="${1:-}"
FORCE="${2:-false}"

echo -e "${CYAN}🔧 Portainer Edge Agent Installer (Laptop)${NC}"
echo -e "${CYAN}===========================================${NC}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

DOCKER_VERSION=$(docker --version)
echo -e "${GREEN}✓ Docker detected: $DOCKER_VERSION${NC}"

# Check if edge agent already running
EXISTING_AGENT=$(docker ps -a --filter "name=portainer_edge_agent" --format "{{.Names}}" || true)
if [ -n "$EXISTING_AGENT" ] && [ "$FORCE" != "true" ]; then
    echo -e "${YELLOW}⚠️  Portainer Edge Agent already exists: $EXISTING_AGENT${NC}"
    read -p "Remove and reinstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
    FORCE="true"
fi

if [ "$FORCE" = "true" ] && [ -n "$EXISTING_AGENT" ]; then
    echo -e "${YELLOW}Removing existing edge agent...${NC}"
    docker stop portainer_edge_agent 2>/dev/null || true
    docker rm portainer_edge_agent 2>/dev/null || true
    echo -e "${GREEN}✓ Removed existing edge agent${NC}"
fi

# Get docker command if not provided
if [ -z "$DOCKER_COMMAND" ]; then
    echo ""
    echo -e "${CYAN}Instructions:${NC}"
    echo -e "${NC}1. Log into Portainer at https://jabba.lan:9444${NC}"
    echo -e "${NC}2. Navigate to Environments → Add environment${NC}"
    echo -e "${NC}3. Select 'Docker Standalone' → 'Edge Agent' → 'Standard'${NC}"
    echo -e "${NC}4. Configure:${NC}"
    echo -e "${NC}   - Name: <laptop-name>${NC}"
    echo -e "${NC}   - Portainer server URL: https://jabba.lan:9444${NC}"
    echo -e "${NC}   - Edge Group: laptops${NC}"
    echo -e "${NC}5. Copy the generated 'docker run' command${NC}"
    echo ""
    echo -e "${YELLOW}Paste the complete docker run command below:${NC}"
    echo -e "${YELLOW}(It should start with 'docker run -d ...')${NC}"
    echo ""
    read -r DOCKER_COMMAND
fi

# Validate command
if [[ ! "$DOCKER_COMMAND" =~ ^docker\ run ]]; then
    echo -e "${RED}✗ Invalid command. Must start with 'docker run'${NC}"
    exit 1
fi

if [[ ! "$DOCKER_COMMAND" =~ portainer/agent.*--edge ]]; then
    echo -e "${YELLOW}⚠️  Warning: This doesn't look like an Edge Agent command${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
fi

# Execute command
echo ""
echo -e "${CYAN}Deploying Edge Agent...${NC}"
echo ""

if eval "$DOCKER_COMMAND"; then
    echo ""
    echo -e "${GREEN}✓ Edge Agent deployed successfully${NC}"
else
    echo ""
    echo -e "${RED}✗ Edge Agent deployment failed${NC}"
    exit 1
fi

# Verify agent is running
sleep 2
AGENT_STATUS=$(docker ps --filter "name=portainer_edge_agent" --format "{{.Status}}" || true)
if [ -n "$AGENT_STATUS" ]; then
    echo -e "${GREEN}✓ Edge Agent status: $AGENT_STATUS${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: Edge Agent container not found${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Portainer Edge Agent installation complete!${NC}"
echo ""
echo -e "${CYAN}The Edge Agent will:${NC}"
echo -e "${NC}• Connect to https://jabba.lan:9444 via tunnel port 8000${NC}"
echo -e "${NC}• Poll for commands every 5 seconds (default)${NC}"
echo -e "${NC}• Check in periodically even when off-LAN${NC}"
echo ""
echo -e "${CYAN}Verify in Portainer:${NC}"
echo -e "${NC}• Environments → Check for this laptop (green = online)${NC}"
echo -e "${NC}• Edge Configurations → Deploy mcp.env config to 'laptops' group${NC}"
echo -e "${NC}• Edge Stacks → Deploy MCP stack from Git${NC}"

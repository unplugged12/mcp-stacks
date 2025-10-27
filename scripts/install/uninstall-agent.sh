#!/usr/bin/env bash
#
# Uninstall Portainer Agent from desktop
# Stops and removes the Portainer Agent container.
# Requires confirmation before removal.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

FORCE="${1:-false}"

echo -e "${CYAN}🗑️  Portainer Agent Uninstaller${NC}"
echo -e "${CYAN}===============================${NC}"
echo ""

# Check if agent exists
EXISTING_AGENT=$(docker ps -a --filter "name=portainer_agent" --format "{{.Names}}" || true)
if [ -z "$EXISTING_AGENT" ]; then
    echo -e "${GREEN}✓ No Portainer Agent found. Nothing to uninstall.${NC}"
    exit 0
fi

AGENT_STATUS=$(docker ps -a --filter "name=portainer_agent" --format "{{.Status}}")
echo -e "${YELLOW}Found agent: $EXISTING_AGENT${NC}"
echo -e "${YELLOW}Status: $AGENT_STATUS${NC}"
echo ""

if [ "$FORCE" != "true" ]; then
    read -p "Remove Portainer Agent? This will disconnect from Portainer server. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        exit 0
    fi
fi

echo -e "${CYAN}Stopping agent...${NC}"
docker stop portainer_agent 2>/dev/null || true
echo -e "${GREEN}✓ Agent stopped${NC}"

echo -e "${CYAN}Removing agent...${NC}"
docker rm portainer_agent 2>/dev/null || true
echo -e "${GREEN}✓ Agent removed${NC}"

echo ""
echo -e "${GREEN}🎉 Portainer Agent uninstalled successfully!${NC}"
echo ""
echo -e "${YELLOW}Remember to remove this environment from Portainer UI:${NC}"
echo -e "${NC}https://portainer-server.local:9444 → Environments → Remove this host${NC}"

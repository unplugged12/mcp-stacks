#!/usr/bin/env bash
#
# Uninstall Portainer Edge Agent from laptop
# Stops and removes the Portainer Edge Agent container.
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

echo -e "${CYAN}🗑️  Portainer Edge Agent Uninstaller${NC}"
echo -e "${CYAN}=====================================${NC}"
echo ""

# Check if edge agent exists
EXISTING_AGENT=$(docker ps -a --filter "name=portainer_edge_agent" --format "{{.Names}}" || true)
if [ -z "$EXISTING_AGENT" ]; then
    echo -e "${GREEN}✓ No Portainer Edge Agent found. Nothing to uninstall.${NC}"
    exit 0
fi

AGENT_STATUS=$(docker ps -a --filter "name=portainer_edge_agent" --format "{{.Status}}")
echo -e "${YELLOW}Found edge agent: $EXISTING_AGENT${NC}"
echo -e "${YELLOW}Status: $AGENT_STATUS${NC}"
echo ""

if [ "$FORCE" != "true" ]; then
    read -p "Remove Portainer Edge Agent? This will disconnect from Portainer server. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        exit 0
    fi
fi

echo -e "${CYAN}Stopping edge agent...${NC}"
docker stop portainer_edge_agent 2>/dev/null || true
echo -e "${GREEN}✓ Edge agent stopped${NC}"

echo -e "${CYAN}Removing edge agent...${NC}"
docker rm portainer_edge_agent 2>/dev/null || true
echo -e "${GREEN}✓ Edge agent removed${NC}"

echo ""
echo -e "${GREEN}🎉 Portainer Edge Agent uninstalled successfully!${NC}"
echo ""
echo -e "${YELLOW}Remember to remove this environment from Portainer UI:${NC}"
echo -e "${NC}https://portainer-server.local:9444 → Environments → Remove this laptop${NC}"

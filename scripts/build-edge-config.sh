#!/usr/bin/env bash
#
# Build Edge Config bundle for Portainer laptop deployments
# Creates a ZIP bundle containing mcp.env with secrets for Edge Config delivery.
# Prompts interactively for values; NEVER commits secrets to Git.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
EDGE_CONFIG_DIR="$REPO_ROOT/edge-configs"
OUTPUT_ZIP="$EDGE_CONFIG_DIR/laptops.zip"
TEMP_DIR="$(mktemp -d)"

echo -e "${CYAN}🔧 MCP Edge Config Bundle Builder${NC}"
echo -e "${CYAN}=================================${NC}"
echo ""

# Check for zip command
if ! command -v zip &> /dev/null; then
    echo -e "${RED}✗ 'zip' command not found${NC}"
    echo -e "${YELLOW}Please install zip:${NC}"
    echo -e "${NC}  macOS:  brew install zip${NC}"
    echo -e "${NC}  Ubuntu: sudo apt-get install zip${NC}"
    echo -e "${NC}  RHEL:   sudo yum install zip${NC}"
    exit 1
fi

# Create edge-configs directory if it doesn't exist
mkdir -p "$EDGE_CONFIG_DIR"

# Cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

echo -e "${GREEN}✓ Created temp directory: $TEMP_DIR${NC}"

# Template env file
ENV_PATH="$TEMP_DIR/mcp.env"
cat > "$ENV_PATH" <<'EOF'
# MCP Server Environment Variables
# Delivered via Portainer Edge Config to /var/edge/configs/mcp.env

# Docker Hub MCP Server
HUB_USERNAME=
HUB_PAT_TOKEN=

# Context7 MCP Server
CONTEXT7_TOKEN=

# Playwright MCP Server (typically no auth required)
# Add any Playwright-specific vars here if needed

# Sequential Thinking MCP Server (typically no auth required)
# Add any vars here if needed

EOF

echo -e "${GREEN}✓ Created template mcp.env${NC}"
echo ""

# Interactive prompts
echo -e "${YELLOW}Enter values for secrets (leave blank to skip):${NC}"
echo ""

read -p "Docker Hub Username: " HUB_USERNAME
read -s -p "Docker Hub PAT Token: " HUB_PAT_TOKEN
echo ""
read -s -p "Context7 API Token: " CONTEXT7_TOKEN
echo ""

# Build final env file
cat > "$ENV_PATH" <<EOF
# MCP Server Environment Variables
# Delivered via Portainer Edge Config to /var/edge/configs/mcp.env

# Docker Hub MCP Server
HUB_USERNAME=$HUB_USERNAME
HUB_PAT_TOKEN=$HUB_PAT_TOKEN

# Context7 MCP Server
CONTEXT7_TOKEN=$CONTEXT7_TOKEN

# Playwright MCP Server (typically no auth required)
# Add any Playwright-specific vars here if needed

# Sequential Thinking MCP Server (typically no auth required)
# Add any vars here if needed

EOF

echo ""
echo -e "${GREEN}✓ Updated mcp.env with provided values${NC}"

# Create ZIP
rm -f "$OUTPUT_ZIP"
cd "$TEMP_DIR"
zip -q "$OUTPUT_ZIP" mcp.env

echo -e "${GREEN}✓ Created bundle: $OUTPUT_ZIP${NC}"
echo -e "${GREEN}✓ Cleaned up temp files${NC}"
echo ""

echo -e "${GREEN}🎉 Edge Config bundle ready!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "${NC}1. Log into Portainer at https://jabba.lan:9444${NC}"
echo -e "${NC}2. Navigate to Edge Configurations${NC}"
echo -e "${NC}3. Create new configuration targeting 'laptops' Edge Group${NC}"
echo -e "${NC}4. Upload: $OUTPUT_ZIP${NC}"
echo ""
echo -e "${YELLOW}⚠️  Remember: Never commit $OUTPUT_ZIP to Git!${NC}"

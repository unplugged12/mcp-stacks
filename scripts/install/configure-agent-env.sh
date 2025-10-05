#!/usr/bin/env bash
#
# Configure the MCP agent environment file on Linux hosts.
# Prompts for required secrets and writes them to /run/mcp/mcp.env.
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ENV_FILE="/run/mcp/mcp.env"
ENV_DIR="$(dirname "$ENV_FILE")"

if [[ $(id -u) -ne 0 ]]; then
    echo -e "${RED}✗ This script must be run as root (sudo).${NC}" >&2
    exit 1
fi

echo -e "${CYAN}🔐 MCP Agent Environment Configuration${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

overwrite="y"
if [[ -f "$ENV_FILE" ]]; then
    read -r -p "${YELLOW}An existing env file was found at $ENV_FILE. Overwrite? (y/N): ${NC}" overwrite
    overwrite=${overwrite:-n}
fi

if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Aborting without modifying $ENV_FILE.${NC}"
    exit 0
fi

read -r -p "Docker Hub username: " HUB_USERNAME
while [[ -z "$HUB_USERNAME" ]]; do
    echo -e "${YELLOW}Docker Hub username cannot be empty.${NC}"
    read -r -p "Docker Hub username: " HUB_USERNAME
done

read -r -s -p "Docker Hub PAT: " HUB_PAT_TOKEN
echo ""
while [[ -z "$HUB_PAT_TOKEN" ]]; do
    echo -e "${YELLOW}Docker Hub PAT cannot be empty.${NC}"
    read -r -s -p "Docker Hub PAT: " HUB_PAT_TOKEN
    echo ""
done

read -r -s -p "Context7 API token: " CONTEXT7_TOKEN
echo ""
while [[ -z "$CONTEXT7_TOKEN" ]]; do
    echo -e "${YELLOW}Context7 API token cannot be empty.${NC}"
    read -r -s -p "Context7 API token: " CONTEXT7_TOKEN
    echo ""
done

escape_value() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

mkdir -p "$ENV_DIR"
chmod 700 "$ENV_DIR"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

{
    printf 'HUB_USERNAME="%s"\n' "$(escape_value "$HUB_USERNAME")"
    printf 'HUB_PAT_TOKEN="%s"\n' "$(escape_value "$HUB_PAT_TOKEN")"
    printf 'CONTEXT7_TOKEN="%s"\n' "$(escape_value "$CONTEXT7_TOKEN")"
} > "$tmp_file"

install -m 600 "$tmp_file" "$ENV_FILE"
trap - EXIT
rm -f "$tmp_file"

echo -e "${GREEN}✓ MCP env file written to $ENV_FILE${NC}"
echo -e "${GREEN}✓ Permissions set to 600${NC}"

echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Ensure the Portainer agent is registered for this host."
echo "  2. Deploy or redeploy the desktop stack so containers read the new secrets."

#!/usr/bin/env bash
#
# Trigger Portainer stack redeploy via API
# Redeploys Agent or Edge stacks by pulling latest from Git.
# Supports both regular stacks (Agent) and Edge stacks.
#
# Usage:
#   ./redeploy-stack.sh <API_KEY> <STACK_NAME> [TYPE]
#   TYPE: 'agent' (default) or 'edge'
#
# Example:
#   ./redeploy-stack.sh ptr_xxxx mcp-desktop
#   ./redeploy-stack.sh ptr_xxxx mcp-laptop edge
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Args
API_KEY="${1:-}"
STACK_NAME="${2:-}"
TYPE="${3:-agent}"
PORTAINER_URL="${PORTAINER_URL:-https://jabba.lan:9444}"

if [ -z "$API_KEY" ] || [ -z "$STACK_NAME" ]; then
    echo -e "${RED}Usage: $0 <API_KEY> <STACK_NAME> [TYPE]${NC}"
    echo -e "${YELLOW}TYPE: 'agent' (default) or 'edge'${NC}"
    echo ""
    echo "Example:"
    echo "  $0 ptr_xxxx mcp-desktop"
    echo "  $0 ptr_xxxx mcp-laptop edge"
    exit 1
fi

echo -e "${CYAN}🔄 Portainer Stack Redeploy Helper${NC}"
echo -e "${CYAN}===================================${NC}"
echo ""
echo -e "${YELLOW}Target: $STACK_NAME ($TYPE)${NC}"
echo -e "${YELLOW}Server: $PORTAINER_URL${NC}"
echo ""

# Headers
CURL_OPTS=(-k -s -H "X-API-Key: $API_KEY" -H "Content-Type: application/json")

if [ "$TYPE" = "agent" ]; then
    # Regular stack (Agent endpoints)
    echo -e "${CYAN}Fetching stack list...${NC}"
    STACKS=$(curl "${CURL_OPTS[@]}" "$PORTAINER_URL/api/stacks")

    STACK_ID=$(echo "$STACKS" | jq -r ".[] | select(.Name == \"$STACK_NAME\") | .Id")
    if [ -z "$STACK_ID" ] || [ "$STACK_ID" = "null" ]; then
        echo -e "${RED}✗ Stack '$STACK_NAME' not found${NC}"
        echo ""
        echo -e "${YELLOW}Available stacks:${NC}"
        echo "$STACKS" | jq -r '.[] | "  - \(.Name) (ID: \(.Id))"'
        exit 1
    fi

    ENDPOINT_ID=$(echo "$STACKS" | jq -r ".[] | select(.Name == \"$STACK_NAME\") | .EndpointId")

    echo -e "${GREEN}✓ Found stack: $STACK_NAME (ID: $STACK_ID)${NC}"

    # Trigger Git pull and redeploy
    echo -e "${CYAN}Triggering Git pull and redeploy...${NC}"

    BODY=$(cat <<EOF
{
  "RepositoryAuthentication": false,
  "RepositoryReferenceName": "refs/heads/main",
  "Prune": false,
  "PullImage": true
}
EOF
)

    if curl "${CURL_OPTS[@]}" \
        -X PUT \
        -d "$BODY" \
        "$PORTAINER_URL/api/stacks/$STACK_ID/git/redeploy?endpointId=$ENDPOINT_ID"; then
        echo -e "${GREEN}✓ Redeploy triggered successfully${NC}"
        echo ""
        echo -e "${CYAN}Stack updated from Git. Check Portainer UI for status:${NC}"
        echo -e "${NC}$PORTAINER_URL/#!/stacks/$STACK_ID${NC}"
    else
        echo -e "${RED}✗ Redeploy failed${NC}"
        exit 1
    fi

elif [ "$TYPE" = "edge" ]; then
    # Edge stack
    echo -e "${CYAN}Fetching Edge stack list...${NC}"
    EDGE_STACKS=$(curl "${CURL_OPTS[@]}" "$PORTAINER_URL/api/edge_stacks")

    EDGE_STACK_ID=$(echo "$EDGE_STACKS" | jq -r ".[] | select(.Name == \"$STACK_NAME\") | .Id")
    if [ -z "$EDGE_STACK_ID" ] || [ "$EDGE_STACK_ID" = "null" ]; then
        echo -e "${RED}✗ Edge stack '$STACK_NAME' not found${NC}"
        echo ""
        echo -e "${YELLOW}Available Edge stacks:${NC}"
        echo "$EDGE_STACKS" | jq -r '.[] | "  - \(.Name) (ID: \(.Id))"'
        exit 1
    fi

    echo -e "${GREEN}✓ Found Edge stack: $STACK_NAME (ID: $EDGE_STACK_ID)${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Note: Edge stack Git sync is a Business feature in Portainer CE.${NC}"
    echo -e "${YELLOW}For CE, please use Portainer UI to manually Pull and redeploy:${NC}"
    echo -e "${NC}1. Go to $PORTAINER_URL/#!/edge/stacks${NC}"
    echo -e "${NC}2. Select '$STACK_NAME'${NC}"
    echo -e "${NC}3. Click 'Pull and redeploy'${NC}"
    echo ""
    echo -e "${CYAN}Alternatively, upgrade to Portainer Business for API-based Edge GitOps.${NC}"

else
    echo -e "${RED}✗ Invalid type: $TYPE (must be 'agent' or 'edge')${NC}"
    exit 1
fi

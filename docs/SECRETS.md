# GitHub Actions Secrets Configuration

This document describes the secrets required for the CI/CD pipeline in this repository.

## Overview

The CI/CD pipeline uses GitHub Actions secrets to securely store sensitive information needed for deployment and testing. Secrets are encrypted and only exposed to workflows during runtime.

## Required Secrets

### 1. Docker Hub Credentials

These credentials are used for testing image pulls and deployment validation.

| Secret Name | Description | Required For | How to Get |
|------------|-------------|--------------|------------|
| `HUB_USERNAME` | Docker Hub username | Testing, Deployment | Your Docker Hub account username |
| `HUB_PAT_TOKEN` | Docker Hub Personal Access Token | Testing, Deployment | Docker Hub → Account Settings → Security → New Access Token |

**To create a Docker Hub PAT:**
1. Go to https://hub.docker.com/settings/security
2. Click "New Access Token"
3. Description: `mcp-stacks-ci`
4. Access permissions: `Read-only` (sufficient for pulling images)
5. Generate and copy the token

### 2. MCP Service Credentials

Credentials for MCP services that require authentication.

| Secret Name | Description | Required For | How to Get |
|------------|-------------|--------------|------------|
| `CONTEXT7_TOKEN` | Context7 API token | Testing, Deployment | Context7 dashboard/settings |

### 3. Portainer API Credentials (Optional)

Required only for automated deployment via API. Manual deployment through Portainer UI does not require these.

| Secret Name | Description | Required For | How to Get |
|------------|-------------|--------------|------------|
| `PORTAINER_API_KEY` | Portainer API access token | Deployment workflow | Portainer UI → User → Access tokens |

**To create a Portainer API token:**
1. Go to https://portainer-server.local:9444
2. Click on your username (top-right)
3. Navigate to "Access tokens"
4. Click "Add access token"
5. Description: `github-actions-deploy`
6. Copy the generated token immediately (it won't be shown again)

**Note:** The Portainer API key is **optional**. The deployment workflow will provide manual deployment instructions if this secret is not configured.

## Setting Secrets in GitHub

### Via GitHub Web UI

1. Go to your repository: https://github.com/unplugged12/mcp-stacks
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter the secret name (e.g., `HUB_USERNAME`)
5. Enter the secret value
6. Click **Add secret**
7. Repeat for all required secrets

### Via GitHub CLI

```bash
# Set Docker Hub credentials
gh secret set HUB_USERNAME --body "your-dockerhub-username"
gh secret set HUB_PAT_TOKEN --body "your-dockerhub-pat-token"

# Set MCP service credentials
gh secret set CONTEXT7_TOKEN --body "your-context7-token"

# Optional: Set Portainer API key
gh secret set PORTAINER_API_KEY --body "your-portainer-api-key"
```

### Using .env file (Local Development)

For local testing, you can create a `.env` file (DO NOT commit to Git):

```bash
# .env (gitignored)
HUB_USERNAME=your-dockerhub-username
HUB_PAT_TOKEN=your-dockerhub-pat-token
CONTEXT7_TOKEN=your-context7-token
PORTAINER_API_KEY=your-portainer-api-key
```

Load secrets in your local environment:

```powershell
# PowerShell
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
```

```bash
# Bash
export $(cat .env | xargs)
```

## Secrets Rotation

### Recommended Rotation Schedule

| Secret Type | Rotation Frequency | Action |
|------------|-------------------|---------|
| Docker Hub PAT | Every 90 days | Regenerate token, update secret |
| Context7 Token | As needed | Update when expired/rotated |
| Portainer API Key | Every 180 days | Generate new token, update secret |

### How to Rotate Secrets

1. **Generate new credential** in the respective service
2. **Update GitHub secret**:
   - UI: Settings → Secrets → Click secret name → Update
   - CLI: `gh secret set SECRET_NAME --body "new-value"`
3. **Test the pipeline**: Trigger a workflow run to verify
4. **Revoke old credential** in the service

## Security Best Practices

### DO:
- ✅ Use least-privilege access (read-only when possible)
- ✅ Rotate secrets regularly
- ✅ Use descriptive names when creating tokens (e.g., `github-actions-ci`)
- ✅ Review secret access in repository settings
- ✅ Enable secret scanning in repository settings
- ✅ Use environment-specific secrets when needed

### DON'T:
- ❌ Commit secrets to Git (even in private repositories)
- ❌ Log secrets in workflow outputs
- ❌ Share secrets across multiple repositories unless necessary
- ❌ Use personal credentials for automation (use service accounts/tokens)
- ❌ Grant excessive permissions to tokens

## Troubleshooting

### Secret Not Found Error

```
Error: Secret HUB_USERNAME not found
```

**Solution:** Ensure the secret is created in GitHub repository settings with the exact name (case-sensitive).

### Invalid Credentials Error

```
Error: Authentication failed
```

**Solution:**
1. Verify the secret value is correct (regenerate if needed)
2. Check if the credential has expired
3. Ensure the credential has the required permissions

### Secret Not Updated

If you updated a secret but workflows still fail:

1. **Clear runner cache**: Re-run the workflow
2. **Check secret name**: Ensure it matches exactly (case-sensitive)
3. **Verify permissions**: Ensure the workflow has access to secrets

## Pipeline Workflow Secret Usage

### CI Pipeline (`ci.yml`)

Uses these secrets for validation:
- `HUB_USERNAME` - Image pull authentication
- `HUB_PAT_TOKEN` - Image pull authentication
- `CONTEXT7_TOKEN` - Compose file validation

### Deployment Pipeline (`deploy.yml`)

Uses these secrets for deployment:
- `HUB_USERNAME` - Stack deployment
- `HUB_PAT_TOKEN` - Stack deployment
- `CONTEXT7_TOKEN` - Stack deployment
- `PORTAINER_API_KEY` - Optional API deployment

## Environment Variables vs Secrets

| Use Case | GitHub Secrets | Agent Env File | Edge Config |
|----------|---------------|----------------|-------------|
| CI/CD Pipeline | ✅ | ❌ | ❌ |
| Desktop Stacks (Agent) | ❌ | ✅ | ❌ |
| Laptop Stacks (Edge) | ❌ | ❌ | ✅ |

**Key Principle:**
- **GitHub Secrets**: For CI/CD automation only
- **Agent Env File (`/run/mcp/mcp.env`)**: For Agent-based deployments (desktops)
- **Portainer Edge Config**: For Edge-based deployments (laptops)

## Support

For issues with secrets configuration:

1. **GitHub Secrets**: https://docs.github.com/en/actions/security-guides/encrypted-secrets
2. **Portainer API**: https://docs.portainer.io/api/access
3. **Docker Hub Tokens**: https://docs.docker.com/docker-hub/access-tokens/

## Audit Log

Keep track of secret changes:

| Date | Secret | Action | Changed By | Reason |
|------|--------|--------|------------|--------|
| YYYY-MM-DD | Example | Created | @username | Initial setup |

**Note:** Update this table when making secret changes for audit purposes.

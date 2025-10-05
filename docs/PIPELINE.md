# CI/CD Pipeline Documentation

[![CI Pipeline](https://github.com/unplugged12/mcp-stacks/actions/workflows/ci.yml/badge.svg)](https://github.com/unplugged12/mcp-stacks/actions/workflows/ci.yml)
[![Deploy](https://github.com/unplugged12/mcp-stacks/actions/workflows/deploy.yml/badge.svg)](https://github.com/unplugged12/mcp-stacks/actions/workflows/deploy.yml)

## Overview

This repository uses GitHub Actions to automate testing, security scanning, and deployment of MCP stacks to Portainer. The pipeline ensures code quality, security compliance, and safe deployments.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CI Pipeline (ci.yml)                     │
│                    Triggered on: push, PR                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Lint PS    │  │  Lint Bash   │  │   Validate   │       │
│  │   Scripts    │  │   Scripts    │  │   Scripts    │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                  │                  │               │
│         └──────────────────┴──────────────────┘               │
│                           │                                   │
│         ┌─────────────────┴─────────────────┐                │
│         │                                     │                │
│  ┌──────▼───────┐  ┌──────────────┐  ┌──────▼───────┐       │
│  │   Security   │  │   Validate   │  │    Docker    │       │
│  │     SAST     │  │   Compose    │  │    Image     │       │
│  │ (Trivy/Sem)  │  │    Files     │  │   Security   │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                  │                  │               │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐       │
│  │  Generate    │  │  Test Linux  │  │  Test Win    │       │
│  │     SBOM     │  │   Scripts    │  │   Scripts    │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                  │                  │               │
│         └──────────────────┴──────────────────┘               │
│                           │                                   │
│                    ┌──────▼───────┐                          │
│                    │   CI Summary │                          │
│                    └──────────────┘                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                 Deployment Pipeline (deploy.yml)             │
│                  Triggered: Manual (workflow_dispatch)       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│                  ┌──────────────────┐                        │
│                  │  Pre-Deploy      │                        │
│                  │  Validation      │                        │
│                  └────────┬─────────┘                        │
│                           │                                   │
│         ┌─────────────────┴─────────────────┐                │
│         │                                     │                │
│  ┌──────▼───────────┐            ┌───────────▼──────┐       │
│  │   Deploy Agent   │            │  Deploy Edge     │       │
│  │  Stacks (Desktop)│            │  Stacks (Laptop) │       │
│  └──────┬───────────┘            └───────────┬──────┘       │
│         │                                     │                │
│         └─────────────────┬─────────────────┘                │
│                           │                                   │
│                  ┌────────▼─────────┐                        │
│                  │   Post-Deploy    │                        │
│                  │  Notification    │                        │
│                  └──────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## CI Pipeline (`ci.yml`)

### Purpose
Automated continuous integration that validates code quality, security, and functionality on every push and pull request.

### Triggers
- **Push** to `main` branch
- **Pull requests** targeting `main` branch
- **Manual** via workflow dispatch

### Pipeline Stages

#### 1. Lint PowerShell Scripts
- **Runner:** Windows Latest
- **Tool:** PSScriptAnalyzer
- **Action:** Analyzes all `.ps1` files for style and best practices
- **Fails on:** Warning or Error severity issues

#### 2. Lint Bash Scripts
- **Runner:** Ubuntu Latest
- **Tool:** shellcheck
- **Action:** Analyzes all `.sh` files for syntax and common errors
- **Fails on:** Any shellcheck issues

#### 3. Validate Scripts (Windows)
- **Runner:** Windows Latest
- **Dependencies:** Lint PowerShell
- **Action:** Validates PowerShell script syntax and execution
- **Checks:** Attempts to detect Docker (logs a warning if unavailable) and parses scripts for syntax issues

#### 4. Security SAST Scanning
- **Runner:** Ubuntu Latest
- **Tools:**
  - **Trivy**: Vulnerability scanner for filesystem
  - **Semgrep**: Static analysis for security patterns
- **Action:** Scans code for security vulnerabilities and secrets
- **Reports:** Uploads results to GitHub Security tab
- **Severity:** CRITICAL, HIGH

#### 5. Validate Docker Compose Files
- **Runner:** Ubuntu Latest
- **Strategy:** Matrix (common, desktop, laptop)
- **Tool:** `docker compose config`
- **Action:** Validates compose file syntax and structure
- **Creates:** Dummy environment files for validation

#### 6. Generate SBOM (Software Bill of Materials)
- **Runner:** Ubuntu Latest
- **Tool:** Syft + Grype
- **Action:**
  - Generates CycloneDX SBOM
  - Scans for vulnerabilities in dependencies
- **Artifact:** `sbom.json` (retained 90 days)

#### 7. Docker Image Security Scan
- **Runner:** Ubuntu Latest
- **Strategy:** Matrix (4 MCP images)
- **Tool:** Trivy
- **Action:** Scans Docker images for vulnerabilities
- **Images:**
  - `mcp/context7:latest`
  - `mcp/dockerhub:latest`
  - `mcp/mcp-playwright:latest`
  - `mcp/sequentialthinking:latest`
- **Note:** Non-blocking for third-party images

#### 8. Test Scripts (Linux)
- **Runner:** Ubuntu Latest
- **Dependencies:** Lint Bash
- **Action:** Tests Bash script syntax and executability

#### 9. Test Scripts (Windows)
- **Runner:** Windows Latest
- **Dependencies:** Lint PowerShell, Validate Scripts
- **Action:** Tests PowerShell script execution

#### 10. CI Summary
- **Runner:** Ubuntu Latest
- **Dependencies:** All previous jobs
- **Action:** Generates summary report in GitHub UI
- **Fails if:** Any critical job fails

### Success Criteria
- All linting passes (PowerShell + Bash)
- All security scans complete (SAST + image scanning)
- All Docker Compose files are valid
- All scripts execute without syntax errors

## Deployment Pipeline (`deploy.yml`)

### Purpose
Manual deployment workflow that validates and deploys stacks to Portainer environments.

### Triggers
- **Manual only** via GitHub Actions UI (workflow_dispatch)

### Input Parameters

| Parameter | Type | Description | Options |
|-----------|------|-------------|---------|
| `environment` | Choice | Target environment | desktop, laptop, all |
| `stack_name` | String | Override stack name | Optional |
| `force_redeploy` | Boolean | Force redeploy | Default: false |

### Pipeline Stages

#### 1. Pre-Deployment Validation
- **Runner:** Ubuntu Latest
- **Action:** Validates Docker Compose files for selected environment
- **Creates:** Test environment files with secrets
- **Output:** Validation status (pass/fail)

#### 2. Deploy Agent Stacks (Desktop)
- **Runner:** Ubuntu Latest
- **Condition:** environment = 'desktop' or 'all'
- **Action:**
  - Generates deployment instructions
  - Provides API deployment examples
  - Creates step-by-step manual deployment guide
- **Note:** Actual API deployment requires `PORTAINER_API_KEY` secret

#### 3. Deploy Edge Stacks (Laptop)
- **Runner:** Ubuntu Latest
- **Condition:** environment = 'laptop' or 'all'
- **Action:**
  - Generates Edge stack deployment instructions
  - Provides manual deployment steps (required for Portainer CE)
  - Validates Edge Config requirements
- **Note:** Portainer CE requires manual "Pull and redeploy"

#### 4. Post-Deploy Notification
- **Runner:** Ubuntu Latest
- **Dependencies:** Both deployment jobs
- **Action:**
  - Generates deployment summary
  - Provides next steps
  - Lists verification tasks

### Deployment Methods

#### Automatic (Portainer Business)
If using Portainer Business Edition with full API access:
- Configure `PORTAINER_API_KEY` secret
- Pipeline can trigger automatic redeployment
- GitOps auto-sync works for Agent endpoints

#### Manual (Portainer CE)
For Portainer Community Edition:
- Pipeline provides detailed instructions
- Manual "Pull and redeploy" required in UI
- Edge stacks always require manual trigger

## Secrets Configuration

See [SECRETS.md](./SECRETS.md) for detailed secrets documentation.

### Required Secrets

| Secret | Required | Used By | Purpose |
|--------|----------|---------|---------|
| `HUB_USERNAME` | Yes | CI, Deploy | Docker Hub authentication |
| `HUB_PAT_TOKEN` | Yes | CI, Deploy | Docker Hub authentication |
| `CONTEXT7_TOKEN` | Yes | CI, Deploy | Context7 service auth |
| `PORTAINER_API_KEY` | No | Deploy | Optional API deployment |

## Running Workflows

### Trigger CI Pipeline

CI runs automatically on push/PR. To manually trigger:

```bash
# Via GitHub CLI
gh workflow run ci.yml

# Via GitHub UI
Actions → CI Pipeline → Run workflow
```

### Trigger Deployment

```bash
# Deploy to desktop environments
gh workflow run deploy.yml -f environment=desktop

# Deploy to laptop environments
gh workflow run deploy.yml -f environment=laptop

# Deploy to all environments
gh workflow run deploy.yml -f environment=all -f force_redeploy=true

# Deploy with custom stack name
gh workflow run deploy.yml -f environment=desktop -f stack_name=mcp-production
```

**Via GitHub UI:**
1. Go to Actions tab
2. Select "Deploy to Portainer" workflow
3. Click "Run workflow"
4. Select options and run

## Workflow Outputs

### CI Pipeline Artifacts
- **SBOM:** `sbom.json` (Software Bill of Materials)
- **SARIF Reports:** Security scan results (uploaded to Security tab)
- **Summary:** Available in workflow run summary

### Deployment Pipeline Outputs
- **Deployment Instructions:** Step-by-step manual deployment guide
- **API Examples:** Ready-to-use API commands
- **Verification Steps:** Post-deployment checklist

## Security Features

### Static Analysis
- **PSScriptAnalyzer**: PowerShell best practices and security rules
- **shellcheck**: Bash script security and correctness
- **Semgrep**: Security patterns and vulnerability detection
- **Trivy**: CVE scanning for code and containers

### Dependency Scanning
- **SBOM Generation**: Complete dependency inventory
- **Grype**: Vulnerability scanning of dependencies
- **Trivy**: Image layer vulnerability scanning

### Secrets Protection
- All secrets encrypted in GitHub
- Never logged in workflow outputs
- Rotation procedures documented
- Secret scanning enabled

### Compliance
- SARIF reports uploaded to GitHub Security
- 90-day retention for SBOM artifacts
- Audit trail via GitHub Actions logs

## Monitoring and Alerts

### Status Badges
Add to README for visibility:

```markdown
[![CI Pipeline](https://github.com/unplugged12/mcp-stacks/actions/workflows/ci.yml/badge.svg)](https://github.com/unplugged12/mcp-stacks/actions/workflows/ci.yml)
[![Deploy](https://github.com/unplugged12/mcp-stacks/actions/workflows/deploy.yml/badge.svg)](https://github.com/unplugged12/mcp-stacks/actions/workflows/deploy.yml)
```

### Failure Notifications
GitHub Actions automatically notifies:
- Via GitHub UI notifications
- Via email (if configured)
- Via mobile app (GitHub Mobile)

Configure additional notifications:
- Settings → Notifications → Actions

## Troubleshooting

### CI Pipeline Fails

#### Linting Errors
```
Error: PSScriptAnalyzer found issues
```
**Solution:**
1. Run locally: `Invoke-ScriptAnalyzer -Path script.ps1`
2. Fix reported issues
3. Commit and push

#### Compose Validation Fails
```
Error: docker-compose.yml validation failed
```
**Solution:**
1. Run locally: `docker compose config`
2. Check YAML syntax
3. Verify environment variable references

#### Security Scan Failures
```
Error: High severity vulnerabilities found
```
**Solution:**
1. Review Security tab for details
2. Update dependencies or images
3. Document accepted risks if needed

### Deployment Pipeline Issues

#### Missing Secrets
```
Warning: PORTAINER_API_KEY not configured
```
**Solution:**
- Add secret in Settings → Secrets → Actions
- Or follow manual deployment instructions

#### Validation Fails
```
Error: Pre-deployment validation failed
```
**Solution:**
1. Check compose file syntax
2. Verify all required secrets are set
3. Review workflow logs for specific errors

## Best Practices

### Development Workflow
1. **Create feature branch**: `git checkout -b feature/my-change`
2. **Make changes**: Edit compose files or scripts
3. **Test locally**: Run `docker compose config`
4. **Commit**: `git commit -m "Add new MCP server"`
5. **Push**: `git push origin feature/my-change`
6. **Open PR**: CI pipeline runs automatically
7. **Review**: Check CI results and security scans
8. **Merge**: Once CI passes and PR approved
9. **Deploy**: Use deployment workflow if needed

### Security Workflow
1. **Regular scans**: CI runs on every push
2. **Review alerts**: Check Security tab weekly
3. **Update dependencies**: Keep images and dependencies current
4. **Rotate secrets**: Follow rotation schedule in SECRETS.md
5. **Audit logs**: Review Actions logs monthly

### Deployment Workflow
1. **Validate locally**: Test compose files before committing
2. **Check CI**: Ensure CI passes before deploying
3. **Use staging**: Test on non-production environments first
4. **Manual verification**: Check Portainer UI after deployment
5. **Monitor logs**: Review container logs post-deployment

## Performance

### Typical Run Times
- **CI Pipeline**: 8-12 minutes
  - Lint jobs: 1-2 minutes
  - Security scans: 3-5 minutes
  - Validation: 2-3 minutes
  - Image scans: 2-4 minutes
- **Deployment Pipeline**: 2-3 minutes
  - Validation: 1-2 minutes
  - Deployment instructions: 1 minute

### Optimization Tips
- Use matrix strategy for parallel execution
- Cache dependencies when possible
- Skip unnecessary jobs with `if` conditions
- Use workflow artifacts for sharing data

## Maintenance

### Regular Tasks
- **Weekly**: Review security scan results
- **Monthly**: Update GitHub Actions versions
- **Quarterly**: Review and optimize workflow performance
- **Annually**: Audit entire pipeline configuration

### Updates
When updating workflows:
1. Test in feature branch first
2. Review changes in PR
3. Monitor first production run
4. Document changes in this file

## Resources

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Trivy Documentation**: https://aquasecurity.github.io/trivy/
- **Semgrep Rules**: https://semgrep.dev/explore
- **Portainer API**: https://docs.portainer.io/api/
- **PSScriptAnalyzer**: https://github.com/PowerShell/PSScriptAnalyzer
- **shellcheck**: https://www.shellcheck.net/

## Support

For issues with the CI/CD pipeline:
1. Check workflow logs in Actions tab
2. Review this documentation
3. Check GitHub Actions status: https://www.githubstatus.com/
4. Consult repository maintainers

## Changelog

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-04 | 1.0 | Initial CI/CD pipeline implementation | @unplugged12 |

---

**Last Updated:** 2025-10-04
**Maintained By:** @unplugged12

# Edge Configurations

This directory contains scripts to build Edge Config bundles for laptop deployments.

## Usage

Run the Edge Config builder script to create a `.zip` bundle with environment variables:

**PowerShell:**
```powershell
.\scripts\build-edge-config.ps1
```

**Bash:**
```bash
./scripts/build-edge-config.sh
```

The script will:
1. Create a template `mcp.env` file with placeholder values
2. Prompt you interactively to fill in secrets
3. Package it into `edge-configs/laptops.zip`
4. **NOT commit secrets to Git** (protected by `.gitignore`)

## Deployment

1. In Portainer UI, navigate to **Edge Configurations**
2. Create a new configuration targeting your **laptops** Edge Group
3. Upload the generated `laptops.zip`
4. The configuration will be delivered to `/var/edge/configs/mcp.env` on each laptop

## Security

- Never commit `.env` or `.zip` files to Git
- Secrets are stored in Portainer's Edge Config system
- Each laptop receives the same configuration via the Edge tunnel

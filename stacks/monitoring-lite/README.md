# Monitoring Lite Stack

Lightweight telemetry collectors tailored for NAS endpoints that also host Plex
or other resource-intensive services. This stack forwards metrics and logs to a
remote observability backend while keeping local CPU, RAM, and disk usage low.

## Components

| Service  | Purpose | Notes |
|----------|---------|-------|
| Telegraf | Collects host + Docker metrics | Sends data to remote InfluxDB-compatible endpoint |
| Promtail | Ships container/syslog entries | Targets remote Loki-compatible endpoint |

## When to Use This Stack

Use `stacks/monitoring-lite/docker-compose.yml` when:

- The NAS hosts Plex, backup jobs, or VMs and cannot spare resources for
  Prometheus/Grafana/Loki.
- You have access to a remote observability platform (Grafana Cloud, InfluxDB
  Cloud, VictoriaMetrics, etc.) to store and visualize telemetry.
- You only need lightweight local agents with minimal footprint (<200 MB RAM,
  <1 vCPU steady state).

Use the full `stacks/monitoring/docker-compose.yml` bundle when:

- You have a dedicated observability node or VM with >4 vCPU, >8 GB RAM, and fast
  SSD storage for time-series data.
- You require local dashboards, alerting, and long-term retention without an
  external service dependency.

## Configuration

All sensitive values should be provided as environment variables via Portainer
stack deployment or an `.env` file that is **not committed to Git**.

| Variable | Description |
|----------|-------------|
| `ENVIRONMENT` | Optional label (default `nas`) applied to metrics/logs |
| `INFLUX_REMOTE_WRITE_URL` | Remote write endpoint (InfluxDB v2, VictoriaMetrics gateway, etc.) |
| `INFLUX_TOKEN` | API token for metrics backend |
| `INFLUX_ORG` | Organization/tenant name for metrics backend |
| `INFLUX_BUCKET` | Bucket/database name for metrics backend |
| `LOKI_URL` | Remote Loki HTTP push endpoint (Grafana Cloud, self-hosted) |
| `LOKI_TENANT_ID` | Optional tenant ID for Loki multi-tenancy |

### Deploy Steps

1. Copy `.env.example` (create one locally) with the variables above.
2. In Portainer, add a new stack pointing at `stacks/monitoring-lite/docker-compose.yml`.
3. Provide the environment variables in the **Environment variables** section or
   mount an `.env` file.
4. Deploy the stack. Metrics/logs will begin streaming to the configured remote
   services.

### Optional: Add Netdata for Local Dashboards

If you need quick on-box dashboards without Prometheus/Grafana, add the
following service to the compose file:

```yaml
  netdata:
    image: netdata/netdata:stable
    container_name: monitoring-lite-netdata
    restart: unless-stopped
    pid: host
    network_mode: host
    cap_add:
      - SYS_PTRACE
      - NET_ADMIN
    security_opt:
      - apparmor:unconfined
    volumes:
      - netdata-config:/etc/netdata
      - netdata-lib:/var/lib/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
volumes:
  netdata-config:
  netdata-lib:
```

This adds ~300 MB RAM usage but still avoids running full Prometheus/Grafana on
the NAS.

# MCP Observability Guide

Comprehensive observability strategy for MCP (Model Context Protocol) servers with OpenTelemetry instrumentation, health monitoring, and operational insights.

---

## Table of Contents

- [Overview](#overview)
- [Current Observability Features](#current-observability-features)
- [OpenTelemetry Instrumentation Plan](#opentelemetry-instrumentation-plan)
- [Health Check Strategy](#health-check-strategy)
- [Logging Configuration](#logging-configuration)
- [Metrics Collection](#metrics-collection)
- [Distributed Tracing](#distributed-tracing)
- [Alerting & Monitoring](#alerting--monitoring)
- [Implementation Roadmap](#implementation-roadmap)
- [Tools & Integration](#tools--integration)

---

## Overview

This document outlines the observability strategy for MCP servers deployed across Agent (desktop) and Edge (laptop) environments managed by Portainer CE.

**Key Goals:**
- Proactive health monitoring of all MCP services
- Performance metrics and resource utilization tracking
- Distributed tracing for request flows
- Structured logging with correlation IDs
- Alerting on service degradation or failures

**Observability Pillars:**
1. **Metrics**: Quantitative data about system behavior (CPU, memory, request rates)
2. **Logs**: Discrete events with context (errors, warnings, info)
3. **Traces**: Request paths through distributed services

---

## Current Observability Features

The enhanced docker-compose files now include:

### Health Checks

All MCP services have container-level health checks:

```yaml
healthcheck:
  test: ["CMD-SHELL", "timeout 5 sh -c ':> /dev/tcp/127.0.0.1/3000' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

**How it works:**
- Tests TCP connectivity to port 3000 (MCP server port)
- Runs every 30 seconds
- Allows 40 seconds startup time before first check
- Marks unhealthy after 3 consecutive failures

**Access health status:**
```bash
docker inspect <container-name> --format='{{.State.Health.Status}}'
```

### Resource Limits

Prevent resource exhaustion with defined limits:

| Service | CPU Limit | Memory Limit | CPU Reservation | Memory Reservation |
|---------|-----------|--------------|-----------------|-------------------|
| context7 | 1.0 core | 512MB | 0.25 core | 128MB |
| dockerhub | 0.5 core | 256MB | 0.1 core | 64MB |
| playwright | 2.0 cores | 2GB | 0.5 core | 256MB |
| sequentialthinking | 1.0 core | 512MB | 0.25 core | 128MB |

**Playwright gets more resources** due to browser automation requirements.

**Monitor resource usage:**
```bash
docker stats --no-stream
```

### Structured Logging

All services use JSON file logging driver with rotation:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
    labels: "service,environment"
```

**Features:**
- Automatic log rotation (max 10MB per file, 3 files retained)
- Total max log storage: 30MB per container
- Labels attached for filtering

**View logs:**
```bash
docker logs <container-name> --tail 100 --follow
docker logs <container-name> --since 1h
```

### Service Labels

Labels enable filtering and grouping:

```yaml
labels:
  - "com.mcp.service=context7"
  - "com.mcp.version=latest"
  - "com.mcp.environment=production"
  - "com.mcp.deployment=edge"  # or "agent"
```

**Query by label:**
```bash
docker ps --filter "label=com.mcp.service=playwright"
docker ps --filter "label=com.mcp.deployment=edge"
```

---

## OpenTelemetry Instrumentation Plan

OpenTelemetry (OTel) provides vendor-neutral observability for cloud-native software.

### Architecture Overview

```
┌─────────────────┐
│  MCP Servers    │
│  (Node.js apps) │
└────────┬────────┘
         │
         │ OTel SDK
         ▼
┌─────────────────┐
│ OTel Collector  │  ← Sidecar or centralized
│  (aggregator)   │
└────────┬────────┘
         │
         ├─────► Prometheus (Metrics)
         ├─────► Loki (Logs)
         └─────► Jaeger/Tempo (Traces)
```

### Phase 1: SDK Integration (Application-Level)

#### Node.js Instrumentation

Add OpenTelemetry to each MCP server codebase:

**1. Install dependencies:**
```bash
npm install --save @opentelemetry/api \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-otlp-grpc
```

**2. Create instrumentation file (`instrumentation.js`):**
```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-otlp-grpc');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'mcp-service',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.SERVICE_VERSION || '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.ENVIRONMENT || 'production',
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
    }),
    exportIntervalMillis: 60000, // 1 minute
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': { enabled: true },
      '@opentelemetry/instrumentation-express': { enabled: true },
      '@opentelemetry/instrumentation-fs': { enabled: false }, // Reduce noise
    }),
  ],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('OpenTelemetry SDK shut down successfully'))
    .catch((error) => console.log('Error shutting down OpenTelemetry SDK', error))
    .finally(() => process.exit(0));
});
```

**3. Start application with instrumentation:**
```bash
node --require ./instrumentation.js server.js
```

**4. Update Dockerfile:**
```dockerfile
# Add to existing MCP server Dockerfile
COPY instrumentation.js /app/
ENV NODE_OPTIONS="--require /app/instrumentation.js"
```

#### Environment Variables

Add to docker-compose or Edge Config:

```env
OTEL_SERVICE_NAME=mcp-context7
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
ENVIRONMENT=production
SERVICE_VERSION=1.0.0
```

### Phase 2: OpenTelemetry Collector Deployment

Deploy OTel Collector as a sidecar or centralized service.

#### Option A: Sidecar Pattern (Per-Stack)

Add to `stacks/common/docker-compose.yml`:

```yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    restart: unless-stopped
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml:ro
    ports:
      - "4317:4317"  # OTLP gRPC receiver
      - "4318:4318"  # OTLP HTTP receiver
      - "8888:8888"  # Prometheus metrics (collector itself)
    networks:
      - mcp-network
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:13133/"]
      interval: 30s
      timeout: 5s
      retries: 3
```

#### OTel Collector Configuration

Create `otel-collector-config.yaml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

  resource:
    attributes:
      - key: deployment.type
        value: ${DEPLOYMENT_TYPE}
        action: upsert

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: mcp

  loki:
    endpoint: http://loki:3100/loki/api/v1/push

  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true

  logging:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [jaeger, logging]

    metrics:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [prometheus, logging]

    logs:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [loki, logging]
```

#### Option B: Centralized Collector

Deploy OTel Collector on Portainer as a separate stack, accessible via network.

---

## Health Check Strategy

### Container-Level Health Checks

Already implemented in docker-compose files. Health status visible in:
- Portainer UI (Containers view)
- Docker CLI: `docker ps` (shows "healthy" or "unhealthy")
- Docker inspect: `docker inspect <container> --format='{{json .State.Health}}'`

### Application-Level Health Endpoints

MCP servers should expose health endpoints for deeper checks.

**Recommended endpoint:** `GET /health`

**Response format:**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-04T12:34:56Z",
  "uptime": 3600,
  "checks": {
    "database": "ok",
    "external_api": "ok",
    "disk_space": "ok"
  }
}
```

**Update healthcheck in docker-compose:**
```yaml
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Portainer Webhook Monitoring

Configure webhooks to trigger external monitoring when health changes:

1. Portainer UI → Containers → Select container → Webhooks
2. Create webhook for "stop" and "unhealthy" events
3. Send to monitoring system (e.g., PagerDuty, Slack)

---

## Logging Configuration

### Structured Logging Best Practices

**Use JSON format** for all application logs:

```javascript
// Example: Winston logger configuration
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: process.env.OTEL_SERVICE_NAME,
    environment: process.env.ENVIRONMENT,
  },
  transports: [
    new winston.transports.Console(),
  ],
});

// Usage
logger.info('MCP request processed', {
  correlationId: req.id,
  method: req.method,
  path: req.path,
  duration: elapsed,
  userId: req.user?.id,
});
```

### Log Aggregation

**Option 1: Docker Logging Drivers**

Use Loki logging driver (requires Docker plugin):

```yaml
logging:
  driver: loki
  options:
    loki-url: "http://loki:3100/loki/api/v1/push"
    loki-batch-size: "400"
    labels: "service,environment"
```

**Option 2: Promtail Sidecar**

Deploy Promtail alongside services to scrape Docker logs:

```yaml
services:
  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./promtail-config.yaml:/etc/promtail/config.yaml:ro
    command: -config.file=/etc/promtail/config.yaml
```

### Log Retention

Current configuration: **30MB per container** (10MB × 3 files)

For long-term retention, forward to external system (Loki, Elasticsearch, CloudWatch).

---

## Metrics Collection

### Container Metrics

Docker provides built-in metrics via `/var/run/docker.sock`.

**Exporters:**
- **cAdvisor**: Container-level metrics
- **Docker Metrics Exporter**: Prometheus-compatible

**Deploy cAdvisor:**
```yaml
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    ports:
      - "8080:8080"
    restart: unless-stopped
```

Access metrics: `http://localhost:8080/metrics`

### Application Metrics

Use OpenTelemetry SDK or Prometheus client libraries.

**Key metrics to track:**
- Request rate (requests/sec)
- Request duration (latency percentiles: p50, p95, p99)
- Error rate (errors/sec)
- Active connections
- Queue depth

**Example: Custom Prometheus metrics in Node.js**
```javascript
const client = require('prom-client');

const requestDuration = new client.Histogram({
  name: 'mcp_request_duration_seconds',
  help: 'Duration of MCP requests in seconds',
  labelNames: ['method', 'status'],
});

const requestCounter = new client.Counter({
  name: 'mcp_requests_total',
  help: 'Total number of MCP requests',
  labelNames: ['method', 'status'],
});

// Middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    requestDuration.labels(req.method, res.statusCode).observe(duration);
    requestCounter.labels(req.method, res.statusCode).inc();
  });
  next();
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

---

## Distributed Tracing

### Trace Context Propagation

OpenTelemetry automatically propagates trace context via HTTP headers:
- `traceparent`: W3C Trace Context
- `tracestate`: Vendor-specific data

**Example trace flow:**
```
Client → MCP-Context7 → External API
  |         |              |
  +-------- Trace ID: abc123 --------+
```

### Trace Visualization

Use Jaeger or Grafana Tempo to visualize traces.

**Deploy Jaeger:**
```yaml
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"  # UI
      - "14250:14250"  # gRPC
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    restart: unless-stopped
```

Access UI: `http://localhost:16686`

### Trace Sampling

Configure sampling to reduce overhead:

```javascript
// In instrumentation.js
const { TraceIdRatioBasedSampler } = require('@opentelemetry/sdk-trace-base');

const sdk = new NodeSDK({
  sampler: new TraceIdRatioBasedSampler(0.1), // Sample 10% of traces
  // ...
});
```

---

## Alerting & Monitoring

### Portainer Notifications

Portainer CE has limited native alerting. Use webhooks to integrate with external systems.

**Webhook targets:**
- Slack
- Discord
- Microsoft Teams
- PagerDuty
- Custom HTTP endpoint

### Prometheus Alerting

If using Prometheus + Alertmanager:

**Example alert rule:**
```yaml
groups:
  - name: mcp_alerts
    interval: 30s
    rules:
      - alert: MCPServiceDown
        expr: up{job="mcp-services"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "MCP service {{ $labels.service }} is down"
          description: "{{ $labels.service }} has been down for more than 2 minutes"

      - alert: MCPHighMemoryUsage
        expr: container_memory_usage_bytes{name=~"mcp-.*"} / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.name }}"
          description: "Memory usage is above 90% for 5 minutes"

      - alert: MCPHighErrorRate
        expr: rate(mcp_requests_total{status=~"5.."}[5m]) > 0.05
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is above 5% for 2 minutes"
```

---

## Implementation Roadmap

### Phase 1: Foundation (Current)
- [x] Health checks in docker-compose
- [x] Resource limits configured
- [x] Structured logging with rotation
- [x] Service labels for filtering

### Phase 2: Application Instrumentation (Next)
- [ ] Add OpenTelemetry SDK to MCP server codebases
- [ ] Implement `/health` and `/metrics` endpoints
- [ ] Deploy OTel Collector (sidecar pattern)
- [ ] Configure log forwarding to Loki

### Phase 3: Visualization & Alerting
- [ ] Deploy Grafana for dashboards
- [ ] Deploy Prometheus for metrics storage
- [ ] Deploy Jaeger for trace visualization
- [ ] Configure Alertmanager for alerts
- [ ] Create Grafana dashboards for MCP services

### Phase 4: Advanced Observability
- [ ] Implement SLO tracking (Service Level Objectives)
- [ ] Add custom business metrics
- [ ] Distributed tracing across all services
- [ ] Automated anomaly detection
- [ ] Cost attribution and resource optimization

---

## Tools & Integration

---

## Lightweight Observability Strategy for NAS Endpoints

The full Prometheus + Grafana + Loki stack delivers deep insights, but it can
consume several CPU cores, multiple gigabytes of RAM, and significant disk
IO—resources that a NAS already sharing Plex, backup jobs, or VM workloads
cannot spare. To keep telemetry flowing without overwhelming the NAS, adopt one
of the following strategies.

### Option 1: Offload Heavy Components to a Remote Host

1. **Run collectors on the NAS**: Keep only lightweight agents (Telegraf,
   Promtail, node-exporter) on the NAS. They gather metrics/logs and forward
   them upstream.
2. **Deploy storage & visualization elsewhere**: Host Prometheus, Grafana,
   Loki/Tempo on a more capable machine (homelab server, cloud VM). Configure
   remote write/HTTP endpoints in the NAS agents.
3. **Benefits**:
   - NAS CPU/RAM remain available for Plex, ZFS scrubs, or VM workloads.
   - Heavy queries and retention policies run on hardware designed for it.
   - Scale dashboards/alerting without impacting local services.

### Option 2: Replace with Lightweight, All-in-One Collectors

If a remote backend is not available, replace the heavy bundle with a
single-agent solution tailored for constrained devices:

- **Netdata (Agent mode)** for per-second visibility and local dashboards with
  minimal tuning.
- **Telegraf + Remote Backend** for metrics-only collection to InfluxDB Cloud,
  Timescale Cloud, or VictoriaMetrics SaaS.
- **Vector or Promtail** for log forwarding to Grafana Cloud Loki or another
  managed store.

The new `stacks/monitoring-lite/docker-compose.yml` defines this minimal agent
set. See [Lightweight Monitoring Stack](../stacks/monitoring-lite/README.md) for
usage guidance.

### Deployment Decision Matrix

| Environment | Recommended Stack | Rationale |
|-------------|-------------------|-----------|
| Dedicated observability host | `stacks/monitoring/docker-compose.yml` | Runs complete monitoring platform locally |
| NAS hosting Plex/backups | `stacks/monitoring-lite/docker-compose.yml` | Keeps resource usage low, ships telemetry remotely |
| Remote cloud monitoring | `stacks/monitoring-lite/docker-compose.yml` + managed backends | Avoids local storage of metrics/logs |

### Configuration Considerations

- **Network**: Ensure outbound HTTPS connectivity from the NAS to remote
  telemetry services.
- **Authentication**: Store API tokens (Grafana Cloud, InfluxDB, etc.) as stack
  environment variables or Portainer secrets.
- **Retention & Compliance**: Managed platforms handle data retention, but
  verify your policies before forwarding sensitive logs.

By separating collection from storage/visualization, the NAS contributes to the
observability fabric without sacrificing performance or reliability.

### Recommended Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| Metrics Storage | Prometheus | Time-series database for metrics |
| Metrics Visualization | Grafana | Dashboards and graphs |
| Log Aggregation | Loki | Log storage and querying |
| Trace Storage | Jaeger or Tempo | Distributed trace backend |
| Collector | OpenTelemetry Collector | Unified telemetry pipeline |
| Alerting | Alertmanager | Alert routing and silencing |
| Container Metrics | cAdvisor | Docker container metrics |

### Grafana Dashboard Examples

**1. MCP Service Overview**
- Request rate (requests/sec)
- Error rate (%)
- P95 latency
- Resource usage (CPU, memory)
- Container health status

**2. Resource Utilization**
- CPU usage per service
- Memory usage per service
- Disk I/O
- Network I/O

**3. Distributed Traces**
- Trace duration histogram
- Service dependency graph
- Error trace samples

### Grafana Loki for Logs

**Query examples:**
```logql
# All logs from context7 service
{com_mcp_service="context7"}

# Error logs from all MCP services
{com_mcp_service=~"mcp-.*"} |= "error" | json

# High latency requests
{com_mcp_service="context7"} | json | duration > 1000

# Requests by user
{com_mcp_service="context7"} | json | userId="user123"
```

---

## Cost Considerations

### Self-Hosted vs. Cloud

**Self-Hosted (Recommended for home lab):**
- Prometheus + Grafana + Loki + Jaeger
- Free and open-source
- Runs on existing infrastructure
- Requires maintenance

**Cloud Options:**
- Grafana Cloud (free tier available)
- Datadog (paid)
- New Relic (paid)
- AWS CloudWatch (pay-per-use)

### Resource Requirements

**Observability stack resource estimates:**
- Prometheus: 512MB RAM, 0.5 CPU, 10GB storage
- Grafana: 256MB RAM, 0.2 CPU
- Loki: 512MB RAM, 0.5 CPU, 20GB storage
- Jaeger: 512MB RAM, 0.5 CPU, 10GB storage
- OTel Collector: 256MB RAM, 0.2 CPU

**Total:** ~2GB RAM, ~2 CPU cores, ~40GB storage

---

## Security Considerations

### Secrets Management

Never log sensitive information:
- API tokens
- Passwords
- PII (Personally Identifiable Information)

**Use redaction in logs:**
```javascript
logger.info('User logged in', {
  userId: user.id,
  email: redact(user.email), // user@example.com → u***@e***.com
});
```

### Network Security

- Use internal Docker networks for OTel Collector
- Expose Grafana/Prometheus via reverse proxy with authentication
- Use TLS for external exporters

### Data Retention

Configure retention policies to comply with data governance:

```yaml
# Prometheus retention
--storage.tsdb.retention.time=30d

# Loki retention
retention_enabled: true
retention_period: 30d
```

---

## Testing Observability

### Smoke Test Integration

The smoke test script (`scripts/smoke-test.ps1`) validates health checks.

**Run after deployment:**
```powershell
.\scripts\smoke-test.ps1 -StackPrefix "mcp"
```

### Generate Test Traffic

Use `curl` or custom scripts to generate traffic for testing metrics:

```bash
# Generate 100 requests
for i in {1..100}; do
  curl -X POST http://localhost:3000/mcp/request \
    -H "Content-Type: application/json" \
    -d '{"method":"test","params":{}}'
done
```

### Verify Metrics Export

```bash
# Check OTel Collector metrics endpoint
curl http://localhost:8888/metrics

# Check application metrics endpoint
curl http://localhost:3000/metrics
```

---

## Support & Resources

**OpenTelemetry:**
- Documentation: https://opentelemetry.io/docs/
- Node.js Instrumentation: https://opentelemetry.io/docs/instrumentation/js/

**Prometheus:**
- Documentation: https://prometheus.io/docs/

**Grafana:**
- Documentation: https://grafana.com/docs/

**Loki:**
- Documentation: https://grafana.com/docs/loki/

**Jaeger:**
- Documentation: https://www.jaegertracing.io/docs/

---

## Next Steps

1. **Review current health check implementation** in deployed stacks
2. **Add OpenTelemetry SDK** to MCP server codebases
3. **Deploy observability stack** (Prometheus + Grafana + Loki)
4. **Create Grafana dashboards** for MCP services
5. **Configure alerting** for critical services
6. **Document runbooks** for common issues

For questions or contributions, refer to the main repository README.

---

**Last Updated:** 2025-10-04
**Maintainer:** Platform Builder

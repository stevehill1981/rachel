# Health Check Endpoints

Rachel provides health check endpoints for monitoring and load balancer configuration.

## Basic Health Check

**Endpoint:** `GET /health`

Returns a simple OK status if the application is running.

```bash
curl http://localhost:4000/health
```

**Response:**
```json
{
  "status": "ok",
  "service": "rachel",
  "timestamp": "2025-07-07T07:43:53.915578Z"
}
```

## Detailed Health Check

**Endpoint:** `GET /health/detailed`

Performs comprehensive health checks including:
- Database connectivity
- Game server status
- Memory usage

```bash
curl http://localhost:4000/health/detailed
```

**Response:**
```json
{
  "status": "healthy",
  "service": "rachel",
  "version": "0.1.0",
  "timestamp": "2025-07-07T07:43:59.772420Z",
  "node": "rachel@10.0.0.1",
  "checks": {
    "database": {
      "status": "healthy",
      "message": "Database connection OK"
    },
    "game_servers": {
      "status": "healthy",
      "message": "Game servers operational",
      "active_games": 5
    },
    "memory": {
      "status": "healthy",
      "message": "Memory usage: 93.56 MB",
      "memory_mb": 93.56
    }
  }
}
```

## Status Codes

- **200 OK**: All checks passed, service is healthy
- **503 Service Unavailable**: One or more checks failed, service is degraded

## Fly.io Configuration

Add to your `fly.toml`:

```toml
[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  
  [http_service.health_check]
    interval = "30s"
    timeout = "5s"
    grace_period = "10s"
    method = "GET"
    path = "/health"
```

## Monitoring Integration

These endpoints can be used with:
- **Uptime monitoring services** (UptimeRobot, Pingdom, etc.)
- **Load balancers** (AWS ELB, Google Cloud Load Balancer)
- **Container orchestrators** (Kubernetes, Docker Swarm)
- **APM tools** (New Relic, Datadog, AppSignal)

## Memory Thresholds

The detailed health check monitors memory usage:
- **Healthy**: < 1500 MB
- **Warning**: >= 1500 MB

Adjust these thresholds in `health_controller.ex` based on your deployment resources.
# Load Testing Guide

This guide explains how to load test Rachel before launch.

## Quick Load Test

We've included a simple Elixir script for basic load testing:

```bash
# Test with 10 concurrent players (default)
elixir scripts/load_test.exs

# Test with 50 concurrent players
elixir scripts/load_test.exs http://localhost:4000 50

# Test production
elixir scripts/load_test.exs https://rachel-game.fly.dev 20
```

## Using Apache Bench (ab)

For more thorough HTTP load testing:

```bash
# Install ab (usually comes with Apache)
# macOS: Already installed
# Ubuntu: sudo apt-get install apache2-utils

# Test health endpoint - 1000 requests, 10 concurrent
ab -n 1000 -c 10 http://localhost:4000/health/

# Test homepage - 500 requests, 20 concurrent  
ab -n 500 -c 20 http://localhost:4000/

# Test with keep-alive
ab -n 1000 -c 50 -k http://localhost:4000/health/
```

## Using hey (Modern HTTP load tester)

```bash
# Install hey
go install github.com/rakyll/hey@latest

# Test with 50 concurrent users for 30 seconds
hey -z 30s -c 50 http://localhost:4000/health/

# Test with specific request rate (100 req/sec)
hey -q 100 -z 30s http://localhost:4000/health/
```

## Expected Results

With 1GB RAM and 1 shared CPU on Fly.io:

### Health Endpoints
- Should handle 500+ requests/second
- Response time < 50ms

### Game Pages  
- Should handle 100+ requests/second
- Response time < 200ms

### Concurrent Games
- 10-20 active games simultaneously
- 50-100 total connected players

## Monitoring During Tests

1. **Watch Memory Usage**:
   ```bash
   curl http://localhost:4000/health/detailed | jq .checks.memory
   ```

2. **Check Rate Limiting**:
   Look for `X-RateLimit-*` headers in responses

3. **Monitor Logs**:
   ```bash
   fly logs # In production
   ```

## Load Test Scenarios

### 1. Gradual Ramp-up
Simulates organic growth:
```bash
for i in {1..5}; do
  echo "Wave $i: $((i*10)) players"
  elixir scripts/load_test.exs http://localhost:4000 $((i*10))
  sleep 10
done
```

### 2. Spike Test  
Simulates viral moment:
```bash
# Sudden spike of 100 concurrent requests
ab -n 100 -c 100 http://localhost:4000/
```

### 3. Sustained Load
Simulates steady traffic:
```bash
# 20 concurrent users for 5 minutes
hey -z 5m -c 20 http://localhost:4000/health/
```

## What to Look For

### ✅ Good Signs:
- All requests complete successfully
- Response times remain consistent
- Memory usage stays under 80%
- No 500 errors
- Rate limiting works (429 responses when expected)

### ⚠️ Warning Signs:
- Response times > 1 second
- Memory usage > 90%
- Connection timeouts
- 502/503 errors
- Server restart during test

## After Testing

1. Check Sentry for any errors
2. Review server logs for warnings
3. Monitor memory usage trends
4. Verify rate limits weren't too restrictive

## Production Testing

When testing on Fly.io:
- Start with lower concurrent numbers (10-20)
- Monitor Fly.io dashboard during tests
- Check bandwidth usage
- Verify health checks stay green
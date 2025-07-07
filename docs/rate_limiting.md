# Rate Limiting

Rachel implements ETS-based rate limiting to prevent abuse and ensure fair usage.

## Overview

The rate limiter uses a sliding window algorithm to track requests. It's designed for single-node deployments but can be upgraded to use Redis for multi-node setups.

## Limits

### API Endpoints
- **Limit**: 300 requests per minute
- **Applies to**: All `/health/*` endpoints
- **Headers**: Returns `X-RateLimit-*` headers

### Game Creation
- **Limit**: 10 games per 5 minutes per player
- **Applies to**: 
  - Instant play (`/play`)
  - Practice games (`/practice`)
  - Lobby game creation
- **Key**: Uses player ID (persistent across sessions)

## Response Headers

When making API requests, the following headers are returned:

```
X-RateLimit-Limit: 300
X-RateLimit-Remaining: 299
X-RateLimit-Reset: 1641234567
Retry-After: 60 (only when rate limited)
```

## Rate Limited Response

When rate limited, API endpoints return:

```json
{
  "error": "Rate limit exceeded",
  "message": "Too many requests. Please try again later."
}
```

HTTP Status: `429 Too Many Requests`

## Game Creation Rate Limiting

For game creation, users see a flash message:
> "You're creating games too quickly. Please wait a few minutes before trying again."

## Implementation Details

### Storage
- Uses ETS (Erlang Term Storage) for in-memory storage
- Automatically cleans up old entries every 5 minutes
- Keeps request history for up to 2 hours

### Performance
- O(1) lookups with ETS
- Minimal memory overhead
- No external dependencies

### Monitoring
Check current usage for a key:
```elixir
Rachel.RateLimiter.get_usage("ip:192.168.1.1")
```

Reset rate limit (for testing):
```elixir
Rachel.RateLimiter.reset("ip:192.168.1.1")
```

## Future Upgrades

### Redis Support
To support multiple nodes, we can upgrade to Redis:

1. Add Redis dependency:
   ```elixir
   {:redix, "~> 1.2"}
   ```

2. Update RateLimiter to use Redis ZADD/ZREMRANGEBYSCORE
3. Configure Redis connection in production

### Upstash Redis on Fly.io
For serverless Redis:
```bash
fly secrets set REDIS_URL="redis://default:xxx@fly-xxx.upstash.io"
```

## Custom Rate Limits

Apply custom limits to specific routes:

```elixir
# In router.ex
pipeline :strict_api do
  plug :accepts, ["json"]
  plug RachelWeb.Plugs.RateLimit, 
    max_requests: 10, 
    window_ms: 60_000
end
```

## Best Practices

1. **Set appropriate limits**: Balance user experience with protection
2. **Monitor usage**: Check logs for rate limit hits
3. **Provide clear feedback**: Users should understand why they're limited
4. **Consider user types**: Future: different limits for authenticated users
5. **Test limits**: Use the health check endpoints to verify limits work